#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Live Video & Animated GIF Wallpaper Engine
# ==============================================================================
#  Usage:
#    toggle_live_wallpaper.sh          # Toggle live wallpaper on/off
#    toggle_live_wallpaper.sh init     # Startup: start live wallpaper
#    toggle_live_wallpaper.sh start    # Start live wallpaper
#    toggle_live_wallpaper.sh stop     # Switch to static wallpaper
#    toggle_live_wallpaper.sh next     # Cycle to next live wallpaper (video/GIF)
#    toggle_live_wallpaper.sh prev     # Cycle to previous live wallpaper
#    toggle_live_wallpaper.sh list     # List all live wallpapers
# ==============================================================================

BG_DIR="$HOME/.config/omarchy/themes/virtual-paradise/backgrounds"
STATE_DIR="$HOME/.local/state/virtual-paradise"
STATE_FILE="$STATE_DIR/current_live_wallpaper"
STATIC_BG="$BG_DIR/Big_city.jpg"

mkdir -p "$STATE_DIR"

get_live_items() {
  local items=()
  for ext in mp4 gif webm mkv; do
    for f in "$BG_DIR"/*."$ext"; do
      if [[ -f "$f" ]]; then
        local bname=$(basename "$f")
        [[ "$bname" =~ ^(Sleeping_miku|lock).* ]] && continue
        items+=("$f")
      fi
    done
  done
  echo "${items[@]}"
}

is_live_running() {
  pgrep -x mpvpaper >/dev/null 2>&1
}

play_curtain_transition() {
  local qml_script="$HOME/.local/bin/curtain_transition.qml"
  if [[ -f "$qml_script" ]] && command -v quickshell &>/dev/null; then
    quickshell -p "$qml_script" >/dev/null 2>&1 &
  fi
}

set_live() {
  local target="$1"
  local transition="${2:-true}"
  if [[ -z "$target" ]] || [[ ! -f "$target" ]]; then
    local -a items=($(get_live_items))
    if [[ ${#items[@]} -gt 0 ]]; then
      target="${items[0]}"
    fi
  fi

  if [[ -n "$target" && -f "$target" ]]; then
    if [[ "$transition" == "true" ]]; then
      play_curtain_transition
      sleep 0.22
    fi

    # Set static wallpaper as rock-solid background fallback
    if [[ -f "$STATIC_BG" ]]; then
      omarchy theme bg set "$STATIC_BG" 2>/dev/null || true
    fi
    # Launch mpvpaper hardware accelerated on all monitors
    killall -9 mpvpaper 2>/dev/null || true
    if command -v mpvpaper &>/dev/null; then
      mpvpaper -vs -o "no-audio loop" '*' "$target" >/dev/null 2>&1 &
    fi
    echo "$target" > "$STATE_FILE"
  else
    set_static
  fi
}

set_static() {
  killall -9 mpvpaper 2>/dev/null || true
  if [[ -f "$STATIC_BG" ]]; then
    omarchy theme bg set "$STATIC_BG" 2>/dev/null || true
  fi
}

cycle_live() {
  local direction="${1:-next}"
  local -a items=($(get_live_items))
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
    if [[ -f "$STATE_FILE" ]] && [[ -f "$(cat "$STATE_FILE" 2>/dev/null)" ]]; then
      set_live "$(cat "$STATE_FILE")"
    else
      set_live
    fi
    ;;
  stop)
    set_static
    ;;
  start)
    set_live "$2"
    ;;
  next)
    cycle_live next
    ;;
  prev)
    cycle_live prev
    ;;
  list)
    echo "Available Live Wallpapers in Virtual☆Paradise:"
    items=($(get_live_items))
    for f in "${items[@]}"; do
      echo "  • $(basename "$f")"
    done
    ;;
  "")
    if is_live_running; then
      set_static
    else
      if [[ -f "$STATE_FILE" ]] && [[ -f "$(cat "$STATE_FILE" 2>/dev/null)" ]]; then
        set_live "$(cat "$STATE_FILE")"
      else
        set_live
      fi
    fi
    ;;
  *)
    if [[ -f "$1" ]]; then
      set_live "$1"
    else
      echo "File not found: $1" >&2
      exit 1
    fi
    ;;
esac
