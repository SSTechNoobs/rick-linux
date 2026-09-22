# Commands That Worked

Commands confirmed useful while building and maintaining Ricks Hyprland.

## Hyprland

Show connected monitors:
    hyprctl monitors

Show Hyprland layers:
    hyprctl layers

## Quickshell

Check whether Quickshell is running:
    pgrep -a qs

Known Ricks bar process:
    qs -c rick

Check the Ricks bar watchdog:
    pgrep -af '^bash /home/rick/.local/bin/rick-bar-watchdog$'

Watchdog location:
    /home/rick/.local/bin/rick-bar-watchdog

## Notifications

Install Mako:
    sudo pacman -S --needed mako

Enable and start Mako:
    systemctl --user enable --now mako.service

Check Mako:
    systemctl --user status mako.service --no-pager

Test notifications:
    notify-send "Update Checker Test" "Notifications are working."

## Update Tools

Check installed update tools:
    command -v checkupdates || echo "checkupdates: missing"
    command -v notify-send || echo "notify-send: missing"
    command -v yay || echo "yay: missing"

## Documentation

Show documentation tree:
    tree ~/Ricks-Hyprland

Open documentation directory:
    cd ~/Ricks-Hyprland

Read master history:
    cat ~/Ricks-Hyprland/chat-history/master-history.md

## Rule

Only commands that have been confirmed working belong in this file.
Problems and their solutions belong in problems-and-fixes.md.
