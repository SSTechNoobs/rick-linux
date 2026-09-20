#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="Rick Linux Installer"
VERSION="0.1.0"

red='\033[0;31m'; green='\033[0;32m'; yellow='\033[1;33m'; blue='\033[0;34m'; reset='\033[0m'

info(){ printf "%b[INFO]%b %s\n" "$blue" "$reset" "$*"; }
ok(){ printf "%b[ OK ]%b %s\n" "$green" "$reset" "$*"; }
warn(){ printf "%b[WARN]%b %s\n" "$yellow" "$reset" "$*"; }
die(){ printf "%b[FAIL]%b %s\n" "$red" "$reset" "$*" >&2; exit 1; }

trap 'printf "\n%bInstaller stopped at line %s.%b\n" "$red" "$LINENO" "$reset" >&2' ERR

banner(){
  cat <<'BANNER'
=================================================
              Rick Linux Installer
        Arch Linux + Hyprland foundation
=================================================
BANNER
  printf "Version: %s\n\n" "$VERSION"
}

require_root(){
  [[ $EUID -eq 0 ]] || die "Run this from the Arch ISO as root."
}

require_archiso(){
  [[ -r /etc/os-release ]] || die "/etc/os-release is missing."
  . /etc/os-release
  [[ "${ID:-}" == "arch" ]] || die "This starter installer expects the official Arch Linux ISO. Detected: ${PRETTY_NAME:-unknown}"
  command -v pacstrap >/dev/null 2>&1 || die "pacstrap is missing; this does not look like the standard Arch install environment."
  ok "Arch installation environment detected."
}

require_uefi(){
  [[ -d /sys/firmware/efi/efivars ]] || die "System is not booted in UEFI mode. Reboot the USB and choose its UEFI boot entry."
  ok "UEFI mode detected."
}

require_internet(){
  if ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    ok "Internet connection is working."
  else
    die "No internet connection. Connect Ethernet or Wi-Fi before continuing."
  fi
}

check_clock(){
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-ntp true >/dev/null 2>&1 || true
  fi
  ok "Clock synchronization requested."
}

list_disks(){
  printf "\nAvailable physical disks:\n\n"
  lsblk -d -e 7,11 -o NAME,PATH,SIZE,MODEL,TRAN,TYPE | awk 'NR==1 || $NF=="disk"'
  printf "\n"
}

select_disk(){
  local choice
  read -r -p "Enter the FULL target disk path (example /dev/nvme0n1): " choice
  [[ -b "$choice" ]] || die "$choice is not a block device."
  [[ "$(lsblk -dn -o TYPE "$choice" 2>/dev/null)" == "disk" ]] || die "$choice is not a whole disk."

  printf "\nSelected target:\n"
  lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN "$choice"
  printf "\n"
  warn "NO CHANGES WILL BE MADE in version $VERSION."
  warn "A later version will ERASE this disk only after an explicit typed confirmation."

  TARGET_DISK="$choice"
  export TARGET_DISK
}

main(){
  clear || true
  banner
  require_root
  require_archiso
  require_uefi
  require_internet
  check_clock
  list_disks
  select_disk

  ok "Preflight checks passed."
  info "Selected disk: $TARGET_DISK"
  printf "\nThis is the safe preflight release. It does not partition, format, mount, or install anything.\n"
  printf "Next milestone: add guarded partitioning + pacstrap installation.\n"
}

main "$@"
