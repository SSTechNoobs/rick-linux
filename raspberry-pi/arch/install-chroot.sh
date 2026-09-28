#!/usr/bin/env bash
set -Eeuo pipefail

source /root/ricks-build.env

# All Ricks Hyprland Raspberry Pi systems use the same visible hostname.
RICK_HOSTNAME="hyprland-arm64"

REPO=/opt/rick-linux
HOME_DIR="/home/$RICK_USER"
PACKAGE_FILE="$REPO/raspberry-pi/arch/packages.txt"

info() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$*"
}

# ------------------------------------------------------------
# Locale / timezone
# ------------------------------------------------------------

info "Configuring locale and timezone..."

sed -i \
    's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
    /etc/locale.gen

locale-gen

echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf

ln -sf \
    /usr/share/zoneinfo/America/Chicago \
    /etc/localtime

echo "$RICK_HOSTNAME" > /etc/hostname

cat > /etc/hosts <<EOF_HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $RICK_HOSTNAME.localdomain $RICK_HOSTNAME
EOF_HOSTS

# ------------------------------------------------------------
# Arch Linux ARM keys
# ------------------------------------------------------------

info "Initializing Arch Linux ARM package keys..."

# Prefer a direct Arch Linux ARM mirror instead of the GeoIP redirector.
cat > /etc/pacman.d/mirrorlist <<'EOF_MIRRORS'
Server = https://ca.us.mirror.archlinuxarm.org/$arch/$repo
Server = https://fl.us.mirror.archlinuxarm.org/$arch/$repo
Server = https://nj.us.mirror.archlinuxarm.org/$arch/$repo
EOF_MIRRORS

pacman-key --init
pacman-key --populate archlinuxarm

pacman --disable-sandbox -Sy \
    --noconfirm \
    archlinuxarm-keyring

pacman --disable-sandbox -Syu --noconfirm

# ------------------------------------------------------------
# Replace generic Pi kernel with Pi 5 kernel
# ------------------------------------------------------------

info "Installing Raspberry Pi 5 BCM2712 kernel..."

for PACKAGE in \
    linux-aarch64 \
    linux-rpi \
    uboot-raspberrypi
do
    if pacman --disable-sandbox -Q "$PACKAGE" >/dev/null 2>&1; then
        pacman --disable-sandbox -Rdd \
            --noconfirm \
            "$PACKAGE"
    fi
done

# Avoid generic x86-oriented hooks in the Pi initramfs.
sed -i \
    's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms block filesystems fsck)/' \
    /etc/mkinitcpio.conf

pacman --disable-sandbox -S \
    --needed \
    --noconfirm \
    --overwrite '/boot/*' \
    linux-rpi-16k \
    raspberrypi-bootloader \
    firmware-raspberrypi \
    linux-firmware \
    wireless-regdb

# ------------------------------------------------------------
# Ricks Hyprland packages
# ------------------------------------------------------------

info "Installing Ricks Hyprland ARM64 packages..."

