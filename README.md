# Rick Linux

An Arch Linux installer project intended to produce a reproducible Hyprland-based desktop from the official Arch ISO.

## Current status

**v0.1.0 is intentionally non-destructive.** It performs preflight checks and lets you select a target disk, but it does not partition, format, mount, or install anything.

## Run from the official Arch ISO

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/rick-linux/main/install.sh -o install.sh
bash install.sh
```

During development, downloading first and then running the file is preferable to piping a remote script directly into a shell.

## v0.1.0 checks

- Running as root
- Official Arch environment with `pacstrap`
- UEFI boot mode
- Internet connectivity
- Clock synchronization request
- Physical disk listing
- Validation that the selected target is a whole block disk

## Planned stages

1. Guarded GPT partitioning
2. EFI System Partition + root partition (+ optional swap)
3. `pacstrap -K` base installation
4. `genfstab -U`
5. Locale, timezone, hostname, users
6. systemd-boot
7. NetworkManager + PipeWire
8. Hyprland desktop packages
9. Rick Linux configuration
10. Optional applications and AUR setup

## Safety model

Destructive disk operations will require the user to identify a whole disk and type an exact confirmation string containing the selected device path. The installer should never guess a target disk.
