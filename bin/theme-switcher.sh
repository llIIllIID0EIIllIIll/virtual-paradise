#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Theme Variant Switcher
# ==============================================================================
#  Usage:
#    theme-switcher.sh              # Interactive menu
#    theme-switcher.sh cyberpunk    # Switch to cyberpunk variant
#    theme-switcher.sh cozy         # Switch to cozy variant
#    theme-switcher.sh monochrome   # Switch to monochrome variant
#    theme-switcher.sh list         # List available variants
# ==============================================================================

set -euo pipefail

THEME_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes/virtual-paradise"
STATE_DIR="$HOME/.local/state/virtual-paradise"
CURRENT_VARIANT_FILE="$STATE_DIR/current_variant"

mkdir -p "$STATE_DIR"

# Define color variants
declare -A VARIANTS=(
  ["cyberpunk"]="00ffdd:ff00ff:00ff88:0f081d"  # Miku cyan, neon magenta, hacker green
  ["cozy"]="ffa69e:fff4e0:faf3dd:2d2d2d"       # Warm peach, cream, soft yellow
  ["monochrome"]="ffffff:cccccc:888888:000000"  # Pure white, grays, black
  ["neon"]="00ffff:ff00ff:ffff00:0a0a0a"       # Bright cyan, magenta, yellow
  ["sakura"]="ffb7d5:ff69b4:ffc0cb:1a1a2e"     # Pink variants
)

get_current_variant() {
  if [[ -f "$CURRENT_VARIANT_FILE" ]]; then
    cat "$CURRENT_VARIANT_FILE"
  else
    echo "cyberpunk"
  fi
}

list_variants() {
  echo "Available theme variants:"
  local current
  current=$(get_current_variant)
  for variant in "${!VARIANTS[@]}"; do
    if [[ "$variant" == "$current" ]]; then
      echo "  ✓ $variant (current)"
    else
      echo "  • $variant"
    fi
  done
}

apply_variant() {
  local variant="$1"
  
  if [[ -z "${VARIANTS[$variant]:-}" ]]; then
    echo "Unknown variant: $variant"
    echo "Available: ${!VARIANTS[*]}"
    exit 1
  fi
  
  echo "Applying variant: $variant"
  
  # Save current variant
  echo "$variant" > "$CURRENT_VARIANT_FILE"
  
  # Parse colors
  IFS=':' read -r accent secondary tertiary background <<< "${VARIANTS[$variant]}"
  
  # Update colors.toml
  local colors_file="$THEME_DIR/colors.toml"
  if [[ -f "$colors_file" ]]; then
    cp "$colors_file" "$colors_file.backup"
    
    # Update accent color
    sed -i "s/^accent = .*/accent = \"#$accent\"/" "$colors_file"
    sed -i "s/^active_border_color = .*/active_border_color = \"#$accent\"/" "$colors_file"
    
    # Update secondary colors
    sed -i "s/^color1 = .*/color1 = \"#$secondary\"/" "$colors_file"
    sed -i "s/^color2 = .*/color2 = \"#$tertiary\"/" "$colors_file"
    
    echo "✓ Updated colors.toml"
  fi
  
  # Update Hyprland border colors
  local hypr_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
  if [[ -f "$hypr_file" ]]; then
    sed -i "s/col.active_border = .*/col.active_border = rgb($accent)/" "$hypr_file"
    sed -i "s/col.inactive_border = .*/col.inactive_border = rgb($background)/" "$hypr_file"
    echo "✓ Updated hyprland.conf"
  fi
  
  # Reload Hyprland
  if command -v hyprctl &>/dev/null; then
    hyprctl reload &>/dev/null || true
    echo "✓ Reloaded Hyprland"
  fi
  
  # Restart omarchy shell if running
  if pgrep -f "omarchy-shell" &>/dev/null; then
    pkill -USR1 -f "omarchy-shell" 2>/dev/null || true
    echo "✓ Signaled omarchy-shell to reload"
  fi
  
  echo ""
  echo "✓ Theme variant '$variant' applied successfully!"
  echo ""
  echo "Colors:"
  echo "  Accent:     #$accent"
  echo "  Secondary:  #$secondary"
  echo "  Tertiary:   #$tertiary"
  echo "  Background: #$background"
}

interactive_menu() {
  local current
  current=$(get_current_variant)
  
  echo "Virtual☆Paradise Theme Switcher"
  echo "================================"
  echo "Current variant: $current"
  echo ""
  list_variants
  echo ""
  
  # Build menu options
  local options=()
  local variants=()
  
  for variant in $(echo "${!VARIANTS[@]}" | tr ' ' '\n' | sort); do
    if [[ "$variant" != "$current" ]]; then
      options+=("$variant")
      variants+=("$variant")
    fi
  done
  
  if [[ ${#options[@]} -eq 0 ]]; then
    echo "No other variants available."
    exit 0
  fi
  
  # Try to use fzf if available
  if command -v fzf &>/dev/null; then
    local selected
    selected=$(printf '%s\n' "${options[@]}" | fzf --prompt="Select variant: " --height=40% --reverse)
    if [[ -n "$selected" ]]; then
      apply_variant "$selected"
    fi
  else
    # Fallback to simple numbered menu
    echo "Select a variant:"
    local i=1
    for opt in "${options[@]}"; do
      echo "  $i) $opt"
      ((i++))
    done
    echo "  0) Cancel"
    echo ""
    
    read -p "Enter number: " choice
    
    if [[ "$choice" == "0" ]]; then
      exit 0
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#options[@]} ]]; then
      apply_variant "${variants[$((choice-1))]}"
    else
      echo "Invalid selection"
      exit 1
    fi
  fi
}

# Main logic
case "${1:-}" in
  "")
    interactive_menu
    ;;
  "list")
    list_variants
    ;;
  "cyberpunk"|"cozy"|"monochrome"|"neon"|"sakura")
    apply_variant "$1"
    ;;
  *)
    echo "Usage: $0 [variant|list]"
    echo ""
    echo "Variants: cyberpunk, cozy, monochrome, neon, sakura"
    echo ""
    echo "Examples:"
    echo "  $0              # Interactive menu"
    echo "  $0 list         # List available variants"
    echo "  $0 cyberpunk    # Switch to cyberpunk"
    exit 1
    ;;
esac
