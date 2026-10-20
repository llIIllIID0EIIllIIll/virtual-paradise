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
#    theme-switcher.sh reset        # Restore the original palette
# ==============================================================================

set -euo pipefail

THEME_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes/virtual-paradise"
STATE_DIR="$HOME/.local/state/virtual-paradise"
CURRENT_VARIANT_FILE="$STATE_DIR/current_variant"
ORIGINAL_DIR="$STATE_DIR/theme-variant-orig"

mkdir -p "$STATE_DIR"

# Define color variants
declare -A VARIANTS=(
  ["cyberpunk"]="00ffdd:ff00ff:00ff88:0f081d"  # Miku cyan, neon magenta, hacker green
  ["cozy"]="ffa69e:fff4e0:faf3dd:2d2d2d"       # Warm peach, cream, soft yellow
  ["monochrome"]="ffffff:cccccc:888888:000000"  # Pure white, grays, black
  ["neon"]="00ffff:ff00ff:ffff00:0a0a0a"       # Bright cyan, magenta, yellow
  ["sakura"]="ffb7d5:ff69b4:ffc0cb:1a1a2e"     # Pink variants
)

# Which colors.toml keys follow which variant color. The palette's other
# entries (the sakura pink in color5, the bright shades) stay as they are:
# they are part of the theme's identity and no variant defines them.
ACCENT_KEYS="accent active_border_color active_tab_background cursor selection_background color4"
SECONDARY_KEYS="color1"
TERTIARY_KEYS="color2"
BACKGROUND_KEYS="background color0 selection_foreground"

# Only text files carry the palette. Everything else in the theme directory is
# an image or a binary.
TEXT_PATTERNS=(toml css conf ini json lua theme rgb txt md)

get_current_variant() {
  if [[ -f "$CURRENT_VARIANT_FILE" ]]; then
    cat "$CURRENT_VARIANT_FILE"
  else
    echo "cyberpunk"
  fi
}

list_variants() {
  echo "Available theme variants:"
  local current variant
  current=$(get_current_variant)
  while IFS= read -r variant; do
    if [[ "$variant" == "$current" ]]; then
      echo "  ✓ $variant (current)"
    else
      echo "  • $variant"
    fi
  done < <(printf '%s\n' "${!VARIANTS[@]}" | LC_ALL=C sort)
}

# Read a key from a colors.toml file.
toml_value() {
  local file="$1" key="$2"
  sed -n -E "s|^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"?#?([0-9a-fA-F]{6})\"?.*$|\1|p" \
    "$file" | head -n 1
}

# The pristine colors.toml: the one that was saved before the first switch.
pristine_colors_file() {
  printf '%s/colors.toml\n' "$ORIGINAL_DIR"
}

# Build "old hex -> new hex" for every color the variant replaces.
#
# The theme ships its own ghostty.conf, foot.ini, alacritty.toml, shell.toml,
# btop.theme, vscode-theme.json and gtk.css. Omarchy only renders a template
# when the theme does not ship that file, so those static copies are what the
# terminal, the bar, btop, VS Code and GTK really use — editing colors.toml
# alone would change almost nothing. Replacing the hex values in every file
# keeps all of them in sync.
build_color_map() {
  local source="$1" accent="$2" secondary="$3" tertiary="$4" background="$5"
  local key old
  local -A map=()

  local -a groups=("$ACCENT_KEYS" "$SECONDARY_KEYS" "$TERTIARY_KEYS" "$BACKGROUND_KEYS")
  local -a targets=("$accent" "$secondary" "$tertiary" "$background")
  local index key_list new_value

  for index in "${!groups[@]}"; do
    key_list="${groups[$index]}"
    new_value="${targets[$index]}"
    for key in $key_list; do
      old="$(toml_value "$source" "$key")"
      [[ -n $old ]] || continue
      if [[ -n ${map[$old]:-} && ${map[$old]} != "$new_value" ]]; then
        printf 'conflicting colors: #%s is used by two variant colors\n' "$old" >&2
        continue
      fi
      map[$old]="$new_value"
    done
  done

  for old in "${!map[@]}"; do
    printf '%s %s\n' "$old" "${map[$old]}"
  done
}

# Files in the theme directory that carry the palette.
variant_files() {
  local file pattern
  for pattern in "${TEXT_PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
      printf '%s\n' "$file"
    done < <(find "$THEME_DIR" -type f -name "*.$pattern" -print0 2>/dev/null)
  done
}

