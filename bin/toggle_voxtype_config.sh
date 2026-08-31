#!/bin/bash
# Toggle Voxtype / Voice Dictation Configuration Window (Dynamic Terminal & Floating Window)

if pgrep -f "Voxtype Config" >/dev/null 2>&1 || pgrep -f "voxtype.*configure" >/dev/null 2>&1; then
    pkill -9 -f "Voxtype Config" 2>/dev/null
    pkill -9 -f "voxtype.*configure" 2>/dev/null
else
    cmd="voxtype configure; omarchy-restart-shell"
    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        xdg-terminal-exec --title="Voxtype Config" --app-id=org.omarchy.terminal.float -e bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v ghostty >/dev/null 2>&1; then
        ghostty --title="Voxtype Config" --x11-instance-name=voxtype_float -e bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty --title "Voxtype Config" --class voxtype_float -e bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v kitty >/dev/null 2>&1; then
        kitty --title "Voxtype Config" --class voxtype_float bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v foot >/dev/null 2>&1; then
        foot --title="Voxtype Config" --app-id=voxtype_float bash -c "$cmd" >/dev/null 2>&1 &
    fi
fi
