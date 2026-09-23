#!/usr/bin/env bash
set -Eeuo pipefail

info() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$*"
}

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

# ------------------------------------------------------------
# Safety checks
# ------------------------------------------------------------

[[ $EUID -ne 0 ]] || \
    die "Run this as your normal user, not with sudo."

[[ "$(uname -m)" == "aarch64" ]] || \
    die "This installer requires Raspberry Pi OS 64-bit (aarch64)."

grep -qa "Raspberry Pi" /proc/device-tree/model 2>/dev/null || \
    die "This does not appear to be a Raspberry Pi."

source /etc/os-release

[[ "${VERSION_CODENAME:-}" == "trixie" ]] || \
    die "Raspberry Pi OS Trixie is required."

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$SCRIPT_DIR/packages.txt" ]] || \
    die "packages.txt not found."

[[ -f "$SCRIPT_DIR/packages-backports.txt" ]] || \
    die "packages-backports.txt not found."

[[ -d "$REPO_ROOT/configs/quickshell/rick" ]] || \
    die "Ricks Hyprland configuration files were not found."

TARGET_USER="$USER"
TARGET_HOME="$HOME"

info "Installing Ricks Hyprland for Raspberry Pi"
echo "User: $TARGET_USER"
echo "Home: $TARGET_HOME"
echo "Model: $(tr -d '\0' </proc/device-tree/model)"

# ------------------------------------------------------------
# Update Raspberry Pi OS
# ------------------------------------------------------------

info "Updating Raspberry Pi OS..."

sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive \
    apt-get full-upgrade -y

# ------------------------------------------------------------
# Debian Trixie backports
# ------------------------------------------------------------

info "Enabling Debian Trixie backports..."

if [[ -f /usr/share/keyrings/debian-archive-keyring.pgp ]]; then
    DEBIAN_KEYRING="/usr/share/keyrings/debian-archive-keyring.pgp"
else
    DEBIAN_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
fi

sudo tee /etc/apt/sources.list.d/ricks-hyprland-backports.sources \
    >/dev/null <<EOF_BACKPORTS
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Signed-By: $DEBIAN_KEYRING
EOF_BACKPORTS

sudo apt-get update

# ------------------------------------------------------------
# Standard packages
# ------------------------------------------------------------

info "Installing Raspberry Pi desktop packages..."

mapfile -t PACKAGES < <(
    sed 's/#.*//' "$SCRIPT_DIR/packages.txt" |
    tr ' \t' '\n' |
    sed '/^$/d'
)

sudo DEBIAN_FRONTEND=noninteractive \
    apt-get install -y "${PACKAGES[@]}"

# ------------------------------------------------------------
# Hyprland packages from backports
# ------------------------------------------------------------

info "Installing Hyprland + Quickshell from backports..."

mapfile -t BACKPORT_PACKAGES < <(
    sed 's/#.*//' "$SCRIPT_DIR/packages-backports.txt" |
    tr ' \t' '\n' |
    sed '/^$/d'
)

sudo DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
    -t trixie-backports \
    "${BACKPORT_PACKAGES[@]}"

# ------------------------------------------------------------
# System services
# ------------------------------------------------------------

info "Enabling system services..."

for SERVICE in \
    NetworkManager.service \
    bluetooth.service \
    cups.service \
    avahi-daemon.service
do
    sudo systemctl enable "$SERVICE"
done

# ------------------------------------------------------------
# Raspberry Pi user groups
# ------------------------------------------------------------

info "Configuring Raspberry Pi hardware access..."

for GROUP in video render audio bluetooth lpadmin; do
    if getent group "$GROUP" >/dev/null; then
        sudo usermod -aG "$GROUP" "$TARGET_USER"
    fi
done

# ------------------------------------------------------------
# User directories
# ------------------------------------------------------------

info "Installing Ricks Hyprland configuration..."

mkdir -p \
    "$TARGET_HOME/.config/hypr" \
    "$TARGET_HOME/.config/quickshell" \
    "$TARGET_HOME/.local/bin" \
    "$TARGET_HOME/Desktop" \
    "$TARGET_HOME/Documents" \
    "$TARGET_HOME/Downloads" \
    "$TARGET_HOME/Music" \
    "$TARGET_HOME/Pictures/RicksLinuxSplash" \
    "$TARGET_HOME/Pictures/RicksLinuxWallpaper" \
    "$TARGET_HOME/Videos"

