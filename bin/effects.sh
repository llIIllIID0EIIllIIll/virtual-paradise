#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Enhanced Animations & Effects
# ==============================================================================
#  Rainbow borders, smooth animations, and visual effects.
#
#  Run as `effects.sh <effect>`; the functions are also safe to source.
#
#  NOTE: Hyprland 0.5x loads a Lua config, and `hyprctl keyword` refuses to
#  work with it ("keyword can't work with non-legacy parsers. Use eval.").
#  Every setting below therefore goes through `hyprctl eval` with the same
#  hl.config() shape the theme's own hypr/*.lua files use. The legacy
#  `hyprctl keyword` calls this file used to make were silent no-ops.
# ==============================================================================

# Rainbow animated border (cycles through theme colors)
# Usage: effects.sh rainbow
rainbow_border() {
  local colors=("rgba(ff0055ff)" "rgba(ff00ffff)" "rgba(00ffddff)" "rgba(00ff88ff)" "rgba(ffe066ff)" "rgba(ffb7d5ff)")
  local index=0

  while true; do
    local next_index=$(( (index + 1) % ${#colors[@]} ))
    set_active_border_gradient "${colors[$index]}" "${colors[$next_index]}" 45
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
    set_shadow_color "rgba(00ffdd${hex})"

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

  # `hyprctl dispatch workspace e+1` is the legacy syntax and is rejected by
  # the Lua dispatcher; the theme's own bindings use hl.dsp.focus().
  if [[ "$direction" == "next" ]]; then
    hyprctl dispatch 'hl.dsp.focus({ workspace = "e+1" })' >/dev/null 2>&1 || true
  else
    hyprctl dispatch 'hl.dsp.focus({ workspace = "e-1" })' >/dev/null 2>&1 || true
  fi
}

# Focus animation (pulse border on focus change)
focus_pulse() {
  local current_border
  current_border="$(hyprctl getoption general:col.active_border -j 2>/dev/null | jq -r '.gradient // empty')"

  # Flash to bright white then back
  hyprctl eval 'hl.config({ general = { col = { active_border = "rgba(ffffffff)" } } })' >/dev/null 2>&1 || true
  sleep 0.1

  if [[ -n $current_border ]]; then
    restore_active_border "$current_border"
  else
    hyprctl reload >/dev/null 2>&1 || true
  fi
}

# Blur toggle (enable/disable blur for performance)
toggle_blur() {
  local current
  current=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.bool // false')

  if [[ "$current" == "true" ]]; then
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } } })' >/dev/null 2>&1 || true
    echo "Blur disabled (performance mode)"
  else
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } } })' >/dev/null 2>&1 || true
    echo "Blur enabled (aesthetic mode)"
  fi
}

# Shake animation (error feedback)
shake_window() {
  local shake="$HOME/.local/bin/hypr_window_error_shake.sh"
  local restore="$HOME/.local/bin/hypr_window_error_restore.sh"

  if [[ -x $shake ]]; then
    # The theme ships the real effect: a neon red border on the active window
    # that fades back once the error is gone. The old implementation used
    # `hyprctl dispatch movewindowpixel`, which the Lua dispatcher rejects.
    "$shake" >/dev/null 2>&1 || true
    if [[ -x $restore ]]; then
      ( sleep 0.5; "$restore" >/dev/null 2>&1 || true ) &
    fi
    return 0
  fi

  echo "The window shake effect needs ~/.local/bin/hypr_window_error_shake.sh (run the installer again)." >&2
  return 1
}

# --- Hyprland helpers --------------------------------------------------------

# Set the global active border to a gradient of one or two colours.
# set_active_border_gradient <color> [color] [angle]
set_active_border_gradient() {
  local first="$1" second="${2:-$1}" angle="${3:-45}"
  hyprctl eval "hl.config({ general = { col = { active_border = { colors = { \"$first\", \"$second\" }, angle = $angle } } } })" \
    >/dev/null 2>&1 || true
}

# Set the drop shadow colour.
# set_shadow_color <rgba>
set_shadow_color() {
  local color="$1"
  hyprctl eval "hl.config({ decoration = { shadow = { color = \"$color\" } } })" >/dev/null 2>&1 || true
}

# Restore the border gradient that was active before an effect ran.
# restore_active_border <gradient string from hyprctl getoption>
#
# Hyprland reports a gradient stop as AARRGGBB ("ee00ffdd" is #00ffdd with an
# ee alpha), while its config syntax wants RRGGBBAA. The first byte therefore
# has to move to the end, or the restored border comes back with its red and
# blue channels swapped.
restore_active_border() {
  local gradient="$1"
  local angle=45 token css expr="" sep=""
  local -a tokens=()

  read -ra tokens <<<"$gradient"
  for token in "${tokens[@]}"; do
    if [[ $token == *deg ]]; then
      angle="${token%deg}"
    else
      if [[ ${#token} -eq 8 ]]; then
        css="${token:2}${token:0:2}"
      else
        css="$token"
      fi
      expr+="${sep}\"rgba($css)\""
      sep=", "
    fi
  done

  [[ -n $expr ]] || return 1
  hyprctl eval "hl.config({ general = { col = { active_border = { colors = { $expr }, angle = $angle } } } })" \
    >/dev/null 2>&1 || true
}

# Export functions for use in other scripts
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    "rainbow")
      echo "Starting rainbow border effect (Ctrl+C to stop)"
      # Restore the configured border when the effect is stopped, so the
      # desktop is not left with whatever colour the loop ended on.
      trap 'exit 0' INT TERM
      trap 'hyprctl reload >/dev/null 2>&1 || true' EXIT
      rainbow_border
      ;;
    "glow")
      echo "Starting glow effect (Ctrl+C to stop)"
      trap 'exit 0' INT TERM
      trap 'hyprctl reload >/dev/null 2>&1 || true' EXIT
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
    "workspace-next")
      workspace_slide next
      ;;
    "workspace-prev")
      workspace_slide prev
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
