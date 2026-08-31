#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Live Video Wallpaper Engine with Slanted Curtain Reveal
# ==============================================================================
#  Usage:
#    toggle_live_wallpaper.sh          # Toggle live video wallpaper on/off
#    toggle_live_wallpaper.sh init     # Startup: start live video with curtain reveal
#    toggle_live_wallpaper.sh start    # Start live video wallpaper
#    toggle_live_wallpaper.sh stop     # Switch to static Miku wallpaper
#    toggle_live_wallpaper.sh next     # Cycle to next video in backgrounds
# ==============================================================================

BG_DIR="$HOME/.config/omarchy/themes/virtual-paradise/backgrounds"
LIVE_VIDEO="$BG_DIR/miku-horizontal-live.mp4"
STATIC_BG="$BG_DIR/miku-cyber-peace.png"

CURRENT_BG=$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null)

set_live() {
  local video="${1:-$LIVE_VIDEO}"
  if [[ -f "$video" ]]; then
    omarchy theme bg set "$video"
    local filename=$(basename "$video")
    notify-send -u normal "󰸌 Live Wallpaper" "Playing: ${filename}\n(Slanted curtain reveal active)"
  else
    set_static
  fi
}

set_static() {
  if [[ -f "$STATIC_BG" ]]; then
    omarchy theme bg set "$STATIC_BG"
    notify-send -u low "󰸌 Live Wallpaper" "Switched to Static Miku Wallpaper"
  fi
}

case "$1" in
  init|autostart)
    if [[ -f "$LIVE_VIDEO" ]]; then
      set_live "$LIVE_VIDEO"
    else
      set_static
    fi
    ;;
  stop)
    set_static
    ;;
  start)
    set_live "$2"
    ;;
  next)
    VIDEOS=("$BG_DIR"/*.mp4)
    if [[ ${#VIDEOS[@]} -gt 0 ]]; then
      NEXT_VIDEO="${VIDEOS[0]}"
      for i in "${!VIDEOS[@]}"; do
        if [[ "${VIDEOS[$i]}" == "$CURRENT_BG" ]]; then
          NEXT_INDEX=$(( (i + 1) % ${#VIDEOS[@]} ))
          NEXT_VIDEO="${VIDEOS[$NEXT_INDEX]}"
          break
        fi
      done
      set_live "$NEXT_VIDEO"
    else
      set_live "$LIVE_VIDEO"
    fi
    ;;
  "")
    if [[ "$CURRENT_BG" == *.mp4 || "$CURRENT_BG" == *.webm ]]; then
      set_static
    else
      set_live "$LIVE_VIDEO"
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
