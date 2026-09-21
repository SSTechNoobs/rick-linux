#!/usr/bin/env bash
set -Eeuo pipefail

MOUNTPOINT="${1:?Missing target mountpoint}"
USERNAME="${2:?Missing username}"
SOURCE_DIR="${3:?Missing Rick Linux source directory}"

USER_HOME="$MOUNTPOINT/home/$USERNAME"
TEMP_SUDO=""

cleanup_installer_sudo() {
    if [[ -n "${TEMP_SUDO:-}" ]]; then
        rm -f "$TEMP_SUDO"
    fi
}

trap cleanup_installer_sudo EXIT

info() {
    printf '[DESKTOP] %s\n' "$*"
}

[[ -d "$MOUNTPOINT" ]] || {
    echo "Target mountpoint does not exist: $MOUNTPOINT" >&2
    exit 1
}

[[ -f "$SOURCE_DIR/packages/desktop.txt" ]] || {
    echo "Missing desktop package list." >&2
    exit 1
}

[[ -f "$SOURCE_DIR/configs/quickshell/rick/shell.qml" ]] || {
    echo "Missing Ricks Linux Quickshell configuration." >&2
    exit 1
}

# ------------------------------------------------------------
# Official Arch desktop packages
# ------------------------------------------------------------

mapfile -t DESKTOP_PACKAGES < <(
    grep -Ev '^[[:space:]]*(#|$)' \
        "$SOURCE_DIR/packages/desktop.txt"
)

info "Installing Ricks Linux desktop packages..."

arch-chroot "$MOUNTPOINT" pacman \
    -Syu \
    --needed \
    --noconfirm \
    "${DESKTOP_PACKAGES[@]}"

# ------------------------------------------------------------
# Enable multilib, then install Steam + 32-bit Intel Vulkan
# ------------------------------------------------------------

info "Enabling Arch multilib repository..."

sed -i \
    '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/ s/^#//' \
    "$MOUNTPOINT/etc/pacman.conf"

info "Installing Steam and multilib graphics support..."

arch-chroot "$MOUNTPOINT" pacman \
    -Syu \
    --needed \
    --noconfirm \
    steam \
    lib32-vulkan-intel

# ------------------------------------------------------------
# System services
# ------------------------------------------------------------

info "Enabling system services..."

for service in \
    NetworkManager.service \
    bluetooth.service \
    cups.service \
    avahi-daemon.service
do
    arch-chroot "$MOUNTPOINT" systemctl enable "$service"
done

# ------------------------------------------------------------
# Automatic Brother printer setup
# ------------------------------------------------------------

info "Installing Brother HL-L2395DW automatic printer setup..."

install -m 0755     "$SOURCE_DIR/scripts/system/rick-printer-setup"     "$MOUNTPOINT/usr/local/sbin/rick-printer-setup"

install -m 0644     "$SOURCE_DIR/configs/systemd/rick-printer-setup.service"     "$MOUNTPOINT/etc/systemd/system/rick-printer-setup.service"

arch-chroot "$MOUNTPOINT"     systemctl enable rick-printer-setup.service

# ------------------------------------------------------------
# mDNS / .local support for network printers
# ------------------------------------------------------------

info "Configuring local network discovery..."

if grep -q '^hosts:' "$MOUNTPOINT/etc/nsswitch.conf"; then
    sed -i \
        's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' \
        "$MOUNTPOINT/etc/nsswitch.conf"
fi

# ------------------------------------------------------------
# Ricks Linux marker
# ------------------------------------------------------------

cat > "$MOUNTPOINT/etc/rick-linux-release" <<'RICK_RELEASE'
NAME="Ricks Linux"
ID=rick-linux
VERSION="1.0.1"
BASE="Arch Linux"
RICK_RELEASE

date --iso-8601=seconds > "$MOUNTPOINT/etc/rick-linux-install-date"

# ------------------------------------------------------------
# User configuration
# ------------------------------------------------------------

info "Installing Ricks Linux user configuration..."

install -d \
    "$USER_HOME/.config/quickshell/rick/icons" \
    "$USER_HOME/.config/hypr" \
    "$USER_HOME/.config/aether/custom/ricks-wallpaper" \
    "$USER_HOME/.local/bin" \
    "$USER_HOME/Desktop" \
    "$USER_HOME/Documents" \
    "$USER_HOME/Downloads" \
    "$USER_HOME/Music" \
    "$USER_HOME/Pictures" \
    "$USER_HOME/Videos"

install -m 0644 \
    "$SOURCE_DIR/configs/quickshell/rick/shell.qml" \
    "$USER_HOME/.config/quickshell/rick/shell.qml"

cp -a \
    "$SOURCE_DIR/configs/quickshell/rick/icons/." \
    "$USER_HOME/.config/quickshell/rick/icons/"

install -m 0644 \
    "$SOURCE_DIR/configs/hypr/hyprland.lua" \
    "$USER_HOME/.config/hypr/hyprland.lua"


install -m 0644 \
    "$SOURCE_DIR/configs/aether/custom/ricks-wallpaper/config.json" \
    "$USER_HOME/.config/aether/custom/ricks-wallpaper/config.json"

install -m 0644 \
    "$SOURCE_DIR/configs/aether/custom/ricks-wallpaper/wallpaper.txt" \
    "$USER_HOME/.config/aether/custom/ricks-wallpaper/wallpaper.txt"

install -m 0755 \
    "$SOURCE_DIR/configs/aether/custom/ricks-wallpaper/post-apply.sh" \
    "$USER_HOME/.config/aether/custom/ricks-wallpaper/post-apply.sh"

