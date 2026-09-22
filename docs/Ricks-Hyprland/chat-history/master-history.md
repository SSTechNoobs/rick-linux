# Ricks Hyprland Master History

## Main Goal

Build and maintain a custom Hyprland desktop called **Ricks Hyprland** on the Minisforum M2.

The system should be simple, polished, reliable, and easy to restore.

---

## Main Hardware

- Minisforum M2 mini PC
- Intel Core Ultra 7 processor
- 32 GB RAM
- NVMe SSD
- Intel integrated Arc graphics
- TV/monitor connected through HDMI or DisplayPort

---

## Current Linux Context

### Ricks Hyprland
Primary custom Linux installation.

### Omarchy
Secondary installation used for testing, development, recovery, and maintenance.

Previous Artix Linux work is no longer considered the main system.

---

## Hyprland Work

Ricks Hyprland uses Hyprland as the compositor/window manager.

Important goals include:

- reliable startup
- TV/monitor compatibility
- correct display detection
- custom keyboard shortcuts
- custom bars and widgets
- system notifications
- clean application launching

---

## Quickshell

Ricks Hyprland uses Quickshell for custom desktop UI elements.

Work completed or discussed includes:

- custom top bar
- system tray
- clock
- status indicators
- update notifications
- bar watchdog
- automatic recovery if the bar disappears

Known running components have included:

- `qs -c rick`
- `rick-bar-watchdog`

The watchdog was confirmed to restore or maintain the bar after the TV was turned off and back on.

---

## Update Checker

The system was configured to check for Arch Linux package updates.

Known tools:

- `notify-send`
- `yay`
- `mako`

`mako` was installed and tested successfully for desktop notifications.

Goal:

- check for updates approximately once per week
- notify when updates are available
- eventually provide a clickable update/install icon near the clock

---

## Notification System

Mako was installed with:

    sudo pacman -S --needed mako

The user service was enabled with:

    systemctl --user enable --now mako.service

Notifications were tested using:

    notify-send "Update Checker Test" "Notifications are working."

---

## Display / TV Behavior

The Minisforum is commonly connected to a TV.

Important behavior to preserve:

- bar remains available after TV power cycling
- Hyprland detects the display correctly
- DisplayPort and HDMI may both be used depending on setup

A watchdog was added to improve Quickshell reliability after display reconnects.

---

## Documentation System

On 2026-09-22 a permanent documentation folder was created:

    ~/Ricks-Hyprland

Current structure:

    backups/
    chat-history/
    configs/
    scripts/
    README.md
    hardware.md
    setup-history.md
    commands-that-worked.md
    problems-and-fixes.md

Purpose:

- preserve important commands
- document fixes
- back up configuration files
- store summaries of ChatGPT work
- make Ricks Hyprland easier to rebuild later

---

## Future Documentation Rules

When an important change is completed:

1. Add the working command to `commands-that-worked.md`
2. Add major system changes to `setup-history.md`
3. Add troubleshooting solutions to `problems-and-fixes.md`
4. Copy important configs into `configs/`
5. Copy custom scripts into `scripts/`
6. Add major ChatGPT work summaries into `chat-history/`

---

## Long-Term Goal

Ricks Hyprland should eventually be reproducible from documentation and backups without relying on old ChatGPT conversations.

