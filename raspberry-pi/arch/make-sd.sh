#!/usr/bin/env bash
set -Eeuo pipefail

DEVICE="${1:-/dev/sda}"

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"

REPO_ROOT="$(
    cd "$SCRIPT_DIR/../.." &&
    pwd
)"

ROOTFS_NAME="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
ROOTFS_URL="https://ca.us.mirror.archlinuxarm.org/os/$ROOTFS_NAME"
ROOTFS_MD5_URL="$ROOTFS_URL.md5"

CACHE_DIR="$HOME/Downloads/ricks-pi-arch"
ROOTFS="$CACHE_DIR/$ROOTFS_NAME"
MD5_FILE="$ROOTFS.md5"

PI_USER="rick"
PI_HOSTNAME="ricks-pi"

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$*"
}

# ------------------------------------------------------------
# Required tools
# ------------------------------------------------------------

for CMD in \
    qemu-aarch64-static \
    arch-chroot \
    bsdtar \
    parted \
    mkfs.vfat \
    mkfs.ext4 \
    curl \
    rsync \
    openssl
do
    command -v "$CMD" >/dev/null || \
        die "Missing required command: $CMD"
done

[[ -b "$DEVICE" ]] || \
    die "$DEVICE is not a block device."

case "$DEVICE" in
    /dev/nvme*|/dev/mmcblk*)
        die "Refusing unexpected target device $DEVICE"
        ;;
esac

TRAN="$(
    lsblk -ndo TRAN "$DEVICE" |
    xargs
)"

[[ "$TRAN" == "usb" ]] || \
    die "$DEVICE is not a USB-attached device."

ROOT_SOURCE="$(findmnt -no SOURCE /)"

ROOT_PARENT="$(
    lsblk -no PKNAME "$ROOT_SOURCE" 2>/dev/null |
    head -n1
)"

if [[ -n "$ROOT_PARENT" &&
      "/dev/$ROOT_PARENT" == "$DEVICE" ]]
then
    die "Refusing to overwrite the running system disk."
fi

if [[ "$DEVICE" =~ [0-9]$ ]]; then
    BOOT_PART="${DEVICE}p1"
    ROOT_PART="${DEVICE}p2"
else
    BOOT_PART="${DEVICE}1"
    ROOT_PART="${DEVICE}2"
fi

echo
echo "=============================================="
echo " RICKS HYPRLAND - ARCH LINUX ARM - PI 5"
echo "=============================================="
echo
echo "TARGET:"
lsblk -d -o NAME,SIZE,MODEL,TRAN "$DEVICE"

echo
echo "THIS WILL ERASE EVERYTHING ON:"
echo
echo "    $DEVICE"
echo

read -rp "Type ERASE $DEVICE to continue: " CONFIRM

[[ "$CONFIRM" == "ERASE $DEVICE" ]] || \
    die "Cancelled."

# ------------------------------------------------------------
# Pi user password
# ------------------------------------------------------------

echo
read -rsp "Password for Pi user '$PI_USER': " PI_PASS
echo
read -rsp "Enter password again: " PI_PASS2
echo

[[ -n "$PI_PASS" ]] || \
    die "Password cannot be empty."

[[ "$PI_PASS" == "$PI_PASS2" ]] || \
    die "Passwords do not match."

PI_PASSHASH="$(
    printf '%s' "$PI_PASS" |
    openssl passwd -6 -stdin
)"

unset PI_PASS PI_PASS2

# ------------------------------------------------------------
# Wi-Fi
# ------------------------------------------------------------

WIFI_SSID=""
WIFI_PSK=""

CURRENT_WIFI="$(
    nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null |
    sed -n 's/^yes://p' |
    head -n1 |
    sed 's/\\:/:/g'
)"

if [[ -n "$CURRENT_WIFI" ]]; then
    echo
    echo "Current Wi-Fi:"
    echo "    $CURRENT_WIFI"
    echo

    read -rp "Use this Wi-Fi on the Raspberry Pi? [Y/n]: " ANSWER

    if [[ ! "${ANSWER:-Y}" =~ ^[Nn]$ ]]; then
        WIFI_SSID="$CURRENT_WIFI"

        WIFI_DEVICE="$(
            nmcli -t -f DEVICE,TYPE,STATE device status |
            awk -F: \
                '$2 == "wifi" && $3 == "connected" {print $1; exit}'
        )"

        if [[ -n "$WIFI_DEVICE" ]]; then
            WIFI_CONNECTION="$(
                nmcli -g GENERAL.CONNECTION \
                    device show "$WIFI_DEVICE" \
                    2>/dev/null || true
            )"

            if [[ -n "$WIFI_CONNECTION" &&
                  "$WIFI_CONNECTION" != "--" ]]
            then
                WIFI_PSK="$(
                    sudo nmcli \
                        --show-secrets \
                        -g 802-11-wireless-security.psk \
                        connection show "$WIFI_CONNECTION" \
                        2>/dev/null || true
                )"
            fi
        fi
    fi
