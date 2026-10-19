#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Enhanced Animations & Effects
# ==============================================================================
#  Rainbow borders, smooth animations, and visual effects.
#
#  Run as `effects.sh <effect>`; the functions are also safe to source.
# ==============================================================================

# Rainbow animated border (cycles through theme colors)
# Usage: Add to hyprland.conf
# windowrulev2 = animation rainbow, class:^(.*)$

# NOTE: the bezier curves and the window animations that used to be pasted in
# here were hyprlang, not shell, so running this script printed a dozen
# "command not found" errors before doing anything. They live in
# hypr/looknfeel.lua now, which is the config Hyprland actually loads.

# Rainbow border script (call this periodically)
# This creates a cycling gradient effect
rainbow_border() {
  local colors=("rgb(ff0055)" "rgb(ff00ff)" "rgb(00ffdd)" "rgb(00ff88)" "rgb(ffe066)" "rgb(ffb7d5)")
  local index=0
  
  while true; do
    local next_index=$(( (index + 1) % ${#colors[@]} ))
    hyprctl keyword general:col.active_border "${colors[$index]} ${colors[$next_index]} 45deg" 2>/dev/null
    sleep 2
    index=$next_index
  done
}

# Glow effect for active window (subtle pulsing)
glow_effect() {
  local intensity=0
  local direction=1
  
  while true; do
    intensity=$((intensity + direction * 5))
    
    if [[ $intensity -ge 100 ]] || [[ $intensity -le 50 ]]; then
      direction=$((direction * -1))
    fi
    
    # Convert to hex (50-100 range = 0.2-0.4 opacity)
    local hex
    hex=$(printf "%02x" $((intensity * 255 / 100)))
    hyprctl keyword decoration:shadow_color "rgba(00ffdd${hex})" 2>/dev/null
    
    sleep 0.1
  done
}

# Particle effect (floating dots in background)
particle_effect() {
  # This would require a compositor plugin or external renderer
  # Placeholder for future implementation
  echo "Particle effect not yet implemented"
  echo "Consider using: hyprland-effects or picom with custom shaders"
}

# Workspace transition effects
workspace_slide() {
  local direction="${1:-next}"  # next or prev
  
  if [[ "$direction" == "next" ]]; then
    hyprctl dispatch workspace e+1
  else
    hyprctl dispatch workspace e-1
  fi
}

# Focus animation (pulse border on focus change)
focus_pulse() {
  local current_border
  current_border=$(hyprctl getoption general:col.active_border -j | jq -r '.str')
  
  # Flash to bright white then back
  hyprctl keyword general:col.active_border "rgb(ffffff)" 2>/dev/null
  sleep 0.1
  hyprctl keyword general:col.active_border "$current_border" 2>/dev/null
}

# Window spawn animation (scale up from center)
spawn_animation() {
  local window_class="$1"
  
  # Start small and transparent
  hyprctl dispatch exec "[float; size 100 100; center 1; opacity 0.5] $window_class"
  
  # Animate to full size
  sleep 0.05
  hyprctl dispatch resizewindowpixel exact 800 600
  hyprctl dispatch setopacity 1.0
}

# Blur toggle (enable/disable blur for performance)
toggle_blur() {
  local current
  current=$(hyprctl getoption decoration:blur:enabled -j | jq -r '.int')
  
  if [[ "$current" == "1" ]]; then
    hyprctl keyword decoration:blur:enabled false
    echo "Blur disabled (performance mode)"
  else
    hyprctl keyword decoration:blur:enabled true
    echo "Blur enabled (aesthetic mode)"
  fi
}

# Shake animation (error feedback)
shake_window() {
  local window_id="${1:-$(hyprctl activewindow -j | jq -r '.address')}"
  
  for i in {1..6}; do
    local offset=$(( (i % 2) * 10 - 5 ))
    hyprctl dispatch movewindowpixel "$offset 0, address:$window_id"
    sleep 0.05
  done
}

# Export functions for use in other scripts
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    "rainbow")
      echo "Starting rainbow border effect (Ctrl+C to stop)"
      rainbow_border
      ;;
    "glow")
      echo "Starting glow effect (Ctrl+C to stop)"
      glow_effect
      ;;
    "toggle-blur")
      toggle_blur
      ;;
    "shake")
      shake_window "$2"
      ;;
    "focus-pulse")
      focus_pulse
      ;;
    *)
      echo "Virtual☆Paradise Effects"
      echo "========================"
      echo ""
      echo "Usage: $0 <effect>"
      echo ""
      echo "Effects:"
      echo "  rainbow      - Animated rainbow borders (continuous)"
      echo "  glow         - Pulsing glow effect (continuous)"
      echo "  toggle-blur  - Toggle blur on/off"
      echo "  shake [id]   - Shake window (error feedback)"
      echo "  focus-pulse  - Flash border on focus"
      echo ""
      ;;
  esac
fi
