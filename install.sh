#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="Rick Linux Installer"
VERSION="0.2.0"
MOUNTPOINT="/mnt"

red='\033[0;31m'; green='\033[0;32m'; yellow='\033[1;33m'; blue='\033[0;34m'; reset='\033[0m'

info(){ printf "%b[INFO]%b %s\n" "$blue" "$reset" "$*"; }
ok(){ printf "%b[ OK ]%b %s\n" "$green" "$reset" "$*"; }
warn(){ printf "%b[WARN]%b %s\n" "$yellow" "$reset" "$*"; }
die(){ printf "%b[FAIL]%b %s\n" "$red" "$reset" "$*" >&2; exit 1; }

on_error(){
  local rc=$?
  printf "\n%b[FAIL]%b Installer stopped at line %s (exit %s).\n" "$red" "$reset" "$1" "$rc" >&2
  printf "The target may be partially installed. Do not reboot until the error is reviewed.\n" >&2
  exit "$rc"
}
trap 'on_error $LINENO' ERR

banner(){
  cat <<'BANNER'
=================================================
              Rick Linux Installer
          Arch Linux base installation
=================================================
BANNER
  printf "Version: %s\n\n" "$VERSION"
}

require_root(){
  [[ $EUID -eq 0 ]] || die "Run this from the official Arch ISO as root."
}

require_archiso(){
  [[ -r /etc/os-release ]] || die "/etc/os-release is missing."
  . /etc/os-release
  [[ "${ID:-}" == "arch" ]] || die "Expected the official Arch Linux ISO. Detected: ${PRETTY_NAME:-unknown}"
  command -v pacstrap >/dev/null 2>&1 || die "pacstrap is missing."
  ok "Arch installation environment detected."
}