fi

if [[ -z "$WIFI_SSID" ]]; then
    echo
    read -rp \
        "Wi-Fi SSID (leave blank for Ethernet only): " \
        WIFI_SSID
fi

if [[ -n "$WIFI_SSID" &&
      -z "$WIFI_PSK" ]]
then
    read -rsp "Wi-Fi password: " WIFI_PSK
    echo
fi

# ------------------------------------------------------------
# Root filesystem download
# ------------------------------------------------------------

mkdir -p "$CACHE_DIR"

info "Checking Arch Linux ARM root filesystem..."

curl -fL \
    "$ROOTFS_MD5_URL" \
    -o "$MD5_FILE"

EXPECTED_MD5="$(
    awk '{print $1}' "$MD5_FILE" |
    head -n1
)"

[[ -n "$EXPECTED_MD5" ]] || \
    die "Could not read Arch Linux ARM checksum."

if [[ ! -f "$ROOTFS" ]] ||
   ! echo "$EXPECTED_MD5  $ROOTFS" |
        md5sum -c --status
then
    info "Downloading Arch Linux ARM AArch64 root filesystem..."

    rm -f "$ROOTFS"

    curl -fL \
        "$ROOTFS_URL" \
        -o "$ROOTFS"
fi

info "Verifying Arch Linux ARM download..."

echo "$EXPECTED_MD5  $ROOTFS" |
    md5sum -c - ||
    die "Root filesystem checksum failed."

# ------------------------------------------------------------
# Partition SD card
# ------------------------------------------------------------

info "Unmounting old SD-card partitions..."

sudo umount "${DEVICE}"?* \
    2>/dev/null || true

info "Erasing old filesystem signatures..."

sudo wipefs -af "$DEVICE"

info "Creating Raspberry Pi partition table..."

sudo parted -s "$DEVICE" \
    mklabel msdos

sudo parted -s "$DEVICE" \
    mkpart primary fat32 1MiB 1025MiB

sudo parted -s "$DEVICE" \
    set 1 boot on

sudo parted -s "$DEVICE" \
    mkpart primary ext4 1025MiB 100%

sudo partprobe "$DEVICE"
sudo udevadm settle
sleep 2

[[ -b "$BOOT_PART" ]] || \
    die "$BOOT_PART was not created."

[[ -b "$ROOT_PART" ]] || \
    die "$ROOT_PART was not created."

# ------------------------------------------------------------
# Filesystems
# ------------------------------------------------------------

info "Creating Raspberry Pi boot filesystem..."

sudo mkfs.vfat \
    -F 32 \
    -n BOOT \
    "$BOOT_PART"

info "Creating Arch Linux root filesystem..."

sudo mkfs.ext4 \
    -F \
    -L ROOT \
    "$ROOT_PART"

# ------------------------------------------------------------
# Mount filesystems
# ------------------------------------------------------------

WORK_DIR="$(
    mktemp -d \
        /tmp/ricks-pi-arch.XXXXXX
)"

ROOT_MNT="$WORK_DIR/root"

sudo mkdir -p "$ROOT_MNT"

cleanup() {
    set +e

    sudo umount \
        "$ROOT_MNT/boot" \
        2>/dev/null

    sudo umount \
        "$ROOT_MNT" \
        2>/dev/null

    sudo rm -rf "$WORK_DIR"
}

trap cleanup EXIT

sudo mount \
    "$ROOT_PART" \
    "$ROOT_MNT"

# ------------------------------------------------------------
# Extract Arch Linux ARM
# ------------------------------------------------------------

info "Extracting Arch Linux ARM..."

sudo bsdtar \
    -xpf "$ROOTFS" \
    -C "$ROOT_MNT"

sudo mkdir -p \
    "$ROOT_MNT/boot"

# We are replacing the rootfs boot files with the Pi-5 kernel.
sudo find \
    "$ROOT_MNT/boot" \
    -mindepth 1 \
    -maxdepth 1 \
    -exec rm -rf -- {} +

sudo mount \
    "$BOOT_PART" \
    "$ROOT_MNT/boot"

