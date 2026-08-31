#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise Rice Layout Launcher
# ==============================================================================
# Launches terminals in sequence for a pristine tiling layout:
# 1. Fastfetch (Main left panel)
# 2. btop (Top-right system monitor)
# 3. cava (Bottom-right audio visualizer)
# 4. virtual_matrix (Bottom-right matrix animation)

TERM_BIN="${TERMINAL:-ghostty}"
if ! command -v "$TERM_BIN" &>/dev/null; then
  if command -v ghostty &>/dev/null; then
    TERM_BIN="ghostty"
  elif command -v foot &>/dev/null; then
    TERM_BIN="foot"
  elif command -v alacritty &>/dev/null; then
    TERM_BIN="alacritty"
  elif command -v kitty &>/dev/null; then
    TERM_BIN="kitty"
  fi
fi

# 1. Fastfetch (Main Left Panel - plays smooth neon gradient intro shimmer before settling)
"$TERM_BIN" -e zsh -c 'sleep 0.35; ~/.local/bin/virtual_fetch --intro 1.5; exec zsh' &
sleep 0.15

# 2. btop (Splits to right half)
"$TERM_BIN" -e btop &
sleep 0.15

# 3. cava (Splits bottom-right)
"$TERM_BIN" -e cava &
sleep 0.15

# 4. virtual_matrix (Splits next to cava with 3-color gradient)
"$TERM_BIN" -e ~/.local/bin/virtual_matrix -a -f -s 50 -l k -u '☆★✦✧' &