mapfile -t PACKAGES < <(
    awk '
        {
            sub(/#.*/, "")
            for (i = 1; i <= NF; i++)
                print $i
        }
    ' "$PACKAGE_FILE"
)

pacman --disable-sandbox -S \
    --needed \
    --noconfirm \
    "${PACKAGES[@]}"

# ------------------------------------------------------------
# Pi boot configuration
# ------------------------------------------------------------

info "Configuring Raspberry Pi 5 boot..."

cat > /boot/cmdline.txt <<'EOF_CMDLINE'
root=LABEL=ROOT rw rootwait rootfstype=ext4 quiet loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 fsck.repair=yes
EOF_CMDLINE

cat > /etc/fstab <<'EOF_FSTAB'
LABEL=ROOT  /      ext4  defaults,noatime  0 1
LABEL=BOOT  /boot  vfat  defaults,noatime  0 2
EOF_FSTAB

# linux-rpi-16k supplies the proper Pi VC4/V3D config.txt.
grep -q '^dtoverlay=vc4-kms-v3d' /boot/config.txt || \
    echo 'dtoverlay=vc4-kms-v3d' >> /boot/config.txt

grep -q '^dtparam=audio=on' /boot/config.txt || \
    echo 'dtparam=audio=on' >> /boot/config.txt

grep -q '^arm_64bit=1' /boot/config.txt || \
    echo 'arm_64bit=1' >> /boot/config.txt

# ------------------------------------------------------------
# User
# ------------------------------------------------------------

info "Creating Ricks Hyprland user..."

if ! id "$RICK_USER" >/dev/null 2>&1; then
    useradd \
        -m \
        -G wheel \
        -s /bin/bash \
        "$RICK_USER"
fi

usermod \
    --password "$RICK_PASSHASH" \
    "$RICK_USER"

for GROUP in \
    audio video input render storage lp
do
    if getent group "$GROUP" >/dev/null; then
        usermod -aG "$GROUP" "$RICK_USER"
    fi
done

install -d -m 0750 /etc/sudoers.d

cat > /etc/sudoers.d/10-wheel <<'EOF_SUDO'
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
EOF_SUDO

chmod 0440 /etc/sudoers.d/10-wheel

# Remove default Arch Linux ARM account.
if id alarm >/dev/null 2>&1; then
    userdel -r alarm 2>/dev/null || true
fi

passwd -l root >/dev/null 2>&1 || true

# ------------------------------------------------------------
# System services
# ------------------------------------------------------------

info "Enabling Raspberry Pi services..."

systemctl disable \
    systemd-networkd.service \
    systemd-networkd-wait-online.service \
    2>/dev/null || true

systemctl enable \
    NetworkManager.service \
    bluetooth.service \
    cups.socket

systemctl disable \
    NetworkManager-wait-online.service \
    cups.service \
    cups.path \
    2>/dev/null || true

systemctl mask \
    sshd.service \
    avahi-daemon.service \
    avahi-daemon.socket \
    2>/dev/null || true

# ------------------------------------------------------------
# Ricks Raspberry Pi performance tuning
# ------------------------------------------------------------

info "Applying Raspberry Pi performance tuning..."

# 4 GB compressed RAM swap.
cat > /etc/systemd/zram-generator.conf <<'EOF_ZRAM'
[zram0]
zram-size = 4096
compression-algorithm = zstd
swap-priority = 100
EOF_ZRAM

# Prefer compressed RAM swap and avoid unnecessary swap read-ahead.
cat > /etc/sysctl.d/99-ricks-performance.conf <<'EOF_SYSCTL'
vm.swappiness=100
vm.page-cluster=0
EOF_SYSCTL

# Keep the system journal in RAM to reduce SD-card writes.
install -d /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/99-ricks-performance.conf <<'EOF_JOURNAL'
[Journal]
Storage=volatile
RuntimeMaxUse=64M
EOF_JOURNAL

rm -rf /var/log/journal

# Run all Pi CPU cores with the performance governor.
cat > /usr/local/bin/ricks-performance-governor <<'EOF_GOVERNOR'
#!/usr/bin/env bash
for governor in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
    [[ -e "$governor" ]] || continue
    echo performance > "$governor"
done
EOF_GOVERNOR

chmod 0755 /usr/local/bin/ricks-performance-governor

cat > /etc/systemd/system/ricks-performance-governor.service <<'EOF_GOVERNOR_SERVICE'
[Unit]
Description=Ricks Raspberry Pi CPU Performance Governor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ricks-performance-governor
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_GOVERNOR_SERVICE

systemctl enable ricks-performance-governor.service

# Chrome should exit when its windows close instead of staying in RAM.
install -d /etc/opt/chrome/policies/managed

cat > /etc/opt/chrome/policies/managed/ricks-performance.json <<'EOF_CHROME_POLICY'
{
  "BackgroundModeEnabled": false
}
EOF_CHROME_POLICY

# ------------------------------------------------------------
# NetworkManager Wi-Fi
# ------------------------------------------------------------

if [[ -n "${RICK_WIFI_SSID:-}" ]]; then
    info "Creating Raspberry Pi Wi-Fi profile..."

    install -d -m 0700 \
        /etc/NetworkManager/system-connections

    (
        umask 077

        if [[ -n "${RICK_WIFI_PSK:-}" ]]; then
            nmcli --offline connection add \
                type wifi \
                con-name "Ricks WiFi" \
                ssid "$RICK_WIFI_SSID" \
                wifi-sec.key-mgmt wpa-psk \
                wifi-sec.psk "$RICK_WIFI_PSK" \
                connection.autoconnect yes \
                ipv4.method auto \
                ipv6.method auto \
                > /etc/NetworkManager/system-connections/ricks-wifi.nmconnection
        else
            nmcli --offline connection add \
                type wifi \
                con-name "Ricks WiFi" \
                ssid "$RICK_WIFI_SSID" \
                connection.autoconnect yes \
                ipv4.method auto \
                ipv6.method auto \
                > /etc/NetworkManager/system-connections/ricks-wifi.nmconnection
        fi
    )

    chmod 0600 \
        /etc/NetworkManager/system-connections/ricks-wifi.nmconnection
fi

# ------------------------------------------------------------
# Ricks user directories
# ------------------------------------------------------------

install -d \
    -o "$RICK_USER" \
    -g "$RICK_USER" \
    "$HOME_DIR/.config/hypr" \
    "$HOME_DIR/.config/libfm" \
    "$HOME_DIR/.config/quickshell" \
    "$HOME_DIR/.local/share/applications" \
    "$HOME_DIR/.config/aether/custom/ricks-wallpaper" \
    "$HOME_DIR/.config/systemd/user" \
    "$HOME_DIR/.local/bin" \
    "$HOME_DIR/Desktop" \
    "$HOME_DIR/Documents" \
    "$HOME_DIR/Downloads" \
    "$HOME_DIR/Music" \
    "$HOME_DIR/Pictures/RicksLinuxWallpaper" \
    "$HOME_DIR/Videos"

# ------------------------------------------------------------
# Quickshell
# ------------------------------------------------------------

info "Installing Ricks Quickshell bar..."

rm -rf "$HOME_DIR/.config/quickshell/rick"

cp -a \
    "$REPO/configs/quickshell/rick" \
    "$HOME_DIR/.config/quickshell/"

# The repository contains the exact tested Raspberry Pi Quickshell
# configuration and assets. Do not rewrite shell.qml after copying it.

# ------------------------------------------------------------
# PCManFM
# ------------------------------------------------------------

install -m 0644 \
    "$REPO/configs/libfm/libfm.conf" \
    "$HOME_DIR/.config/libfm/libfm.conf"

# ------------------------------------------------------------
# Ricks application launchers
# ------------------------------------------------------------

install -m 0644 \
    "$REPO/configs/applications/rick-aether.desktop" \
    "$HOME_DIR/.local/share/applications/rick-aether.desktop"

install -m 0644 \
    "$REPO/configs/applications/rick-chatgpt.desktop" \
    "$HOME_DIR/.local/share/applications/rick-chatgpt.desktop"

# ------------------------------------------------------------
# Hyprland
# ------------------------------------------------------------

info "Installing Ricks Hyprland configuration..."

install -m 0644 \
    "$REPO/configs/hypr/hyprland.lua" \
    "$HOME_DIR/.config/hypr/hyprland.lua"

for CONFIG in \
    hyprlauncher.conf \
    hyprtoolkit.conf
do
    if [[ -f "$REPO/configs/hypr/$CONFIG" ]]; then
        install -m 0644 \
            "$REPO/configs/hypr/$CONFIG" \
            "$HOME_DIR/.config/hypr/$CONFIG"
    fi
done

sed -i \
    "s#/home/rick#$HOME_DIR#g" \
    "$HOME_DIR/.config/hypr/hyprland.lua"

# ------------------------------------------------------------
# Wallpaper / Aether profile
# ------------------------------------------------------------

install -m 0644 \
    "$REPO/raspberry-pi/theme/wallpaper.png" \
    "$HOME_DIR/Pictures/RicksLinuxWallpaper/wallpaper.png"

cp -a \
    "$REPO/configs/aether/custom/ricks-wallpaper/." \
    "$HOME_DIR/.config/aether/custom/ricks-wallpaper/"

# ------------------------------------------------------------
# Shared helper scripts
# ------------------------------------------------------------

cp -a \
    "$REPO/scripts/user/." \
    "$HOME_DIR/.local/bin/"

chmod +x "$HOME_DIR/.local/bin/"*

# ------------------------------------------------------------
# Pi update helpers
# ------------------------------------------------------------

cat > "$HOME_DIR/.local/bin/rick-update-count" <<'EOF_COUNT'
#!/usr/bin/env bash
updates="$(checkupdates 2>/dev/null || true)"
printf '%s\n' "$updates" | sed '/^$/d' | wc -l
EOF_COUNT

cat > "$HOME_DIR/.local/bin/rick-update-check" <<'EOF_CHECK'
#!/usr/bin/env bash

updates="$(checkupdates 2>/dev/null || true)"

count="$(
    printf '%s\n' "$updates" |
    sed '/^$/d' |
    wc -l
)"