cat > "$USER_HOME/.config/user-dirs.dirs" <<'EOF_XDG'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
XDG_TEMPLATES_DIR="$HOME/"
XDG_PUBLICSHARE_DIR="$HOME/"
EOF_XDG

cat > "$USER_HOME/.config/hypr/hyprland.conf" <<'EOF_HYPRCONF'
exec-once = ~/.local/bin/rick-bar-watchdog
exec-once = ~/.local/bin/rick-wallpaper-apply
EOF_HYPRCONF

for optional in hyprtoolkit.conf hyprlauncher.conf; do
    if [[ -f "$SOURCE_DIR/configs/hypr/$optional" ]]; then
        install -m 0644 \
            "$SOURCE_DIR/configs/hypr/$optional" \
            "$USER_HOME/.config/hypr/$optional"
    fi
done

for helper in "$SOURCE_DIR"/scripts/user/rick-*; do
    [[ -f "$helper" ]] || continue

    install -m 0755 \
        "$helper" \
        "$USER_HOME/.local/bin/$(basename "$helper")"
done

install -m 0644 \
    "$SOURCE_DIR/configs/bash_profile" \
    "$USER_HOME/.bash_profile"

# Replace paths captured from the original development account.
find \
    "$USER_HOME/.config/quickshell/rick" \
    "$USER_HOME/.config/hypr" \
    "$USER_HOME/.local/bin" \
    -type f \
    -exec sed -i \
        "s#/home/rick#/home/$USERNAME#g" {} +

# ------------------------------------------------------------
# Session helpers
# ------------------------------------------------------------

cat > "$USER_HOME/.local/bin/rick-session-start" <<EOF_SESSION
#!/usr/bin/env bash

sleep 2

pgrep -x nm-applet >/dev/null 2>&1 || \
    setsid -f nm-applet --indicator >/dev/null 2>&1

systemctl --user start hyprpolkitagent.service \
    >/dev/null 2>&1 || true
EOF_SESSION

chmod 0755 "$USER_HOME/.local/bin/rick-session-start"

if ! grep -q 'rick-session-start' \
    "$USER_HOME/.config/hypr/hyprland.lua"
then
    cat >> "$USER_HOME/.config/hypr/hyprland.lua" <<EOF_HYPR

-- Ricks Linux session services
hl.on("hyprland.start", function()
    hl.exec_cmd("/home/$USERNAME/.local/bin/rick-session-start")
end)
EOF_HYPR
fi

# ------------------------------------------------------------
# Automatic login + automatic Hyprland startup
# ------------------------------------------------------------

info "Configuring automatic desktop login..."

install -d \
    "$MOUNTPOINT/etc/systemd/system/getty@tty1.service.d"

sed \
    "s/@USERNAME@/$USERNAME/g" \
    "$SOURCE_DIR/configs/autologin.conf.in" \
    > "$MOUNTPOINT/etc/systemd/system/getty@tty1.service.d/autologin.conf"

# ------------------------------------------------------------
# Correct ownership
# ------------------------------------------------------------

arch-chroot "$MOUNTPOINT" chown \
    -R "$USERNAME:$USERNAME" \
    "/home/$USERNAME"

# ------------------------------------------------------------
# AUR applications
# ------------------------------------------------------------

info "Preparing AUR package installation..."

TEMP_SUDO="$MOUNTPOINT/etc/sudoers.d/99-rick-installer"

cat > "$TEMP_SUDO" <<EOF_SUDO
$USERNAME ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman
EOF_SUDO

chmod 0440 "$TEMP_SUDO"

arch-chroot "$MOUNTPOINT"     visudo -cf /etc/sudoers.d/99-rick-installer >/dev/null

AUR_COMMAND=$(cat <<'EOF_AUR'
set -e

rm -rf /tmp/rick-yay
git clone https://aur.archlinux.org/yay-bin.git /tmp/rick-yay

cd /tmp/rick-yay
makepkg -si --noconfirm

for package in google-chrome aether brother-hll2395dw; do
    echo
    echo "Installing AUR package: $package"

    yay -S \
        --needed \
        --noconfirm \
        --answerclean None \
        --answerdiff None \
        "$package" || \
        echo "WARNING: $package could not be installed."
done
EOF_AUR
)

arch-chroot "$MOUNTPOINT" \
    runuser -u "$USERNAME" -- \
    env HOME="/home/$USERNAME" USER="$USERNAME" LOGNAME="$USERNAME" \
    bash --noprofile --norc -c "$AUR_COMMAND"

rm -f "$TEMP_SUDO"
TEMP_SUDO=""

# ------------------------------------------------------------
# Final checks
# ------------------------------------------------------------

info "Verifying desktop installation..."

for command in \
    Hyprland \
    start-hyprland \
    qs \
    ghostty \
    pcmanfm \
    xed \
    gnome-calculator \
    pavucontrol \
    fastfetch \
    nm-applet \
    nm-connection-editor \
    bluetoothctl \
    system-config-printer
do
    if ! arch-chroot "$MOUNTPOINT" \
        /usr/bin/bash -lc "command -v '$command' >/dev/null"
    then
        echo "Missing required command: $command" >&2
        exit 1
    fi
done

for package in \
    steam \
    google-chrome \
    aether
do
    if ! arch-chroot "$MOUNTPOINT" \
        pacman -Q "$package" >/dev/null 2>&1
    then
        echo "Missing required package: $package" >&2
        exit 1
    fi
done
printf '\n'
printf 'Ricks Linux desktop installation completed.\n'
printf 'Automatic login user: %s\n' "$USERNAME"
printf 'Desktop: Hyprland + Quickshell\n'
