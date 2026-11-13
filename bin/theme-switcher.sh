#!/bin/bash
# ==============================================================================
#  Virtual☆Paradise — Theme Variant Switcher
# ==============================================================================
#  Usage:
#    theme-switcher.sh              # Interactive menu
#    theme-switcher.sh cyberpunk    # Restore the default neon palette
#    theme-switcher.sh catppuccin   # Match Omarchy's Catppuccin palette
#    theme-switcher.sh custom 5e8eed [secondary tertiary warm pink hot background text]
#                                    # Full custom palette (hex, no '#')
#    theme-switcher.sh wallpaper    # Derive the palette from the wallpaper
#    theme-switcher.sh list         # List available variants
#    theme-switcher.sh reset        # Restore the original palette
# ==============================================================================

set -euo pipefail

THEME_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes/virtual-paradise"
STATE_DIR="$HOME/.local/state/virtual-paradise"
CURRENT_VARIANT_FILE="$STATE_DIR/current_variant"
ORIGINAL_DIR="$STATE_DIR/theme-variant-orig"

mkdir -p "$STATE_DIR"

# Accent palettes. Each entry is
#   accent:secondary:tertiary:warm:pink:background:hot
# and mirrors the matching Omarchy theme (or the well-known web palette for
# Dracula/Rose Pine Moon). Cyberpunk is the theme's own identity.
declare -A VARIANTS=(
  ["cyberpunk"]="00ffdd:ff00ff:00ff88:ffe066:ffb7d5:0f081d:ff0055"
  ["neon"]="00ffff:ff00ff:00ff00:ffff00:ff00ff:0a0a0a:ff0000"
  ["monochrome"]="ffffff:cccccc:888888:eeeeee:dddddd:000000:ff5555"
  ["catppuccin"]="89b4fa:f5c2e7:a6e3a1:f9e2af:f5c2e7:1e1e2e:f38ba8"
  ["tokyo-night"]="7aa2f7:bb9af7:9ece6a:e0af68:bb9af7:1a1b26:f7768e"
  ["gruvbox"]="7daea3:d3869b:a9b665:d8a657:d3869b:282828:ea6962"
  ["nord"]="81a1c1:b48ead:a3be8c:ebcb8b:b48ead:2e3440:bf616a"
  ["everforest"]="7fbbb3:d699b6:a7c080:dbbc7f:d699b6:2d353b:e67e80"
  ["kanagawa"]="7e9cd8:957fb8:98bb6c:e6c384:957fb8:1f1f28:c34043"
  ["rose-pine"]="c4a7e7:ea9a97:9ccfd8:f6c177:ea9a97:232136:eb6f92"
  ["hackerman"]="82fb9c:7cf8f7:50f7d4:50f7d4:7cf8f7:0b0c16:ff5f7a"
  ["dracula"]="bd93f9:ff79c6:8be9fd:f1fa8c:ff79c6:282a36:ff5555"
)

# Which colors.toml keys follow which variant colour. The semantic roles at
# the bottom of colors.toml are included, otherwise the ANSI colours change
# but the GTK/terminal/shell roles keep the cyberpunk palette.
ACCENT_KEYS="accent active_border_color active_tab_background cursor selection_background selection color4 color6 color12 color14 blue cyan bright_blue"
SECONDARY_KEYS="color1"
TERTIARY_KEYS="color2 color10 green bright_green"
WARM_KEYS="color3 color11 yellow bright_yellow"
PINK_KEYS="color5 color13 magenta bright_magenta"
HOT_KEYS="red color9 bright_red"
BACKGROUND_KEYS="background color0 selection_foreground bg dark_bg darker_bg lighter_bg"
FOREGROUND_KEYS="foreground fg light_fg soft_fg bright_fg"

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
  local source="$1" accent="$2" secondary="$3" tertiary="$4" warm="$5" pink="$6" hot="$7" background="$8" foreground="$9"
  local key old
  local -A map=()

  local -a groups=("$ACCENT_KEYS" "$SECONDARY_KEYS" "$TERTIARY_KEYS" "$WARM_KEYS" "$PINK_KEYS" "$HOT_KEYS" "$BACKGROUND_KEYS" "$FOREGROUND_KEYS")
  local -a targets=("$accent" "$secondary" "$tertiary" "$warm" "$pink" "$hot" "$background" "$foreground")
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
reload_live_consumers() {
  # The settings panel asks for this on each debounced theme pass: sync Cava
  # from the just-written colors.toml and let sync_cava_theme.py signal it.
  [[ ${VP_RELOAD_CONSUMERS:-0} == 1 ]] || return 0
  local sync_cava="$HOME/.local/bin/sync_cava_theme.py"
  if [[ -x $sync_cava ]]; then
    "$sync_cava" "virtual-paradise" >/dev/null 2>&1 || true
  fi
}