require_uefi(){
  [[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode. Reboot the USB using its UEFI entry."
  ok "UEFI mode detected."
}

require_tools(){
  local tools=(lsblk findmnt ping timedatectl sgdisk wipefs partprobe udevadm mkfs.fat mkfs.ext4 mount umount blkid pacstrap genfstab arch-chroot lscpu)
  local missing=()
  local tool
  for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  ((${#missing[@]} == 0)) || die "Missing required Arch ISO tools: ${missing[*]}"
  ok "Required installation tools are available."
}

require_internet(){
  if ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    ok "Internet connection is working."
  else
    die "No internet connection. Connect Ethernet or Wi-Fi before continuing."
  fi
}

check_clock(){
  timedatectl set-ntp true >/dev/null 2>&1 || true
  ok "Clock synchronization requested."
}

ensure_mountpoint_clear(){
  if findmnt -rn -M "$MOUNTPOINT" >/dev/null 2>&1; then
    die "$MOUNTPOINT is already mounted. Reboot the Arch ISO before running this installer."
  fi
}

list_and_select_disk(){
  local disk transport choice i
  mapfile -t DISKS < <(
    while read -r disk; do
      transport="$(lsblk -dn -o TRAN "$disk" 2>/dev/null | tr -d '[:space:]')"
      [[ "$transport" == "usb" ]] && continue
      printf '%s\n' "$disk"
    done < <(lsblk -dpno NAME,TYPE | awk '$2=="disk" {print $1}')
  )

  ((${#DISKS[@]} > 0)) || die "No non-USB physical disks were found."

  printf "\nInternal installation targets:\n\n"
  for i in "${!DISKS[@]}"; do
    disk="${DISKS[$i]}"
    printf "  %d) %s\n" "$((i+1))" "$disk"
    lsblk -dno SIZE,MODEL,SERIAL,TRAN "$disk" | sed 's/^/     /'
    printf "\n"
  done

  while true; do
    read -r -p "Select target disk [1-${#DISKS[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { warn "Enter a number from the list."; continue; }
    (( choice >= 1 && choice <= ${#DISKS[@]} )) || { warn "Selection out of range."; continue; }
    TARGET_DISK="${DISKS[$((choice-1))]}"
    break
  done

  [[ -b "$TARGET_DISK" ]] || die "$TARGET_DISK is not a block device."
  [[ "$(lsblk -dn -o TYPE "$TARGET_DISK")" == "disk" ]] || die "$TARGET_DISK is not a whole disk."

  if lsblk -nrpo NAME,MOUNTPOINT "$TARGET_DISK" | awk '$2 != "" {found=1} END{exit !found}'; then
    die "A filesystem on $TARGET_DISK is mounted. Unmount it or reboot the Arch ISO and retry."
  fi

  if swapon --show=NAME --noheadings 2>/dev/null | grep -q "^${TARGET_DISK}"; then
    die "A swap partition on $TARGET_DISK is active. Disable it before continuing."
  fi

  printf "\nSelected target:\n"
  lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN "$TARGET_DISK"
}

prompt_settings(){
  local input pass1 pass2

  read -r -p "Hostname [rick-linux]: " input
  HOSTNAME_VALUE="${input:-rick-linux}"
  [[ "$HOSTNAME_VALUE" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,62}$ ]] || die "Invalid hostname: $HOSTNAME_VALUE"

  read -r -p "Username [rick]: " input
  USERNAME_VALUE="${input:-rick}"
  [[ "$USERNAME_VALUE" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Invalid Linux username: $USERNAME_VALUE"

  read -r -p "Timezone [America/Chicago]: " input
  TIMEZONE_VALUE="${input:-America/Chicago}"
  [[ -e "/usr/share/zoneinfo/$TIMEZONE_VALUE" ]] || die "Unknown timezone: $TIMEZONE_VALUE"

  while true; do
    read -r -s -p "Password for $USERNAME_VALUE: " pass1; printf '\n'
    read -r -s -p "Retype password: " pass2; printf '\n'
    [[ -n "$pass1" ]] || { warn "Password cannot be empty."; continue; }
    [[ "$pass1" == "$pass2" ]] || { warn "Passwords did not match. Try again."; continue; }
    [[ "$pass1" != *:* ]] || { warn "Password cannot contain a colon (:)."; continue; }
    USER_PASSWORD="$pass1"
    break
  done
}

detect_microcode(){
  case "$(lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')" in
    GenuineIntel) MICROCODE_PKG="intel-ucode"; MICROCODE_IMG="intel-ucode.img" ;;
    AuthenticAMD) MICROCODE_PKG="amd-ucode"; MICROCODE_IMG="amd-ucode.img" ;;
    *) MICROCODE_PKG=""; MICROCODE_IMG="" ;;
  esac
  if [[ -n "$MICROCODE_PKG" ]]; then
    info "CPU microcode package: $MICROCODE_PKG"
  else
    warn "CPU vendor was not Intel/AMD; no microcode package will be added."
  fi
}

confirm_erase(){
  local confirmation expected
  expected="ERASE $TARGET_DISK"

  printf "\n%bDESTRUCTIVE INSTALLATION PLAN%b\n" "$yellow" "$reset"
  printf "  Target:   %s\n" "$TARGET_DISK"
  lsblk -dno SIZE,MODEL,SERIAL "$TARGET_DISK" | sed 's/^/  Disk:     /'
  printf "  Layout:   GPT, 1 GiB EFI/FAT32, remaining space ext4 root\n"
  printf "  Hostname: %s\n" "$HOSTNAME_VALUE"
  printf "  User:     %s\n" "$USERNAME_VALUE"
  printf "  Timezone: %s\n" "$TIMEZONE_VALUE"
  printf "  Swap:     none in v%s\n\n" "$VERSION"

  warn "EVERYTHING currently on $TARGET_DISK will be permanently erased."
  warn "Other disks are not intentionally modified."
  printf "\nType exactly: %s\n" "$expected"
  read -r -p "> " confirmation
  [[ "$confirmation" == "$expected" ]] || die "Confirmation did not match. Nothing was erased."
}

partition_path(){
  local disk="$1" number="$2"
  if [[ "$disk" =~ [0-9]$ ]]; then
    printf '%sp%s' "$disk" "$number"
  else
    printf '%s%s' "$disk" "$number"
  fi
}

partition_and_format(){
  EFI_PART="$(partition_path "$TARGET_DISK" 1)"
  ROOT_PART="$(partition_path "$TARGET_DISK" 2)"

  info "Erasing existing partition signatures on $TARGET_DISK..."
  wipefs -a -f "$TARGET_DISK"
  sgdisk --zap-all "$TARGET_DISK"

  info "Creating GPT partition table..."
  sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System" "$TARGET_DISK"
  sgdisk -n 2:0:0   -t 2:8300 -c 2:"Arch Linux root" "$TARGET_DISK"
  partprobe "$TARGET_DISK"
  udevadm settle

  [[ -b "$EFI_PART" ]] || die "EFI partition did not appear: $EFI_PART"
  [[ -b "$ROOT_PART" ]] || die "Root partition did not appear: $ROOT_PART"

  info "Formatting EFI partition as FAT32..."
  mkfs.fat -F 32 -n EFI "$EFI_PART"

  info "Formatting root partition as ext4..."
  mkfs.ext4 -F -L root "$ROOT_PART"

  ok "Partitioning and formatting completed."
}

mount_target(){
  mount "$ROOT_PART" "$MOUNTPOINT"
  mkdir -p "$MOUNTPOINT/boot"
  mount "$EFI_PART" "$MOUNTPOINT/boot"
  ok "Target filesystems mounted."
}

install_base(){
  local packages=(base linux linux-firmware networkmanager sudo nano git curl efibootmgr)
  [[ -n "$MICROCODE_PKG" ]] && packages+=("$MICROCODE_PKG")

  info "Installing the Arch base system. This can take several minutes..."
  pacstrap -K "$MOUNTPOINT" "${packages[@]}"

  info "Generating fstab..."
  genfstab -U "$MOUNTPOINT" > "$MOUNTPOINT/etc/fstab"
  ok "Base system installed."
}

configure_system(){
  info "Configuring timezone and hardware clock..."
  ln -sf "/usr/share/zoneinfo/$TIMEZONE_VALUE" "$MOUNTPOINT/etc/localtime"
  arch-chroot "$MOUNTPOINT" hwclock --systohc

  info "Configuring locale..."
  sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' "$MOUNTPOINT/etc/locale.gen"
  arch-chroot "$MOUNTPOINT" locale-gen
  printf 'LANG=en_US.UTF-8\n' > "$MOUNTPOINT/etc/locale.conf"

  info "Configuring hostname..."
  printf '%s\n' "$HOSTNAME_VALUE" > "$MOUNTPOINT/etc/hostname"
  cat > "$MOUNTPOINT/etc/hosts" <<EOF_HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME_VALUE.localdomain $HOSTNAME_VALUE
EOF_HOSTS

  info "Creating user $USERNAME_VALUE..."
  arch-chroot "$MOUNTPOINT" useradd -m -G wheel -s /bin/bash "$USERNAME_VALUE"
  printf '%s:%s\n' "$USERNAME_VALUE" "$USER_PASSWORD" | arch-chroot "$MOUNTPOINT" chpasswd
  unset USER_PASSWORD

  install -d -m 0750 "$MOUNTPOINT/etc/sudoers.d"
  printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$MOUNTPOINT/etc/sudoers.d/10-wheel"
  chmod 0440 "$MOUNTPOINT/etc/sudoers.d/10-wheel"
  arch-chroot "$MOUNTPOINT" visudo -cf /etc/sudoers >/dev/null
  arch-chroot "$MOUNTPOINT" passwd -l root >/dev/null

  info "Enabling NetworkManager..."
  arch-chroot "$MOUNTPOINT" systemctl enable NetworkManager.service

  ok "Base system configuration completed."
}

install_bootloader(){
  local root_uuid
  root_uuid="$(blkid -s UUID -o value "$ROOT_PART")"
  [[ -n "$root_uuid" ]] || die "Could not read root filesystem UUID."

  info "Installing systemd-boot..."
  arch-chroot "$MOUNTPOINT" bootctl --path=/boot install

  mkdir -p "$MOUNTPOINT/boot/loader/entries"
  cat > "$MOUNTPOINT/boot/loader/loader.conf" <<'EOF_LOADER'
default arch.conf
timeout 3
console-mode auto
editor no
EOF_LOADER

  {
    printf 'title   Rick Linux (Arch base)\n'
    printf 'linux   /vmlinuz-linux\n'
    [[ -n "$MICROCODE_IMG" ]] && printf 'initrd  /%s\n' "$MICROCODE_IMG"
    printf 'initrd  /initramfs-linux.img\n'
    printf 'options root=UUID=%s rw\n' "$root_uuid"
  } > "$MOUNTPOINT/boot/loader/entries/arch.conf"

  {
    printf 'title   Rick Linux (fallback initramfs)\n'
    printf 'linux   /vmlinuz-linux\n'
    [[ -n "$MICROCODE_IMG" ]] && printf 'initrd  /%s\n' "$MICROCODE_IMG"
    printf 'initrd  /initramfs-linux-fallback.img\n'
    printf 'options root=UUID=%s rw\n' "$root_uuid"
  } > "$MOUNTPOINT/boot/loader/entries/arch-fallback.conf"

  arch-chroot "$MOUNTPOINT" bootctl --path=/boot list >/dev/null || warn "bootctl list reported a warning; boot files were still written to the EFI partition."
  ok "systemd-boot installed."
}

verify_install(){
  info "Verifying installed files..."
  [[ -f "$MOUNTPOINT/boot/vmlinuz-linux" ]] || die "Kernel is missing from /boot."
  [[ -f "$MOUNTPOINT/boot/initramfs-linux.img" ]] || die "Initramfs is missing from /boot."
  [[ -f "$MOUNTPOINT/boot/loader/entries/arch.conf" ]] || die "systemd-boot entry is missing."
  [[ -f "$MOUNTPOINT/etc/fstab" ]] || die "fstab is missing."
  [[ -f "$MOUNTPOINT/etc/hostname" ]] || die "hostname configuration is missing."
  ok "Installation verification passed."
}

finish(){
  sync
  umount -R "$MOUNTPOINT"
  ok "Filesystems cleanly unmounted."

  cat <<EOF_DONE

=================================================
Rick Linux base installation is complete.

Target: $TARGET_DISK
User:   $USERNAME_VALUE

Next:
  1. Type: reboot
  2. Remove the Arch USB while the machine restarts.
  3. Boot the installed drive.
  4. Log in at the console as $USERNAME_VALUE.

This v$VERSION release intentionally stops at a basic Arch console.
Hyprland will be added only after this base install boots successfully.
=================================================
EOF_DONE
}

main(){
  clear || true
  banner
  require_root
  require_archiso
  require_uefi
  require_tools
  require_internet
  check_clock
  ensure_mountpoint_clear
  list_and_select_disk
  prompt_settings
  detect_microcode
  confirm_erase
  partition_and_format
  mount_target
  install_base
  configure_system
  install_bootloader
  verify_install
  finish
}

main "$@"
