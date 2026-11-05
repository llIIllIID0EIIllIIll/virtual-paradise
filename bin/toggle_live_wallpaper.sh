#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Live video wallpaper switcher
# ==============================================================================
#  Usage:
#    toggle_live_wallpaper.sh          # Toggle live wallpaper on/off
#    toggle_live_wallpaper.sh start    # Start live wallpaper
#    toggle_live_wallpaper.sh stop     # Switch to static wallpaper
#    toggle_live_wallpaper.sh next     # Cycle to next live wallpaper (video/GIF)
#    toggle_live_wallpaper.sh prev     # Cycle to previous live wallpaper
#    toggle_live_wallpaper.sh list     # List all live wallpapers
#
#  Omarchy 4.5 ships its own background engine (`owe`) and renders video
#  wallpapers itself, so this script no longer runs mpvpaper: it picks the
#  file, plays the theme's glitch curtain, and hands the path to
#  `omarchy theme bg set`. That keeps the rice (the curtain, the cycle keys)
#  without a second video engine decoding the same frames - two engines ran
#  in parallel before, ~360 MB of RSS between them.
# ==============================================================================

# The wallpapers live outside the theme directory: Omarchy stages the whole
# theme into ~/.local/state/omarchy/current/theme on every theme switch, and
# ~95 MB of video in there cost ~15 seconds per switch. Omarchy scans
# ~/.config/omarchy/backgrounds/<theme>/ for wallpapers too, so that is where
# they are. The old location is still accepted for a theme that was installed
# before the move.
BG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/backgrounds/virtual-paradise"
if [[ ! -d "$BG_DIR" ]]; then
  BG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes/virtual-paradise/backgrounds"
fi
STATE_DIR="$HOME/.local/state/virtual-paradise"
STATE_FILE="$STATE_DIR/current_live_wallpaper"
STATIC_BG="$BG_DIR/Miku_missing.jpg"

# The ready flag lives in the per-user runtime directory. A fixed path in
# /tmp can be taken by another user on the machine: a ready flag that is
# already there ends the curtain before the wallpaper is up.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
READY_FILE="$RUNTIME_DIR/virtual_paradise_wallpaper_ready"

CURRENT_THEME="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo "")"
if [[ "$CURRENT_THEME" != "virtual-paradise" && "$1" != "--force" ]]; then
  exit 0
fi

mkdir -p "$STATE_DIR"