apply_theme() {
  # The settings panel writes the text files on every debounce but defers the
  # shell-wide refresh until it closes: `omarchy theme refresh` tears down the
  # panel, which made Undo/Redo disappear ~0.5s after the first click.
  if [[ ${VP_NO_THEME_REFRESH:-0} == 1 ]]; then
    return 0
  fi
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

# Serialize palette-producing operations with vp-palette.sh. Both writers use
# the same lock file, so a debounced custom write cannot interleave with a named
# palette switch.
with_state_lock() {
  mkdir -p "$STATE_DIR"
  local lock_fd
  exec {lock_fd}>"$STATE_DIR/palette.lock"
  flock -x "$lock_fd"
  "$@"
  local rc=$?
  flock -u "$lock_fd" 2>/dev/null || true
  exec {lock_fd}>&-
  return $rc
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
  local accent secondary tertiary warm pink background hot foreground
  IFS=':' read -r accent secondary tertiary warm pink background hot <<<"${VARIANTS[$variant]}"
  foreground="$(toml_value "$(pristine_colors_file)" foreground)"
  [[ -n $foreground ]] || foreground="eafbfa"

  local map_file="$STATE_DIR/theme-variant-map"
  build_color_map "$(pristine_colors_file)" "$accent" "$secondary" "$tertiary" "$warm" "$pink" "$hot" "$background" "$foreground" >"$map_file"
  apply_to_theme_files "$map_file"
  reload_live_consumers

  # Save current variant only after the palette was actually written.
  echo "$variant" >"$CURRENT_VARIANT_FILE"
  write_palette "$variant" "$accent" "$secondary" "$tertiary" "$warm" "$pink" "$background" "$hot" "$foreground"

  apply_theme || true

  echo ""
  echo "✓ Theme variant '$variant' applied successfully!"
  echo ""
  echo "Colors:"
  echo "  Accent:     #$accent"
  echo "  Secondary:  #$secondary"
  echo "  Tertiary:   #$tertiary"
  echo "  Warm:       #$warm"
  echo "  Pink:       #$pink"
  echo "  Background: #$background"
}

# Write the semantic palette the QML bar reads. The theme text files get the
# colors through build_color_map; this JSON is the same palette in a form the
# widgets can bind to without duplicating the switcher.
write_palette() {
  # The settings panel writes palette.json through vp-palette.sh, which is the
  # single source of truth while editing. A detached theme file pass must not
  # overwrite it with an older color if it happens to finish later.
  if [[ ${VP_SKIP_PALETTE_WRITE:-0} == 1 ]]; then
    return 0
  fi
  local name="$1" accent="$2" secondary="$3" tertiary="$4" warm="$5" pink="$6" background="$7" hot="$8" foreground="${9:-}"
  local tmp payload
  [[ -n $foreground ]] || foreground="$(toml_value "$(pristine_colors_file)" foreground)"
  [[ -n $foreground ]] || foreground="eafbfa"
  tmp="$(mktemp "$STATE_DIR/.palette.XXXXXX")" || return 1
  printf -v payload '{\n  "name": "%s",\n  "accent": "#%s",\n  "secondary": "#%s",\n  "tertiary": "#%s",\n  "warm": "#%s",\n  "pink": "#%s",\n  "background": "#%s",\n  "foreground": "#%s",\n  "hot": "#%s"\n}\n' \
    "$name" "$accent" "$secondary" "$tertiary" "$warm" "$pink" "$background" "$foreground" "$hot"
  if [[ -f "$STATE_DIR/palette.json" ]] \
     && [[ "$(cat "$STATE_DIR/palette.json")" == "${payload%$'\n'}" ]]; then
    rm -f "$tmp"
    return 0
  fi
  printf '%s' "$payload" >"$tmp" || return 1
  mv "$tmp" "$STATE_DIR/palette.json" || return 1
  # Quickshell's FileView watches the opened inode; an atomic rename replaces
  # it. Rewriting the same bytes in place emits the modify event the bar needs,
  # so the bar no longer has to poll this file every 300 ms.
  printf '%s' "$payload" >"$STATE_DIR/palette.json"
}

reset_variant() {
  with_state_lock reset_variant_locked
}

reset_variant_locked() {
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
  local a b c d e f g
  IFS=':' read -r a b c d e f g <<<"${VARIANTS[cyberpunk]}"
  write_palette cyberpunk "$a" "$b" "$c" "$d" "$e" "$f" "$g"
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

# Read the most vivid dominant colour of an image or a video frame.
wallpaper_accent() {
  local src="$1"
  # Omarchy's current background is a symlink named "background", without an
  # extension. Resolve it before the video/image branch or every video is
  # treated as a still image.
  src="$(readlink -f "$src" 2>/dev/null || printf '%s' "$src")"
  [[ -f $src ]] || return 1
  local tmp best="" best_score=0 hex score s v
  tmp="$(mktemp --suffix=.png)" || return 1
  case "$src" in
    *.mp4|*.webm|*.mkv|*.mov|*.gif)
      command -v ffmpeg >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
      ffmpeg -y -loglevel error -ss 1 -i "$src" -frames:v 1 "$tmp" >/dev/null 2>&1 \
        || { rm -f "$tmp"; return 1; }
      ;;
    *)
      magick "$src" -resize 160x160 "$tmp" >/dev/null 2>&1 \
        || { rm -f "$tmp"; return 1; }
      ;;
  esac
  while IFS= read -r hex; do
    [[ -n $hex ]] || continue
    read -r s v < <(magick xc:"#$hex" -colorspace HSL \
      -format '%[fx:s*100] %[fx:lightness*100]' info: 2>/dev/null) || true
    score=$(awk -v s="${s:-0}" -v v="${v:-0}" 'BEGIN { printf "%d", s*v }')
    if (( score > best_score )); then
      best_score=$score
      best=$hex
    fi
  done < <(magick "$tmp" -resize 25% -colors 12 -unique-colors txt:- 2>/dev/null \
    | awk -F'#' 'NR>1 {print $2}' | cut -c1-6)
  rm -f "$tmp"
  [[ -n $best ]] || return 1
  # Lift saturation so the accent reads as neon instead of mud.
  magick xc:"#$best" -colorspace HSL -channel G -evaluate multiply 1.3 +channel \
    -colorspace sRGB -depth 8 -format '%[hex:p{0,0}]' info: 2>/dev/null | cut -c1-6
}

