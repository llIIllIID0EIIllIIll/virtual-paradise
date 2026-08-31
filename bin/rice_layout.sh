#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise Rice Layout Launcher (5-Terminal High-Speed Edition)
# ==============================================================================
#  Order:
#    1. fastfetch    (Left Master panel)
#    2. btop         (Top Right system monitor)
#    3. momoisay     (Cute animated Momoi ASCII)
#    4. cava         (Audio visualizer)
#    5. unimatrix    (Tri-color Cyber Matrix)
# ==============================================================================

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

# High-speed parallel dispatch via Hyprland socket with micro-intervals for perfect tiling tree order
spawn_term() {
  local cmd="$1"
  if command -v hyprctl &>/dev/null && [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    hyprctl dispatch exec "$TERM_BIN -e $cmd" >/dev/null 2>&1
  else
    "$TERM_BIN" -e bash -c "$cmd" &
  fi
  sleep 0.04
}

# 1. Fastfetch (Master Left)
spawn_term "zsh -c 'fastfetch; exec zsh'"

# 2. Btop (System Monitor)
spawn_term "btop"

# 3. Momoisay (Blue Archive Cute Animated Mascot)
spawn_term "momoisay -f '★ Virtual☆Paradise ★'"

# 4. Cava (Audio Spectrum)
spawn_term "cava"

# 5. Virtual Matrix (Tri-color Hacker Matrix)
spawn_term "$HOME/.local/bin/virtual_matrix -a -f -s 50 -l k -u '☆★✦✧'"

