#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Live Video Wallpaper Engine (mpvpaper)
# ==============================================================================
#  Usage:
#    toggle_live_wallpaper.sh          # Toggle live video wallpaper on/off
#    toggle_live_wallpaper.sh <path>   # Set specific video file as live wallpaper
#    toggle_live_wallpaper.sh next     # Cycle to next video in theme backgrounds
#    toggle_live_wallpaper.sh stop     # Stop live wallpaper
# ==============================================================================

BG_DIR="$HOME/.config/omarchy/themes/virtual-paradise/backgrounds"
DEFAULT_VIDEO="$BG_DIR/miku-horizontal-live.mp4"

# Fallback if theme backgrounds dir doesn't exist
if [[ ! -f "$DEFAULT_VIDEO" ]]; then
  DEFAULT_VIDEO="$HOME/Downloads/Miku_horizontal_livewallpaper.mp4"
fi

PID=$(pgrep -x mpvpaper)

stop_live_wallpaper() {
  if [[ -n "$PID" ]]; then
    killall -9 mpvpaper >/dev/null 2>&1
    notify-send -u low "󰸌 Live Wallpaper" "Stopped video wallpaper (Static active)"
  fi
}

start_live_wallpaper() {
  local video="$1"
  if [[ ! -f "$video" ]]; then
    video="$DEFAULT_VIDEO"
  fi

  # Stop existing instance if running
  killall mpvpaper >/dev/null 2>&1
  sleep 0.15

  # Launch mpvpaper with hardware acceleration, auto-pause when hidden, and infinite loop
  mpvpaper -p -f -o "no-audio --loop-file=inf --hwdec=auto --framedrop=vo --video-sync=display-resample" '*' "$video"

  local filename=$(basename "$video")
  notify-send -u normal "󰸌 Live Wallpaper" "Playing: ${filename}\n(Auto-pauses when windows cover)"
}

case "$1" in
  stop)
    stop_live_wallpaper
    ;;
  start)
    start_live_wallpaper "$2"
    ;;
  next)
    # Cycle through all .mp4 in backgrounds
    VIDEOS=("$BG_DIR"/*.mp4)
    if [[ ${#VIDEOS[@]} -gt 0 ]]; then
      CURRENT_RUNNING=$(ps aux | grep mpvpaper | grep -o "$BG_DIR/[^'\" ]*.mp4" | head -n 1)
      NEXT_VIDEO="${VIDEOS[0]}"
      for i in "${!VIDEOS[@]}"; do
        if [[ "${VIDEOS[$i]}" == "$CURRENT_RUNNING" ]]; then
          NEXT_INDEX=$(( (i + 1) % ${#VIDEOS[@]} ))
          NEXT_VIDEO="${VIDEOS[$NEXT_INDEX]}"
          break
        fi
      done
      start_live_wallpaper "$NEXT_VIDEO"
    else
      start_live_wallpaper "$DEFAULT_VIDEO"
    fi
    ;;
  "")
    if [[ -n "$PID" ]]; then
      stop_live_wallpaper
    else
      start_live_wallpaper "$DEFAULT_VIDEO"
    fi
    ;;
  *)
    if [[ -f "$1" ]]; then
      start_live_wallpaper "$1"
    else
      echo "File not found: $1" >&2
      exit 1
    fi
    ;;
esac
