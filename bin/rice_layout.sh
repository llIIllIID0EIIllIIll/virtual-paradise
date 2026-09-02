#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Auto-Detecting 5-Terminal Rice Layout Launcher
# ==============================================================================
#  Order:
#    1. fastfetch    (Left Master panel)
#    2. btop         (Top Right system monitor)
#    3. momoisay     (Cute animated Momoi mascot - no text bubble)
#    4. cava         (Audio visualizer)
#    5. unimatrix    (Tri-color Cyber Matrix)
# ==============================================================================

# 1. Auto-detect User Shell (zsh / bash / sh)
DETECT_SHELL() {
  if [[ -n "$SHELL" ]] && command -v "$SHELL" &>/dev/null; then
    echo "$SHELL"
  elif command -v zsh &>/dev/null; then
    which zsh
  elif command -v bash &>/dev/null; then
    which bash
  else
    echo "/bin/sh"
  fi
}

USER_SHELL="$(DETECT_SHELL)"

# 2. Auto-detect Terminal Emulator (Ghostty, Foot, Alacritty, Kitty, etc.)
DETECT_TERMINAL() {
  if [[ -n "$TERMINAL" ]] && [[ "$TERMINAL" != *"xdg-terminal-exec"* ]] && command -v "$TERMINAL" &>/dev/null; then
    echo "$TERMINAL"
    return
  fi
  for term in ghostty foot alacritty kitty wezterm xterm; do
    if command -v "$term" &>/dev/null; then
      echo "$term"
      return
    fi
  done
  echo "xdg-terminal-exec"
}

TERM_BIN="$(DETECT_TERMINAL)"

# 3. Universal Terminal Launcher Dispatcher
LAUNCH_TERM() {
  case "$TERM_BIN" in
    ghostty|foot|alacritty|kitty|xterm)
      "$TERM_BIN" -e "$@" &
      ;;
    wezterm)
      wezterm start -- "$@" &
      ;;
    *)
      if command -v xdg-terminal-exec &>/dev/null; then
        xdg-terminal-exec -- "$@" &
      else
        "$TERM_BIN" "$@" &
      fi
      ;;
  esac
}

# 4. Sequential Launch with Optimized Micro-Delay for Perfect Tiling Tree Layout
# 1. Fastfetch + Paradise Agent (Master Left Panel)
case "$TERM_BIN" in
  ghostty|foot|alacritty|kitty)
    "$TERM_BIN" --title="fastfetch-agent" -e "$USER_SHELL" -c "printf '\033]0;fastfetch-agent\007'; fastfetch; /home/doe/.local/bin/paradise-agent; exec $USER_SHELL" &
    ;;
  *)
    LAUNCH_TERM "$USER_SHELL" -c "printf '\033]0;fastfetch-agent\007'; fastfetch; /home/doe/.local/bin/paradise-agent; exec $USER_SHELL"
    ;;
esac
sleep 0.10

# 2. btop (Top Right)
LAUNCH_TERM btop
sleep 0.10

# 3. momoisay (Cute Mascot Animation only, no speech bubbles)
LAUNCH_TERM /usr/local/bin/momoisay -c cyan -f
sleep 0.10

# 4. cava (Audio Spectrum Visualizer)
LAUNCH_TERM cava
sleep 0.10

# 5. unimatrix (Tri-color Hacker Matrix)
LAUNCH_TERM "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧"

# 6. Auto-focus Fastfetch + Paradise Agent terminal
sleep 0.35
hyprctl dispatch "hl.dsp.focus({ window = 'title:fastfetch-agent' })" 2>/dev/null || true