# Restore the pristine copies and apply the new colors to them.
apply_to_theme_files() {
  local map_file="$1" file relative backup old new
  local -a map_pairs=()

  while read -r old new; do
    [[ -n $old && -n $new ]] || continue
    map_pairs+=("$old" "$new")
  done <"$map_file"

  [[ ${#map_pairs[@]} -gt 0 ]] || return 0

  while IFS= read -r file; do
    relative="${file#$THEME_DIR/}"
    backup="$ORIGINAL_DIR/$relative"

    # First switch: keep the untouched file so the next variant starts from
    # the same baseline again.
    if [[ ! -f $backup ]]; then
      mkdir -p "$(dirname "$backup")"
      cp "$file" "$backup"
    else
      cp "$backup" "$file"
    fi

    local index
    for ((index = 0; index < ${#map_pairs[@]}; index += 2)); do
      old="${map_pairs[$index]}"
      new="${map_pairs[$((index + 1))]}"
      sed -i "s/${old}/${new}/g" "$file"
    done
  done < <(variant_files)
}

# Re-render the theme from its templates. Without this the new colors only
# live in the theme directory: the Hyprland border, the shell and the
# terminals keep the old palette until the next login.
apply_theme() {
  if ! command -v omarchy >/dev/null 2>&1; then
    echo "warning: omarchy is not installed, the variant was written to the theme files only" >&2
    return 0
  fi

  local current
  current=$(omarchy theme current 2>/dev/null || true)
  case "$current" in
    [Vv]irtual*)
      omarchy theme refresh >/dev/null 2>&1 \
        || omarchy theme set virtual-paradise >/dev/null 2>&1 \
        || {
          echo "warning: omarchy could not re-apply the theme" >&2
          return 1
        }
      ;;
    *)
      omarchy theme set virtual-paradise >/dev/null 2>&1 \
        || {
          echo "warning: omarchy could not apply the theme" >&2
          return 1
        }
      ;;
  esac

  # The Hyprland border is generated into ~/.local/state/omarchy/current/theme
  # and needs a reload; the shell hot-reloads on its own.
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
  return 0
}

apply_variant() {
  local variant="$1"

  if [[ -z "${VARIANTS[$variant]:-}" ]]; then
    echo "Unknown variant: $variant"
    echo "Available: $(printf '%s\n' "${!VARIANTS[@]}" | LC_ALL=C sort | tr '\n' ' ')"
    exit 1
  fi

  if [[ ! -f "$THEME_DIR/colors.toml" ]]; then
    echo "Virtual Paradise is not installed: $THEME_DIR/colors.toml is missing." >&2
    echo "Run the installer first (./install.sh)." >&2
    exit 1
  fi

  echo "Applying variant: $variant"

  # Keep the untouched palette once, so 'reset' can bring it back and every
  # later variant starts from the same baseline.
  if [[ ! -f "$(pristine_colors_file)" ]]; then
    mkdir -p "$ORIGINAL_DIR"
    cp "$THEME_DIR/colors.toml" "$(pristine_colors_file)"
  fi

  # Parse colors
  local accent secondary tertiary background
  IFS=':' read -r accent secondary tertiary background <<<"${VARIANTS[$variant]}"

  local map_file="$STATE_DIR/theme-variant-map"
  build_color_map "$(pristine_colors_file)" "$accent" "$secondary" "$tertiary" "$background" >"$map_file"
  apply_to_theme_files "$map_file"

  # Save current variant only after the palette was actually written.
  echo "$variant" >"$CURRENT_VARIANT_FILE"

  apply_theme || true

  echo ""
  echo "✓ Theme variant '$variant' applied successfully!"
  echo ""
  echo "Colors:"
  echo "  Accent:     #$accent"
  echo "  Secondary:  #$secondary"
  echo "  Tertiary:   #$tertiary"
  echo "  Background: #$background"
}

reset_variant() {
  if [[ ! -d "$ORIGINAL_DIR" ]]; then
    echo "No saved palette to restore." >&2
    exit 1
  fi

  local file relative
  while IFS= read -r -d '' file; do
    relative="${file#$ORIGINAL_DIR/}"
    cp "$file" "$THEME_DIR/$relative"
  done < <(find "$ORIGINAL_DIR" -type f -print0)

  rm -rf "$ORIGINAL_DIR"
  rm -f "$CURRENT_VARIANT_FILE" "$STATE_DIR/theme-variant-map"
  apply_theme || true
  echo "✓ Original palette restored."
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

  while IFS= read -r variant; do
    if [[ "$variant" != "$current" ]]; then
      options+=("$variant")
      variants+=("$variant")
    fi
  done < <(printf '%s\n' "${!VARIANTS[@]}" | LC_ALL=C sort)

  if [[ ${#options[@]} -eq 0 ]]; then
    echo "No other variants available."
    exit 0
  fi

  # Try to use fzf if available
  if command -v fzf >/dev/null; then
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
  "reset")
    reset_variant
    ;;
  "cyberpunk"|"cozy"|"monochrome"|"neon"|"sakura")
    apply_variant "$1"
    ;;
  *)
    echo "Usage: $0 [variant|list|reset]"
    echo ""
    echo "Variants: cyberpunk, cozy, monochrome, neon, sakura"
    echo ""
    echo "Examples:"
    echo "  $0              # Interactive menu"
    echo "  $0 list         # List available variants"
    echo "  $0 cyberpunk    # Switch to cyberpunk"
    echo "  $0 reset        # Restore the original palette"
    exit 1
    ;;
esac
