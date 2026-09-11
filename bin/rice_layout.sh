#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Auto-Detecting 5-Terminal Rice Layout Launcher
# ==============================================================================
#  Layout Tree (preview.png):
#    Left 50%:                  fastfetch-agent (Master Left panel)
#    Top Right:                 btop (System monitor)
#    Bottom-Right-Left:         momoisay (Cute animated Momoi mascot)
#    Bottom-Right-Right-Top:    cava (Audio visualizer)
#    Bottom-Right-Right-Bottom: unimatrix / virtual_matrix (Cyber matrix)
# ==============================================================================

# 1. Auto-detect User Shell (zsh / bash / sh)
DETECT_SHELL() {
  local db_shell
  db_shell="$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7)"
  if [[ -n "$db_shell" ]] && [[ "$db_shell" =~ zsh$ ]] && command -v "$db_shell" &>/dev/null; then
    echo "$db_shell"
    return
  fi

  if command -v zsh &>/dev/null; then
    command -v zsh
    return
  fi

  if [[ -n "$db_shell" ]] && command -v "$db_shell" &>/dev/null; then
    echo "$db_shell"
    return
  fi

  if [[ -n "$SHELL" ]] && command -v "$SHELL" &>/dev/null; then
    echo "$SHELL"
    return
  fi

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

# 3. Find First Empty Workspace
get_first_empty_ws() {
  local occupied
  occupied=($(hyprctl workspaces -j 2>/dev/null | jq -r '.[].id' 2>/dev/null | sort -n))
  for ((id=1; id<=20; id++)); do
    local found=0
    for occ in "${occupied[@]}"; do
      if [[ "$occ" -eq "$id" ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      echo "$id"
      return
    fi
  done
  echo "5"
}

# 4. Check if Rice is Already Running
rice_clients=$(hyprctl clients -j 2>/dev/null | jq '[.[] | select((.title | test("fastfetch-agent|rice-btop|rice-momoi|rice-cava|rice-matrix")) or (.initialTitle | test("fastfetch-agent|rice-btop|rice-momoi|rice-cava|rice-matrix")))]')
rice_count=$(echo "$rice_clients" | jq 'length' 2>/dev/null || echo 0)

if [[ "$rice_count" -ge 3 ]]; then
  active_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id')
  rice_ws=$(echo "$rice_clients" | jq -r '.[0].workspace.id')

  if [[ "$active_ws" == "$rice_ws" ]]; then
    # Toggle off when pressed on the rice workspace
    pkill -f "fastfetch-agent|rice-btop|rice-momoi|rice-cava|virtual_matrix" 2>/dev/null || true
    exit 0
  else
    # Jump to rice workspace and focus master terminal
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$rice_ws\" })" 2>/dev/null || true
    hyprctl dispatch "hl.dsp.focus({ window = \"title:fastfetch-agent\" })" 2>/dev/null || true
    exit 0
  fi
fi

# 5. Switch to a Clean Workspace if Current Workspace has Windows
active_windows=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.windows' 2>/dev/null || echo 0)
if [[ "$active_windows" -gt 0 ]]; then
  TARGET_WS=$(get_first_empty_ws)
  hyprctl dispatch "hl.dsp.focus({ workspace = \"$TARGET_WS\" })" 2>/dev/null || true
  sleep 0.05
else
  TARGET_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo 1)
fi

# 6. Terminal Launcher Dispatcher with Title Support (setsid detached)
LAUNCH_RICE_TERM() {
  local title="$1"
  shift
  case "$TERM_BIN" in
    ghostty)
      setsid -f ghostty --title="$title" -e "$@" >/dev/null 2>&1
      ;;
    foot)
      setsid -f foot --title="$title" "$@" >/dev/null 2>&1
      ;;
    alacritty)
      setsid -f alacritty --title "$title" -e "$@" >/dev/null 2>&1
      ;;
    kitty)
      setsid -f kitty --title="$title" "$@" >/dev/null 2>&1
      ;;
    wezterm)
      setsid -f wezterm start --title "$title" -- "$@" >/dev/null 2>&1
      ;;
    *)
      if command -v xdg-terminal-exec &>/dev/null; then
        setsid -f xdg-terminal-exec -- "$@" >/dev/null 2>&1
      else
        setsid -f "$TERM_BIN" "$@" >/dev/null 2>&1
      fi
      ;;
  esac
}

# 7. Ultra-Fast Deterministic Launcher with Mouse Immunity
# Why layouts break when mouse moves:
# Hyprland's dwindle tree splits each new window against the currently active window.
# If follow_mouse is enabled and the user moves the mouse while terminals are opening,
# the mouse hover steals focus away from the active pane, causing subsequent splits
# to land in the wrong branch of the tree.
#
# Solution:
# 1. Temporarily freeze mouse-focus hijacking: follow_mouse = 0
# 2. Sequential micro-burst spawn (pure shell, ZERO Python overhead)
# 3. Explicitly focus the intended target before each split
# 4. Instantly restore follow_mouse = 1 when layout completes

hyprctl eval 'hl.config({ input = { follow_mouse = 0 } })' >/dev/null 2>&1 || true

# Window 1: Fastfetch + Paradise Banner (Master Left Panel)
MASTER_CMD="trap '' INT; printf '\033]0;fastfetch-agent\007'; fastfetch; \"$HOME/.local/bin/paradise_banner.py\" || true; exec $USER_SHELL -l"
case "$TERM_BIN" in
  ghostty)
    setsid -f env VIRTUAL_PARADISE_NO_BANNER=1 ghostty --title="fastfetch-agent" -e "$USER_SHELL" -i -c "$MASTER_CMD" >/dev/null 2>&1
    ;;
  foot)
    setsid -f env VIRTUAL_PARADISE_NO_BANNER=1 foot --title="fastfetch-agent" "$USER_SHELL" -i -c "$MASTER_CMD" >/dev/null 2>&1
    ;;
  alacritty)
    setsid -f env VIRTUAL_PARADISE_NO_BANNER=1 alacritty --title "fastfetch-agent" -e "$USER_SHELL" -i -c "$MASTER_CMD" >/dev/null 2>&1
    ;;
  kitty)
    setsid -f env VIRTUAL_PARADISE_NO_BANNER=1 kitty --title="fastfetch-agent" "$USER_SHELL" -i -c "$MASTER_CMD" >/dev/null 2>&1
    ;;
  *)
    LAUNCH_RICE_TERM "fastfetch-agent" "$USER_SHELL" -i -c "$MASTER_CMD"
    ;;
esac
sleep 0.07

# Window 2: btop (Splits Window 1 horizontally -> Top Right)
LAUNCH_RICE_TERM "rice-btop" btop
sleep 0.07

# Window 3: momoisay (Splits Window 2 vertically -> Bottom Right Left)
LAUNCH_RICE_TERM "rice-momoi" "$HOME/.local/bin/momoisay" -f
sleep 0.07

# Window 4: cava (Splits Window 3 horizontally -> Bottom Right Right Top)
LAUNCH_RICE_TERM "rice-cava" cava
sleep 0.07

# Window 5: unimatrix / virtual_matrix (Splits Window 4 vertically -> Bottom Right Right Bottom)
LAUNCH_RICE_TERM "rice-matrix" "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧"

# Restore mouse focus behavior immediately
hyprctl eval 'hl.config({ input = { follow_mouse = 1 } })' >/dev/null 2>&1 || true

# 8. Return Focus to Master Terminal
sleep 0.1
hyprctl eval 'hl.dsp.focus({ window = "title:fastfetch-agent" })' >/dev/null 2>&1 || true