if (( count > 0 )); then
    names="$(
        printf '%s\n' "$updates" |
        sed '/^$/d' |
        awk '{print $1}' |
        head -8 |
        paste -sd, - |
        sed 's/,/, /g'
    )"

    body="$count Arch update(s) available"

    if [[ -n "$names" ]]; then
        body+=$'\n\n'"$names"
    fi

    notify-send \
        -a "Ricks Hyprland" \
        -i system-software-update \
        "Ricks Hyprland Updates Available" \
        "$body"
fi
EOF_CHECK

cat > "$HOME_DIR/.local/bin/rick-update-install" <<'EOF_INSTALL'
#!/usr/bin/env bash

echo "Ricks Hyprland Raspberry Pi Updater"
echo "==================================="
echo

sudo pacman -Syu
EOF_INSTALL

chmod +x \
    "$HOME_DIR/.local/bin/rick-update-count" \
    "$HOME_DIR/.local/bin/rick-update-check" \
    "$HOME_DIR/.local/bin/rick-update-install"

# ------------------------------------------------------------
# Terminal / browser compatibility
# ------------------------------------------------------------


info "Installing Google Chrome ARM64..."

CHROME_DEB="/tmp/google-chrome-stable-arm64.deb"
CHROME_TMP="$(mktemp -d)"

