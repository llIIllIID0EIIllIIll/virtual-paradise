#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise Rice Layout Launcher (5-Terminal High-Speed Edition)
# ==============================================================================
#  Order:
#    1. fastfetch    (Left Master panel)
#    2. btop         (Top Right system monitor)
#    3. momoisay     (Cute animated Momoi mascot)
#    4. cava         (Audio visualizer)
#    5. unimatrix    (Tri-color Cyber Matrix)
# ==============================================================================

# Explicitly detect native terminal emulator binary
if command -v ghostty &>/dev/null; then
  LAUNCH_TERM() {
    ghostty -e "$@" &
  }
elif command -v foot &>/dev/null; then
  LAUNCH_TERM() {
    foot -e "$@" &
  }
elif command -v alacritty &>/dev/null; then
  LAUNCH_TERM() {
    alacritty -e "$@" &
  }
elif command -v kitty &>/dev/null; then
  LAUNCH_TERM() {
    kitty -e "$@" &
  }
elif command -v xdg-terminal-exec &>/dev/null; then
  LAUNCH_TERM() {
    xdg-terminal-exec -- "$@" &
  }
fi

# 1. Fastfetch (Master Left Panel)
LAUNCH_TERM zsh -c "fastfetch; exec zsh"
sleep 0.12

# 2. btop (Top Right)
LAUNCH_TERM btop
sleep 0.12

# 3. momoisay (Cute Blue Archive Mascot)
LAUNCH_TERM /usr/local/bin/momoisay -f "★ Virtual☆Paradise ★"
sleep 0.12

# 4. cava (Audio Spectrum Visualizer)
LAUNCH_TERM cava
sleep 0.12

# 5. unimatrix (Tri-color Hacker Matrix)
LAUNCH_TERM /home/doe/.local/bin/virtual_matrix -a -f -s 50 -l k -u "☆★✦✧"