# Rotate a hex colour's hue. ImageMagick's modulate hue is a percentage of the
# wheel: 100 keeps it, 150 is the complement.
hue_shift() {
  if command -v magick >/dev/null 2>&1; then
    magick xc:"#$1" -modulate 100,110,"$2" -depth 8 \
      -format '%[hex:p{0,0}]' info: 2>/dev/null | cut -c1-6
    return
  fi
  # CI and minimal installs may not have ImageMagick. colorsys gives the same
  # hue rotation with a small saturation lift.
  python3 - "$1" "$2" <<'PY'
import colorsys, sys
value = sys.argv[1].lstrip("#")
shift = float(sys.argv[2]) / 360.0
r, g, b = (int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
h, l, s = colorsys.rgb_to_hls(r, g, b)
r, g, b = colorsys.hls_to_rgb((h + shift) % 1.0, l, min(1.0, s * 1.1))
print("%02x%02x%02x" % tuple(round(v * 255) for v in (r, g, b)))
PY
}

# Derive a whole palette from the current wallpaper and apply it through the
# same pristine-backup machinery the named variants use.
wallpaper_variant() {
  with_state_lock wallpaper_variant_locked "$@"
}

wallpaper_variant_locked() {
  local src="${1:-$HOME/.local/state/omarchy/current/background}"
  if [[ ! -f "$THEME_DIR/colors.toml" ]]; then
    echo "Virtual Paradise is not installed: $THEME_DIR/colors.toml is missing." >&2
    echo "Run the installer first (./install.sh)." >&2
    exit 1
  fi
  local accent secondary tertiary warm pink background hot foreground
  # Keep the untouched palette first: the background baseline and the
  # reset path both come from it.
  if [[ ! -f "$(pristine_colors_file)" ]]; then
    mkdir -p "$ORIGINAL_DIR"
    cp "$THEME_DIR/colors.toml" "$(pristine_colors_file)"
  fi
  accent="$(wallpaper_accent "$src")"
  if [[ -z $accent ]]; then
    echo "Could not derive a colour from '$src'." >&2
    exit 1
  fi
  secondary="$(hue_shift "$accent" 150)"
  tertiary="$(hue_shift "$accent" 125)"
  warm="$(hue_shift "$accent" 45)"
  pink="$(hue_shift "$accent" 330)"
  hot="$(hue_shift "$accent" 180)"
  background="$(toml_value "$(pristine_colors_file)" background)"
  [[ -n $background ]] || background="0f081d"
  foreground="$(toml_value "$(pristine_colors_file)" foreground)"
  [[ -n $foreground ]] || foreground="eafbfa"

  local map_file="$STATE_DIR/theme-variant-map"
  build_color_map "$(pristine_colors_file)" "$accent" "$secondary" "$tertiary" "$warm" "$pink" "$hot" "$background" "$foreground" >"$map_file"
  apply_to_theme_files "$map_file"
  reload_live_consumers
  echo "wallpaper" >"$CURRENT_VARIANT_FILE"
  write_palette "wallpaper" "$accent" "$secondary" "$tertiary" "$warm" "$pink" "$background" "$hot" "$foreground"
  apply_theme || true
  echo ""
  echo "✓ Wallpaper accent applied from $(basename "$src")"
  echo "  Accent:    #$accent"
  echo "  Secondary: #$secondary"
  echo "  Tertiary:  #$tertiary"
  echo "  Warm:      #$warm"
  echo "  Pink:      #$pink"
}

# Apply an arbitrary six-digit accent by deriving the companion colours from
# it. The background stays the theme's dark baseline; the settings color picker
# uses this path.
apply_custom() {
  with_state_lock apply_custom_locked "$@"
}

apply_custom_locked() {
  local accent="${1#\#}" secondary="${2:-}" tertiary="${3:-}" warm="${4:-}" pink="${5:-}" hot="${6:-}" background="${7:-}" foreground="${8:-}"
  if [[ ! $accent =~ ^[0-9a-fA-F]{6}$ ]]; then
    echo "Usage: $0 custom <accent> [secondary tertiary warm pink hot background foreground]" >&2
    exit 1
  fi
  local color
  for color in "$secondary" "$tertiary" "$warm" "$pink" "$hot" "$background" "$foreground"; do
    if [[ -n $color && ! $color =~ ^[0-9a-fA-F]{6}$ ]]; then
      echo "Invalid color: #$color" >&2
      exit 1
    fi
  done
  if [[ ! -f "$THEME_DIR/colors.toml" ]]; then
    echo "Virtual Paradise is not installed: $THEME_DIR/colors.toml is missing." >&2
    exit 1
  fi

  if [[ ! -f "$(pristine_colors_file)" ]]; then
    mkdir -p "$ORIGINAL_DIR"
    cp "$THEME_DIR/colors.toml" "$(pristine_colors_file)"
  fi

  [[ -n $secondary ]] || secondary="$(hue_shift "$accent" 150)"
  [[ -n $tertiary ]] || tertiary="$(hue_shift "$accent" 125)"
  [[ -n $warm ]] || warm="$(hue_shift "$accent" 45)"
  [[ -n $pink ]] || pink="$(hue_shift "$accent" 330)"
  [[ -n $hot ]] || hot="$(hue_shift "$accent" 180)"
  [[ -n $background ]] || background="$(toml_value "$(pristine_colors_file)" background)"
  [[ -n $background ]] || background="0f081d"
  [[ -n $foreground ]] || foreground="$(toml_value "$(pristine_colors_file)" foreground)"
  [[ -n $foreground ]] || foreground="eafbfa"

  local map_file="$STATE_DIR/theme-variant-map"
  build_color_map "$(pristine_colors_file)" "$accent" "$secondary" "$tertiary" "$warm" "$pink" "$hot" "$background" "$foreground" >"$map_file"
  apply_to_theme_files "$map_file"
  reload_live_consumers
  echo "custom" >"$CURRENT_VARIANT_FILE"
  write_palette "custom" "$accent" "$secondary" "$tertiary" "$warm" "$pink" "$background" "$hot" "$foreground"
  apply_theme || true
  echo ""
  echo "✓ Custom theme applied"
  echo "  Accent:     #$accent"
  echo "  Secondary:  #$secondary"
  echo "  Tertiary:   #$tertiary"
  echo "  Warm:       #$warm"
  echo "  Pink:       #$pink"
  echo "  Urgent:     #$hot"
  echo "  Background: #$background"
  echo "  Text:       #$foreground"
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
  "wallpaper")
    wallpaper_variant "${2:-}"
    ;;
  "custom")
    shift
    apply_custom "$@"
    ;;
  *)
    if [[ -n ${VARIANTS[${1:-}]:-} ]]; then
      apply_variant "$1"
      exit 0
    fi
    echo "Usage: $0 [variant|custom <RRGGBB>|wallpaper [image]|list|reset]"
    echo ""
    echo "Variants: $(printf '%s\n' "${!VARIANTS[@]}" | LC_ALL=C sort | tr '\n' ' ')"
    echo "wallpaper derives the palette from the current background (or the"
    echo "image passed as the second argument)."
    echo ""
    echo "Examples:"
    echo "  $0              # Interactive menu"
    echo "  $0 list         # List available variants"
    echo "  $0 cyberpunk    # Switch to cyberpunk"
    echo "  $0 wallpaper    # Palette from the current wallpaper"
    echo "  $0 reset        # Restore the original palette"
    exit 1
    ;;
esac