CHROME_SCHEME="https"
CHROME_HOST="dl.google.com"
CHROME_URL="${CHROME_SCHEME}://${CHROME_HOST}/linux/direct/google-chrome-stable_current_arm64.deb"

curl -fL \
    "$CHROME_URL" \
    -o "$CHROME_DEB"

(
    cd "$CHROME_TMP"
    ar x "$CHROME_DEB"

    DATA_ARCHIVE="$(
        find . -maxdepth 1 -type f -name 'data.tar.*' -print -quit
    )"

    if [[ -z "$DATA_ARCHIVE" ]]; then
        echo "Could not find Chrome data archive." >&2
        exit 1
    fi

    bsdtar -xpf "$DATA_ARCHIVE" -C /
)

rm -rf "$CHROME_TMP" "$CHROME_DEB"

if [[ ! -x /usr/bin/google-chrome-stable ]]; then
    echo "Google Chrome ARM64 installation failed." >&2
    exit 1
fi

cat > /usr/local/bin/xed <<'EOF_XED'
#!/usr/bin/env bash
exec mousepad "$@"
EOF_XED

chmod 0755 \
    /usr/bin/xfce4-terminal \
    /usr/local/bin/xed

# Xfce Terminal - clean Ricks Hyprland appearance
install -d -m 0755 \
    "$HOME_DIR/.config/xfce4/terminal"

cat > "$HOME_DIR/.config/xfce4/terminal/terminalrc" <<'EOF_TERMINAL'
[Configuration]
MiscMenubarDefault=FALSE
MiscShowUnsafePasteDialog=FALSE
ScrollingBar=TERMINAL_SCROLLBAR_NONE
EOF_TERMINAL

# ------------------------------------------------------------
# Aether ARM64 binary
# ------------------------------------------------------------

info "Installing Aether ARM64..."

AETHER_URL="$(
    curl -fsSL \
        https://api.github.com/repos/omacom/aether/releases/latest |
    jq -r '
        .assets[]
        | select(.name == "aether-linux-arm64")
        | .browser_download_url
    ' |
    head -n1
)"

