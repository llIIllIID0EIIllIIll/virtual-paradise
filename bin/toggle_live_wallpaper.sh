#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Live Video Wallpaper Engine
# ==============================================================================
#  Usage:
#    toggle_live_wallpaper.sh          # Toggle live video wallpaper on/off
#    toggle_live_wallpaper.sh init     # Startup: start live video
#    toggle_live_wallpaper.sh start    # Start live video wallpaper
#    toggle_live_wallpaper.sh stop     # Switch to static Miku wallpaper
#    toggle_live_wallpaper.sh next     # Cycle to next video in backgrounds
# ==============================================================================

BG_DIR="$HOME/.config/omarchy/themes/virtual-paradise/backgrounds"
LIVE_VIDEO="$BG_DIR/miku-horizontal-live.mp4"
STATIC_BG="$BG_DIR/miku-cyber-peace.png"

is_live_running() {
  pgrep -x mpvpaper >/dev/null 2>&1
}

set_live() {
  local video="${1:-$LIVE_VIDEO}"
  if [[ -f "$video" ]]; then
    # Set static wallpaper as rock-solid background fallback
    if [[ -f "$STATIC_BG" ]]; then
      omarchy theme bg set "$STATIC_BG" 2>/dev/null || true
    fi
    # Launch mpvpaper hardware accelerated on all monitors
    killall -9 mpvpaper 2>/dev/null || true
    if command -v mpvpaper &>/dev/null; then
      mpvpaper -vs -o "no-audio loop" '*' "$video" >/dev/null 2>&1 &
    fi
    local filename=$(basename "$video")
    notify-send -u normal "󰸌 Live Wallpaper" "Playing: ${filename}\n(Hardware-accelerated 60fps)"
  else
    set_static
  fi
}

set_static() {
  killall -9 mpvpaper 2>/dev/null || true
  if [[ -f "$STATIC_BG" ]]; then
    omarchy theme bg set "$STATIC_BG" 2>/dev/null || true
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
      set_live "${VIDEOS[0]}"
    else
      set_live "$LIVE_VIDEO"
    fi
    ;;
  "")
    if is_live_running; then
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