get_live_items() {
  local playlist=(
    "$BG_DIR/Miku_live.mp4"
    "$BG_DIR/Miku_missing.mp4"
    "$BG_DIR/Miku_animated_full.mp4"
    "$BG_DIR/Miku_animated1.mp4"
    "$BG_DIR/Miku_animated2.mp4"
    "$BG_DIR/Miku_animated3.mp4"
    "$BG_DIR/Miku_animated4.mp4"
  )
  local items=()
  for f in "${playlist[@]}"; do
    if [[ -f "$f" ]]; then
      items+=("$f")
    fi
  done
  # One path per line: every caller reads this with mapfile, which splits on
  # newlines. Echoing the array joined the paths into a single line, so the
  # cycle saw one item and only ever played the last of them. An empty array
  # printed one empty line, which the callers then counted as a wallpaper.
  if [[ ${#items[@]} -gt 0 ]]; then
    printf '%s\n' "${items[@]}"
  fi
}

# The name Omarchy uses for a background: the file name without extension.
background_name() {
  local base
  base="$(basename "${1:-}" 2>/dev/null)"
  printf '%s' "${base%.*}"
}

# What is on screen right now. The engine's own `current` drops the
# extension, and this theme's static and video share a stem
# (Miku_missing.jpg / .mp4), so read the symlink it manages instead.
current_background() {
  local link="$HOME/.local/state/omarchy/current/background"
  if [[ -L "$link" ]]; then
    readlink "$link" 2>/dev/null && return 0
  fi
  omarchy theme bg current 2>/dev/null | head -1
}

# Is the live video the current background? Drives the toggle.
is_live_current() {
  [[ -f "$STATE_FILE" ]] || return 1
  local want current
  want="$(cat "$STATE_FILE" 2>/dev/null)"
  current="$(current_background)"
  [[ -n "$want" && "$want" == "$current" ]]
}

play_curtain_transition() {
  local target="${1:-LIVE STREAM}"
  local qml_script="$HOME/.local/bin/glitch_transition.qml"
  [[ ! -f "$qml_script" ]] && qml_script="$HOME/.local/bin/curtain_transition.qml"
  if [[ -f "$qml_script" ]] && command -v quickshell &>/dev/null; then
    rm -f "$READY_FILE"
    export CURTAIN_LAYER="${CURTAIN_LAYER:-overlay}"
    export WALLPAPER_TARGET
    export VP_WALLPAPER_READY_FILE="$READY_FILE"
    WALLPAPER_TARGET="$(basename "$target" 2>/dev/null || echo "LIVE STREAM")"
    quickshell -p "$qml_script" >/dev/null 2>&1 &
    # Wait until glitch layer surface is physically rendered on screen by Hyprland
    for ((i=0; i<35; i++)); do
      if hyprctl layers 2>/dev/null | grep -q "curtain-transition"; then
        break
      fi
      sleep 0.015
    done
    # Allow the violent Phase 1 glitch to hit full swing before swapping wallpaper
    sleep 0.12
  fi
}

# Wait until the symlink points at the new media, then let the curtain go.
# The curtain has its own timeout, so a slow decode cannot hold the screen.
wait_for_background() {
  local want="$1"
  local max_checks=60 # 60 * 0.05s = 3.0s maximum
  for ((i=0; i<max_checks; i++)); do
    if [[ -z "$want" ]] || [[ "$(current_background)" == "$want" ]]; then
      break
    fi
    sleep 0.05
  done
  touch "$READY_FILE"
}

set_background() {
  local target="$1"
  local transition="${2:-true}"
  if [[ -n "$target" && -f "$target" ]]; then
    if [[ "$transition" == "true" ]]; then
      play_curtain_transition "$target"
    fi
    omarchy theme bg set "$target" 2>/dev/null || true
    if [[ "$transition" == "true" ]]; then
      wait_for_background "$target" &
    else
      touch "$READY_FILE"
    fi
    echo "$target" > "$STATE_FILE"
  else
    set_static "$transition"
  fi
}

set_live() {
  local target="$1"
  local transition="${2:-true}"
  if [[ -z "$target" ]] || [[ ! -f "$target" ]]; then
    local -a items
    mapfile -t items < <(get_live_items)
    if [[ ${#items[@]} -gt 0 ]]; then
      target="${items[0]}"
    fi
  fi
  set_background "$target" "$transition"
}

set_static() {
  local transition="${1:-true}"
  rm -f "$READY_FILE"
  if [[ "$transition" == "true" ]]; then
    play_curtain_transition
  fi
  if [[ -f "$STATIC_BG" ]]; then
    omarchy theme bg set "$STATIC_BG" 2>/dev/null || true
  fi
  touch "$READY_FILE"
}

cycle_live() {
  local direction="${1:-next}"
  local -a items
  mapfile -t items < <(get_live_items)
  local total=${#items[@]}
  if [[ $total -eq 0 ]]; then
    set_static
    return
  fi

  local current=""
  [[ -f "$STATE_FILE" ]] && current=$(cat "$STATE_FILE")
  local current_idx=-1

  for i in "${!items[@]}"; do
    if [[ "${items[$i]}" == "$current" ]]; then
      current_idx=$i
      break
    fi
  done

  local next_idx=0
  if [[ $current_idx -ge 0 ]]; then
    if [[ "$direction" == "prev" ]]; then
      next_idx=$(( (current_idx - 1 + total) % total ))
    else
      next_idx=$(( (current_idx + 1) % total ))
    fi
  fi

  set_live "${items[$next_idx]}"
}

case "$1" in
  init|autostart)
    # Omarchy restores the background itself at login, video included, so
    # there is nothing to start. Kept so an old autostart line stays harmless.
    exit 0
    ;;
  stop)
    set_static true
    ;;
  start)
    set_live "$2" true
    ;;
  next)
    cycle_live next
    ;;
  prev)
    cycle_live prev
    ;;
  list)
    echo "Available Live Wallpapers in Virtual☆Paradise:"
    mapfile -t items < <(get_live_items)
    for f in "${items[@]}"; do
      echo "  • $(basename "$f")"
    done
    ;;
  "")
    if is_live_current; then
      set_static true
    else
      if [[ -f "$STATE_FILE" ]] && [[ -f "$(cat "$STATE_FILE" 2>/dev/null)" ]]; then
        set_live "$(cat "$STATE_FILE")" true
      else
        set_live "" true
      fi
    fi
    ;;
  *)
    if [[ -f "$1" ]]; then
      set_live "$1" true
    else
      echo "File not found: $1" >&2
      exit 1
    fi
    ;;
esac
