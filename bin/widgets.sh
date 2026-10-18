#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Floating Desktop Widgets
# ==============================================================================
#  Launch floating widgets on the desktop using eww or quickshell
# ==============================================================================

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/virtual-paradise/widgets"
STATE_DIR="$HOME/.local/state/virtual-paradise/widgets"

mkdir -p "$CONFIG_DIR" "$STATE_DIR"

# Check if widget is running
is_running() {
  local widget="$1"
  pgrep -f "eww.*$widget" &>/dev/null
}

# Toggle widget
toggle_widget() {
  local widget="$1"
  
  if is_running "$widget"; then
    eww close "$widget" 2>/dev/null || true
    echo "0" > "$STATE_DIR/$widget"
    echo "✗ Closed $widget"
  else
    eww open "$widget" 2>/dev/null || {
      echo "✗ Failed to open $widget (is eww running?)"
      return 1
    }
    echo "1" > "$STATE_DIR/$widget"
    echo "✓ Opened $widget"
  fi
}

# Clock widget
widget_clock() {
  local config="$CONFIG_DIR/clock.yuck"
  
  if [[ ! -f "$config" ]]; then
    cat > "$config" << 'EOF'
(defwindow clock
  :geometry (geometry :x "100px" :y "100px" :width "200px" :height "100px")
  :stacking "fg"
  :window-type "dock"
  :wm-ignore false
  (box :class "clock-widget"
    :orientation "v"
    :spacing 5
    (label :class "clock-time" :text "${time}")
    (label :class "clock-date" :text "${date}")))

(defvar time "")
(defvar date "")

(defpoll time :interval "1s" "date +'%H:%M:%S'")
(defpoll date :interval "60s" "date +'%A, %B %d'")
EOF
  fi
  
  toggle_widget "clock"
}

# System stats widget
widget_stats() {
  local config="$CONFIG_DIR/stats.yuck"
  
  if [[ ! -f "$config" ]]; then
    cat > "$config" << 'EOF'
(defwindow stats
  :geometry (geometry :x "50px" :y "50px" :width "150px" :height "200px")
  :stacking "fg"
  :window-type "dock"
  :wm-ignore false
  (box :class "stats-widget"
    :orientation "v"
    :spacing 8
    (label :class "stats-title" :text "System")
    (box :orientation "h" :spacing 5
      (label :text "CPU:")
      (label :text "${cpu}%"))
    (box :orientation "h" :spacing 5
      (label :text "RAM:")
      (label :text "${ram}%"))
    (box :orientation "h" :spacing 5
      (label :text "TEMP:")
      (label :text "${temp}°C"))))

(defvar cpu "0")
(defvar ram "0")
(defvar temp "0")

(defpoll cpu :interval "2s" "top -bn1 | grep 'Cpu(s)' | awk '{print int($2)}'")
(defpoll ram :interval "2s" "free | grep Mem | awk '{print int($3/$2 * 100)}'")
(defpoll temp :interval "5s" "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print int($1/1000)}' || echo 0")
EOF
  fi
  
  toggle_widget "stats"
}

# Weather widget
widget_weather() {
  local config="$CONFIG_DIR/weather.yuck"
  
  if [[ ! -f "$config" ]]; then
    cat > "$config" << 'EOF'
(defwindow weather
  :geometry (geometry :x "300px" :y "100px" :width "250px" :height "120px")
  :stacking "fg"
  :window-type "dock"
  :wm-ignore false
  (box :class "weather-widget"
    :orientation "v"
    :spacing 5
    (label :class "weather-title" :text "Weather")
    (label :class "weather-temp" :text "${temp}°C")
    (label :class "weather-desc" :text "${desc}")))

(defvar temp "0")
(defvar desc "Loading...")

(defpoll temp :interval "600s" "curl -s 'wttr.in/?format=%t' | grep -o '[0-9]*' || echo 0")
(defpoll desc :interval "600s" "curl -s 'wttr.in/?format=%C' || echo 'Unknown'")
EOF
  fi
  
  toggle_widget "weather"
}

# Main menu
show_menu() {
  echo "Virtual☆Paradise Floating Widgets"
  echo "=================================="
  echo ""
  echo "Available widgets:"
  echo "  1) Clock      - Large time/date display"
  echo "  2) Stats      - CPU, RAM, Temperature"
  echo "  3) Weather    - Current weather"
  echo ""
  echo "Commands:"
  echo "  widgets.sh clock   - Toggle clock widget"
  echo "  widgets.sh stats   - Toggle stats widget"
  echo "  widgets.sh weather - Toggle weather widget"
  echo "  widgets.sh all     - Toggle all widgets"
  echo "  widgets.sh stop    - Stop all widgets"
  echo ""
}

# Stop all widgets
stop_all() {
  for widget in clock stats weather; do
    if is_running "$widget"; then
      eww close "$widget" 2>/dev/null || true
      echo "0" > "$STATE_DIR/$widget"
    fi
  done
  echo "✓ All widgets stopped"
}

# Toggle all widgets
toggle_all() {
  widget_clock
  widget_stats
  widget_weather
}

# Main logic
case "${1:-}" in
  "")
    show_menu
    ;;
  "clock")
    widget_clock
    ;;
  "stats")
    widget_stats
    ;;
  "weather")
    widget_weather
    ;;
  "all")
    toggle_all
    ;;
  "stop")
    stop_all
    ;;
  *)
    echo "Unknown widget: $1"
    show_menu
    exit 1
    ;;
esac