# Quickshell
rm -rf "$TARGET_HOME/.config/quickshell/rick"

cp -a \
    "$REPO_ROOT/configs/quickshell/rick" \
    "$TARGET_HOME/.config/quickshell/"


# Raspberry Pi update commands for the shared Quickshell bar
PI_QML="$TARGET_HOME/.config/quickshell/rick/shell.qml"

python3 - "$PI_QML" <<'PY_QML'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

old_count = """{ checkupdates 2>/dev/null || true; yay -Qua 2>/dev/null || true; } | sed '/^$/d' | wc -l"""
new_count = """$HOME/.local/bin/rick-update-count"""

old_update = """yay -Syu; rc=$?; echo; if [ $rc -eq 0 ]; then echo 'Updates finished.'; else echo 'Update returned an error.'; fi; echo; echo 'This window will close in 5 seconds...'; sleep 5; exit $rc"""

new_update = """$HOME/.local/bin/rick-update-install; rc=$?; echo; if [ $rc -eq 0 ]; then echo 'Updates finished.'; else echo 'Update returned an error.'; fi; echo; echo 'This window will close in 5 seconds...'; sleep 5; exit $rc"""

if old_count not in text:
    raise SystemExit("Could not find Arch update-count command in shell.qml")

if old_update not in text:
    raise SystemExit("Could not find Arch update-install command in shell.qml")

text = text.replace(old_count, new_count)
text = text.replace(old_update, new_update)

path.write_text(text)
PY_QML

# Hyprland Lua configuration
install -m 0644 \
    "$REPO_ROOT/configs/hypr/hyprland.lua" \
    "$TARGET_HOME/.config/hypr/hyprland.lua"

for CONFIG in hyprlauncher.conf hyprtoolkit.conf; do
    if [[ -f "$REPO_ROOT/configs/hypr/$CONFIG" ]]; then
        install -m 0644 \
            "$REPO_ROOT/configs/hypr/$CONFIG" \
            "$TARGET_HOME/.config/hypr/$CONFIG"
    fi
done

# Replace hard-coded Minisforum home path when necessary
sed -i \
    "s#/home/rick#$TARGET_HOME#g" \
    "$TARGET_HOME/.config/hypr/hyprland.lua"

# Wallpaper
install -m 0644 \
    "$REPO_ROOT/configs/wallpaper/wallpaper.png" \
    "$TARGET_HOME/Pictures/RicksLinuxWallpaper/wallpaper.png"

# Splash artwork
if [[ -d "$REPO_ROOT/configs/splash/RicksLinuxSplash" ]]; then
    cp -a \
        "$REPO_ROOT/configs/splash/RicksLinuxSplash/." \
        "$TARGET_HOME/Pictures/RicksLinuxSplash/"
fi

# ------------------------------------------------------------
# Shared Ricks helper scripts
# ------------------------------------------------------------

info "Installing Ricks helper scripts..."

if [[ -d "$REPO_ROOT/scripts/user" ]]; then
    cp -a \
        "$REPO_ROOT/scripts/user/." \
        "$TARGET_HOME/.local/bin/"

    chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true
fi


# Raspberry Pi versions override Arch-specific helpers
if [[ -d "$SCRIPT_DIR/scripts" ]]; then
    cp -a \
        "$SCRIPT_DIR/scripts/." \
        "$TARGET_HOME/.local/bin/"

    chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true
fi

# ------------------------------------------------------------
# Pi wallpaper helper
# ------------------------------------------------------------

cat > "$TARGET_HOME/.local/bin/rick-wallpaper-apply" <<'EOF_WALLPAPER'
#!/usr/bin/env bash

WALLPAPER="$HOME/Pictures/RicksLinuxWallpaper/wallpaper.png"

[[ -f "$WALLPAPER" ]] || exit 0

pkill -x swaybg 2>/dev/null || true

setsid -f swaybg \
    -i "$WALLPAPER" \
    -m fill \
    >/dev/null 2>&1
EOF_WALLPAPER

chmod 0755 \
    "$TARGET_HOME/.local/bin/rick-wallpaper-apply"

# ------------------------------------------------------------
# Session startup
# ------------------------------------------------------------

cat > "$TARGET_HOME/.local/bin/rick-session-start" <<'EOF_SESSION'
#!/usr/bin/env bash