# ------------------------------------------------------------
# QEMU ARM64 support
# ------------------------------------------------------------

info "Preparing ARM64 chroot..."

sudo install \
    -m 0755 \
    "$(command -v qemu-aarch64-static)" \
    "$ROOT_MNT/usr/bin/qemu-aarch64-static"

# ------------------------------------------------------------
# Copy current Ricks Hyprland project
# ------------------------------------------------------------

sudo mkdir -p \
    "$ROOT_MNT/opt/rick-linux"

sudo rsync \
    -a \
    --delete \
    --exclude='.git' \
    --exclude='PROJECT_STATE.md' \
    "$REPO_ROOT/" \
    "$ROOT_MNT/opt/rick-linux/"

# ------------------------------------------------------------
# DNS for build chroot
# ------------------------------------------------------------

sudo rm -f \
    "$ROOT_MNT/etc/resolv.conf"

sudo cp -L \
    /etc/resolv.conf \
    "$ROOT_MNT/etc/resolv.conf"

# ------------------------------------------------------------
# Build environment
# ------------------------------------------------------------

BUILD_ENV="$WORK_DIR/ricks-build.env"

{
    printf 'RICK_USER=%q\n' "$PI_USER"
    printf 'RICK_HOSTNAME=%q\n' "$PI_HOSTNAME"
    printf 'RICK_PASSHASH=%q\n' "$PI_PASSHASH"
    printf 'RICK_WIFI_SSID=%q\n' "$WIFI_SSID"
    printf 'RICK_WIFI_PSK=%q\n' "$WIFI_PSK"
} > "$BUILD_ENV"

chmod 0600 "$BUILD_ENV"

sudo install \
    -m 0600 \
    "$BUILD_ENV" \
    "$ROOT_MNT/root/ricks-build.env"

unset WIFI_PSK
unset PI_PASSHASH

# ------------------------------------------------------------
# Run Arch ARM installation
# ------------------------------------------------------------

info "Entering ARM64 system through QEMU..."

sudo arch-chroot \
    "$ROOT_MNT" \
    /bin/bash \
    /opt/rick-linux/raspberry-pi/arch/install-chroot.sh

# ------------------------------------------------------------
# Final target cleanup
# ------------------------------------------------------------

info "Cleaning build-only files..."

sudo rm -f \
    "$ROOT_MNT/root/ricks-build.env"

sudo rm -f \
    "$ROOT_MNT/usr/bin/qemu-aarch64-static"

sudo rm -f \
    "$ROOT_MNT/etc/resolv.conf"

sudo ln -s \
    /run/NetworkManager/resolv.conf \
    "$ROOT_MNT/etc/resolv.conf"

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

info "Verifying Raspberry Pi 5 boot files..."

sudo test -f \
    "$ROOT_MNT/boot/kernel8.img" ||
    die "Pi 5 kernel8.img is missing."

sudo test -f \
    "$ROOT_MNT/boot/bcm2712-rpi-5-b.dtb" ||
    die "Raspberry Pi 5 device tree is missing."

sudo test -f \
    "$ROOT_MNT/boot/config.txt" ||
    die "config.txt is missing."

sudo grep -q \
    'root=LABEL=ROOT' \
    "$ROOT_MNT/boot/cmdline.txt" ||
    die "Pi root boot argument is missing."

sudo test -x \
    "$ROOT_MNT/usr/bin/Hyprland" ||
    die "Hyprland is missing."

sudo test -x \
    "$ROOT_MNT/usr/bin/qs" ||
    die "Quickshell is missing."

sudo test -f \
    "$ROOT_MNT/etc/rick-linux-release" ||
    die "Ricks Hyprland marker is missing."

echo
echo "=== BOOT ==="
sudo ls -lh \
    "$ROOT_MNT/boot/kernel8.img" \
    "$ROOT_MNT/boot/bcm2712-rpi-5-b.dtb" \
    "$ROOT_MNT/boot/initramfs-linux.img"

echo
echo "=== RICKS HYPRLAND ==="
sudo cat \
    "$ROOT_MNT/etc/rick-linux-release"

sync

cleanup
trap - EXIT

echo
echo "=============================================="
echo " RICKS HYPRLAND ARCH PI 5 SD CARD IS READY"
echo "=============================================="
echo
echo "Device:   $DEVICE"
echo "User:     $PI_USER"
echo "Hostname: $PI_HOSTNAME"
echo
echo "The card is unmounted and safe to remove."
echo
echo "Put it in the Raspberry Pi 5 and power it on."
echo
