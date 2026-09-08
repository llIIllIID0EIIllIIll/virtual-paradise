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
  # 1. User login shell from passwd database (reflects chsh immediately)
  local db_shell
  db_shell="$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7)"
  if [[ -n "$db_shell" ]] && [[ "$db_shell" =~ zsh$ ]] && command -v "$db_shell" &>/dev/null; then
    echo "$db_shell"
    return
  fi

  # 2. Prefer zsh if installed (Virtual☆Paradise standard)
  if command -v zsh &>/dev/null; then
    command -v zsh
    return
  fi

  # 3. Fallback to db_shell if valid
  if [[ -n "$db_shell" ]] && command -v "$db_shell" &>/dev/null; then
    echo "$db_shell"
    return
  fi

  # 4. Fallback to $SHELL
  if [[ -n "$SHELL" ]] && command -v "$SHELL" &>/dev/null; then
    echo "$SHELL"
    return
  fi

  # 5. Fallback to bash or sh
  if command -v bash &>/dev/null; then
    command -v bash
    return
  fi
  echo "/bin/sh"
}

USER_SHELL="$(DETECT_SHELL)"
export SHELL="$USER_SHELL"

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
    "$TERM_BIN" --title="fastfetch-agent" -e "$USER_SHELL" -i -c "trap '' INT; printf '\033]0;fastfetch-agent\007'; fastfetch; \"$HOME/.local/bin/paradise-agent\" || true; exec $USER_SHELL -l" &
    ;;
  *)
    LAUNCH_TERM "$USER_SHELL" -i -c "trap '' INT; printf '\033]0;fastfetch-agent\007'; fastfetch; \"$HOME/.local/bin/paradise-agent\" || true; exec $USER_SHELL -l"
    ;;
esac
sleep 0.10

# 2. btop (Top Right)
LAUNCH_TERM btop
sleep 0.10

# 3. momoisay (Cute Mascot Animation - dynamic theme color, no speech bubbles)
LAUNCH_TERM "$HOME/.local/bin/momoisay" -f
sleep 0.10

# 4. cava (Audio Spectrum Visualizer)
LAUNCH_TERM cava
sleep 0.10

# 5. unimatrix (Tri-color Hacker Matrix)
LAUNCH_TERM "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧"

# 6. Auto-focus Fastfetch + Paradise Agent terminal
sleep 0.35
hyprctl dispatch "hl.dsp.focus({ window = 'title:fastfetch-agent' })" 2>/dev/null || true

