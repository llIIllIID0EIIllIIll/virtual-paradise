#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Live Video Wallpaper Engine with Auto-Fallback
# ==============================================================================
#  Usage:
#    toggle_live_wallpaper.sh          # Toggle live video wallpaper on/off
#    toggle_live_wallpaper.sh init     # Autostart: run live video, fallback to static image
#    toggle_live_wallpaper.sh start    # Start live video wallpaper
#    toggle_live_wallpaper.sh stop     # Stop live wallpaper (show static Miku)
#    toggle_live_wallpaper.sh next     # Cycle to next video in backgrounds
# ==============================================================================

BG_DIR="$HOME/.config/omarchy/themes/virtual-paradise/backgrounds"
DEFAULT_VIDEO="$BG_DIR/miku-horizontal-live.mp4"
FALLBACK_STATIC="$BG_DIR/miku-cyber-peace.png"

# Secondary fallback paths if theme backgrounds dir is missing
if [[ ! -f "$DEFAULT_VIDEO" ]]; then
  DEFAULT_VIDEO="$HOME/Downloads/Miku_horizontal_livewallpaper.mp4"
fi
if [[ ! -f "$FALLBACK_STATIC" ]]; then
  FALLBACK_STATIC="$HOME/Downloads/miku-cyber-peace-1080p.png"
fi

ensure_static_fallback() {
  if [[ -f "$FALLBACK_STATIC" ]]; then
    local current_bg=$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null)
    if [[ "$current_bg" != "$FALLBACK_STATIC" ]]; then
      omarchy theme bg set "$FALLBACK_STATIC" >/dev/null 2>&1 || true
    fi
  fi
}

stop_live_wallpaper() {
  local pid=$(pgrep -x mpvpaper)
  if [[ -n "$pid" ]]; then
    killall -9 mpvpaper >/dev/null 2>&1
    ensure_static_fallback
    notify-send -u low "󰸌 Live Wallpaper" "Switched to Static Miku Wallpaper"
  else
    ensure_static_fallback
  fi
}

start_live_wallpaper() {
  local video="${1:-$DEFAULT_VIDEO}"
  local silent="$2"

  # Ensure static fallback is always primed underneath
  ensure_static_fallback

  # Check if mpvpaper binary is installed
  if ! command -v mpvpaper >/dev/null 2>&1; then
    if [[ "$silent" != "silent" ]]; then
      notify-send -u low "󰸌 Live Wallpaper" "mpvpaper not available — using static Miku wallpaper"
    fi
    return 1
  fi

  # Check if video file exists
  if [[ ! -f "$video" ]]; then
    if [[ "$silent" != "silent" ]]; then
      notify-send -u low "󰸌 Live Wallpaper" "Video not found — using static Miku wallpaper"
    fi
    return 1
  fi

  # Terminate any existing mpvpaper instance
  killall mpvpaper >/dev/null 2>&1
  sleep 0.15

  # Launch mpvpaper with hardware acceleration, auto-pause when windows cover, and infinite loop
  mpvpaper -p -f -o "no-audio --loop-file=inf --hwdec=auto --framedrop=vo --video-sync=display-resample" '*' "$video" >/dev/null 2>&1

  sleep 0.35

  # Verify if mpvpaper successfully started and is alive
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    if [[ "$silent" != "silent" ]]; then
      local filename=$(basename "$video")
      notify-send -u normal "󰸌 Live Wallpaper" "Playing: ${filename}\n(Auto-pauses when windows cover)"
    fi
    return 0
  else
    # Fallback to static Miku image
    ensure_static_fallback
    if [[ "$silent" != "silent" ]]; then
      notify-send -u low "󰸌 Live Wallpaper" "Playback failed — fallback to static Miku wallpaper"
    fi
    return 1
  fi
}

case "$1" in
  init|autostart)
    # Default startup: attempt live wallpaper, fallback seamlessly to static
    start_live_wallpaper "$DEFAULT_VIDEO" "silent" || ensure_static_fallback
    ;;
  stop)
    stop_live_wallpaper
    ;;
  start)
    start_live_wallpaper "$2"
    ;;
  next)
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
    if pgrep -x mpvpaper >/dev/null 2>&1; then
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
