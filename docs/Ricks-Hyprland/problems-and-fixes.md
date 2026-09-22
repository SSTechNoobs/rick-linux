# Problems and Fixes

This file records problems encountered with Ricks Hyprland and the fixes that worked.

## Quickshell Bar and TV Power Cycling

### Problem

The Minisforum M2 is connected to a TV. Turning the TV off and back on can cause display-related programs such as the Quickshell bar to need recovery.

### Fix

A watchdog script was created:

    /home/rick/.local/bin/rick-bar-watchdog

Check that it is running:

    pgrep -af '^bash /home/rick/.local/bin/rick-bar-watchdog$'

Check the Quickshell bar:

    pgrep -a qs

Expected Quickshell process:

    qs -c rick

### Result

After turning the TV back on, the Ricks Hyprland bar was present and the watchdog was running.

---

## Desktop Notifications

### Problem

Ricks Hyprland needed a notification daemon so update alerts and other desktop notifications could appear.

### Fix

Install Mako:

    sudo pacman -S --needed mako

Enable it:

    systemctl --user enable --now mako.service

Test it:

    notify-send "Update Checker Test" "Notifications are working."

### Result

Mako installed successfully and notifications worked.

---

## Update Checker Tools

### Initial Check

The following command was used:

    command -v checkupdates || echo "checkupdates: missing"
    command -v notify-send || echo "notify-send: missing"
    command -v yay || echo "yay: missing"

At that time:

    checkupdates: missing
    /usr/bin/notify-send
    /usr/bin/yay

Further update-checker configuration should be documented here after it is completed.