if [[ -n "$AETHER_URL" && "$AETHER_URL" != "null" ]]; then
    curl -fL \
        "$AETHER_URL" \
        -o /usr/local/bin/aether

    chmod 0755 /usr/local/bin/aether
else
    echo "WARNING: Aether ARM64 download was not found."
fi


# ------------------------------------------------------------
# Session startup
# ------------------------------------------------------------

# The exact tested Raspberry Pi session startup script is installed
# with the shared helpers from scripts/user/rick-session-start.

# ------------------------------------------------------------
# Weekly update notification
# ------------------------------------------------------------

install -m 0644 \
    "$REPO/raspberry-pi/systemd/user/rick-update-check.service" \
    "$HOME_DIR/.config/systemd/user/rick-update-check.service"

install -m 0644 \
    "$REPO/raspberry-pi/systemd/user/rick-update-check.timer" \
    "$HOME_DIR/.config/systemd/user/rick-update-check.timer"

mkdir -p \
    "$HOME_DIR/.config/systemd/user/timers.target.wants"

ln -sf \
    ../rick-update-check.timer \
    "$HOME_DIR/.config/systemd/user/timers.target.wants/rick-update-check.timer"

# ------------------------------------------------------------
# XDG directories
# ------------------------------------------------------------

cat > "$HOME_DIR/.config/user-dirs.dirs" <<'EOF_XDG'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
XDG_TEMPLATES_DIR="$HOME/"
XDG_PUBLICSHARE_DIR="$HOME/"
EOF_XDG

# ------------------------------------------------------------
# Auto-login + Hyprland startup
# ------------------------------------------------------------

install -d \
    /etc/systemd/system/getty@tty1.service.d

cat > /etc/systemd/system/getty@tty1.service.d/10-fast-start.conf <<'EOF_FAST_GETTY'
[Service]
Type=simple
EOF_FAST_GETTY

cat > \
    /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF_AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $RICK_USER --noclear %I \$TERM
EOF_AUTOLOGIN

cat > "$HOME_DIR/.bash_profile" <<'EOF_PROFILE'
if [ -z "${WAYLAND_DISPLAY:-}" ] &&
   [ "$(tty)" = "/dev/tty1" ]; then
    exec start-hyprland
fi
EOF_PROFILE

cat >> "$HOME_DIR/.bashrc" <<'EOF_BASHRC'

# Ricks Hyprland ARM64 terminal prompt
PS1='[ricks@hyprland-arm64 \W]\$ '
EOF_BASHRC

# ------------------------------------------------------------
# Branding
# ------------------------------------------------------------

cat > /etc/rick-linux-release <<'EOF_RELEASE'
NAME="Ricks Hyprland"
ID=ricks-hyprland
VERSION="Pi Arch 0.1"
BASE="Arch Linux ARM"
ARCH="aarch64"
HARDWARE="Raspberry Pi 5"
EOF_RELEASE

date --iso-8601=seconds \
    > /etc/rick-linux-install-date

# ------------------------------------------------------------
# Permissions
# ------------------------------------------------------------

chown -R \
    "$RICK_USER:$RICK_USER" \
    "$HOME_DIR"

# ------------------------------------------------------------
# Unique machine identity
# ------------------------------------------------------------

# Leave machine-id empty in the master image. systemd generates a unique
# identity the first time each physical Raspberry Pi boots.
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id

# ------------------------------------------------------------
# Final check
# ------------------------------------------------------------

info "Verifying Arch Raspberry Pi 5 installation..."

for COMMAND in \
    Hyprland \
    start-hyprland \
    qs \
    hyprlauncher \
    xfce4-terminal \
    google-chrome-stable \
    pcmanfm \
    nmcli \
    bluetoothctl \
    wpctl \
    notify-send
do
    command -v "$COMMAND" >/dev/null || {
        echo "Missing required command: $COMMAND" >&2
        exit 1
    }

    echo "OK: $COMMAND"
done

echo
echo "Ricks Hyprland Arch Linux ARM configuration complete."
