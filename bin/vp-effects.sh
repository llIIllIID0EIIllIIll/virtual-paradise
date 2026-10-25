#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise - Visual Effects Control Panel
# ==============================================================================
#  Usage:
#    vp-effects.sh start          # Start all effects
#    vp-effects.sh stop           # Stop all effects
#    vp-effects.sh status         # Show running effects
#    vp-effects.sh enable <name>  # Enable specific effect
#    vp-effects.sh disable <name> # Disable specific effect
# ==============================================================================

set -euo pipefail

EFFECTS_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state/virtual-paradise"
STATE_FILE="$STATE_DIR/effects.state"

mkdir -p "$STATE_DIR"

# Available effects: name -> QML file installed in ~/.local/bin by install.sh
declare -A EFFECTS=(
  ["ambient_glitch"]="ambient_glitch.qml"
  ["scanline_overlay"]="scanline_overlay.qml"
)

start_effect() {
  local name="$1"
  local qml_file="${EFFECTS[$name]:-}"

  if [[ -z "$qml_file" ]]; then
    echo "Error: Unknown effect '$name'"
    return 1
  fi

  local full_path="$EFFECTS_DIR/$qml_file"

  if [[ ! -f "$full_path" ]]; then
    echo "Error: Effect file not found: $full_path"
    return 1
  fi

  # Check if already running
  if pgrep -f "quickshell.*$name" >/dev/null; then
    echo "Effect '$name' already running"
    return 0
  fi

  # Start effect in background
  quickshell -p "$full_path" &
  local pid
  pid=$!
  echo "$name:$pid" >> "$STATE_FILE"
  echo "✓ Started effect: $name (PID: $pid)"
}

stop_effect() {
  local name="$1"

  # Find PID from state file
  local pid
  pid=$(grep "^$name:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || true)

  if [[ -z "$pid" ]]; then
    echo "Effect '$name' not running"
    return 0
  fi

  # Kill process
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo "✓ Stopped effect: $name (PID: $pid)"
  fi

  # Remove from state file
  sed -i "/^$name:/d" "$STATE_FILE"
}

start_all() {
  echo "Starting all visual effects..."
  for name in "${!EFFECTS[@]}"; do
    start_effect "$name"
  done
}

stop_all() {
  echo "Stopping all visual effects..."
  for name in "${!EFFECTS[@]}"; do
    stop_effect "$name"
  done
}

show_status() {
  echo "Visual Effects Status:"
  echo "==================="
  for name in "${!EFFECTS[@]}"; do
    local pid
    pid=$(grep "^$name:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || true)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "  ✓ $name (running, PID: $pid)"
    else
      echo "  ✗ $name (stopped)"
    fi
  done
}

case "${1:-}" in
  start)
    start_all
    ;;
  stop)
    stop_all
    ;;
  status)
    show_status
    ;;
  enable)
    [[ -z "${2:-}" ]] && { echo "Usage: $0 enable <name>"; exit 1; }
    start_effect "$2"
    ;;
  disable)
    [[ -z "${2:-}" ]] && { echo "Usage: $0 disable <name>"; exit 1; }
    stop_effect "$2"
    ;;
  *)
    echo "Usage: $0 {start|stop|status|enable <name>|disable <name>}"
    echo
    echo "Available effects:"
    for name in "${!EFFECTS[@]}"; do
      echo "  - $name"
    done
    exit 1
    ;;
esac
