#!/bin/bash
# Toggle Btop System Monitor (Dynamic Terminal Detection & Floating Window)

if pgrep -f "Btop Monitor" >/dev/null 2>&1 || pgrep -x btop >/dev/null 2>&1; then
    pkill -9 -f "Btop Monitor" 2>/dev/null
    pkill -9 -x btop 2>/dev/null
else
    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        xdg-terminal-exec --title="Btop Monitor" --app-id=org.omarchy.terminal.float -e btop >/dev/null 2>&1 &
    elif command -v ghostty >/dev/null 2>&1; then
        ghostty --title="Btop Monitor" --x11-instance-name=btop_float -e btop >/dev/null 2>&1 &
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty --title "Btop Monitor" --class btop_float -e btop >/dev/null 2>&1 &
    elif command -v kitty >/dev/null 2>&1; then
        kitty --title "Btop Monitor" --class btop_float btop >/dev/null 2>&1 &
    elif command -v foot >/dev/null 2>&1; then
        foot --title="Btop Monitor" --app-id=btop_float btop >/dev/null 2>&1 &
    fi
fi