systemctl --user import-environment \
    WAYLAND_DISPLAY \
    DISPLAY \
    XDG_CURRENT_DESKTOP \
    HYPRLAND_INSTANCE_SIGNATURE \
    >/dev/null 2>&1 || true

systemctl --user start mako.service \
    >/dev/null 2>&1 || true

systemctl --user start hyprpolkitagent.service \
    >/dev/null 2>&1 || true

pgrep -x nm-applet >/dev/null 2>&1 || \
    setsid -f nm-applet --indicator \
    >/dev/null 2>&1

"$HOME/.local/bin/rick-wallpaper-apply"
EOF_SESSION

chmod 0755 \
    "$TARGET_HOME/.local/bin/rick-session-start"

# ------------------------------------------------------------
# Ensure session startup exists in Lua
# ------------------------------------------------------------

if ! grep -q 'rick-session-start' \
    "$TARGET_HOME/.config/hypr/hyprland.lua"
then
    cat >> "$TARGET_HOME/.config/hypr/hyprland.lua" <<'EOF_HYPR'

-- Ricks Hyprland Raspberry Pi session
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/rick-session-start")
end)
EOF_HYPR
fi

# ------------------------------------------------------------
# Ghostty compatibility
# Pi uses Foot initially
# ------------------------------------------------------------

info "Creating Pi application compatibility commands..."

sudo tee /usr/local/bin/ghostty >/dev/null <<'EOF_GHOSTTY'
#!/bin/sh
exec foot "$@"
EOF_GHOSTTY

sudo chmod 0755 /usr/local/bin/ghostty

# Chrome compatibility
sudo tee /usr/local/bin/google-chrome-stable >/dev/null <<'EOF_CHROME'
#!/bin/sh
exec chromium "$@"
EOF_CHROME

sudo chmod 0755 /usr/local/bin/google-chrome-stable

# ------------------------------------------------------------
# XDG user directories
# ------------------------------------------------------------

cat > "$TARGET_HOME/.config/user-dirs.dirs" <<'EOF_XDG'
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
# Automatic login
# ------------------------------------------------------------

info "Configuring automatic login..."

sudo mkdir -p \
    /etc/systemd/system/getty@tty1.service.d

sudo tee \
    /etc/systemd/system/getty@tty1.service.d/autologin.conf \
    >/dev/null <<EOF_AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $TARGET_USER --noclear %I \$TERM
EOF_AUTOLOGIN

# ------------------------------------------------------------
# Automatically launch Hyprland on tty1
# ------------------------------------------------------------

touch "$TARGET_HOME/.bash_profile"

if ! grep -q 'RICKS_HYPRLAND_AUTOSTART' \
    "$TARGET_HOME/.bash_profile"
then
    cat >> "$TARGET_HOME/.bash_profile" <<'EOF_PROFILE'

# RICKS_HYPRLAND_AUTOSTART
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec start-hyprland
fi
EOF_PROFILE
fi

# ------------------------------------------------------------
# Ricks system marker
# ------------------------------------------------------------

sudo tee /etc/rick-linux-release >/dev/null <<'EOF_RELEASE'
NAME="Ricks Hyprland"
ID=ricks-hyprland
VERSION="Pi 0.1"
BASE="Raspberry Pi OS Lite"
ARCH="aarch64"
EOF_RELEASE

date --iso-8601=seconds | \
    sudo tee /etc/rick-linux-install-date >/dev/null

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

info "Verifying installation..."

for COMMAND in \
    Hyprland \
    start-hyprland \
    hyprctl \
    qs \
    hyprlauncher \
    foot \
    chromium \
    pcmanfm \
    nm-applet \
    bluetoothctl \
    wpctl \
    notify-send
do
    if ! command -v "$COMMAND" >/dev/null; then
        echo "WARNING: Missing command: $COMMAND"
    else
        printf 'OK: %s\n' "$COMMAND"
    fi
done

echo
echo "============================================"
echo " Ricks Hyprland Raspberry Pi base installed"
echo "============================================"
echo
echo "User:    $TARGET_USER"
echo "Desktop: Hyprland + Quickshell"
echo "Base:    Raspberry Pi OS Lite / Debian Trixie"
echo
echo "Reboot when ready:"
echo
echo "    sudo reboot"
echo
