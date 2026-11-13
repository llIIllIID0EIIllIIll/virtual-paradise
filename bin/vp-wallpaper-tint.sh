#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — palette wallpaper
# ==============================================================================
#  Usage:
#    vp-wallpaper-tint.sh [--dry-run] [apply]
#    vp-wallpaper-tint.sh restore
#
#  Builds a duotone still from the current wallpaper (a video's frame or an
#  image, falling back to Glitch.jpg) using the live Background and Accent
#  colours, then sets it with `omarchy theme bg set`. `restore` puts back the
#  wallpaper that was current before the tint.
#  SDDM and Plymouth artwork intentionally stay on the cyberpunk assets for
#  now: changing boot art needs sudo and an initramfs rebuild.
# ==============================================================================

set -euo pipefail

state="$HOME/.local/state/virtual-paradise"
palette="$state/palette.json"
art="$state/artwork"
previous="$art/previous-background"

dry_run=0
action="apply"
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    apply|restore) action="$arg" ;;
    -h|--help)
      sed -n '4,15p' "$0" | sed 's/^#  //'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

command -v magick >/dev/null 2>&1 || {
  echo "ImageMagick (magick) is required for the palette wallpaper." >&2
  exit 1
}

current_background() {
  local path="$HOME/.local/state/omarchy/current/background"
  if [[ -e $path ]]; then
    readlink -f "$path" 2>/dev/null || printf '%s\n' "$path"
  fi
}

if [[ $action == restore ]]; then
  [[ -f $previous ]] || {
    echo "No palette wallpaper to restore." >&2
    exit 1
  }
  target="$(cat "$previous")"
  [[ -f $target ]] || {
    echo "Previous wallpaper is gone: $target" >&2
    exit 1
  }
  if [[ $dry_run -eq 1 ]]; then
    printf 'Would restore %s\n' "$target"
  else
    omarchy theme bg set "$target"
    rm -f "$previous"
    printf 'Restored %s\n' "$target"
  fi
  exit 0
fi

[[ -f $palette ]] || {
  echo "No live palette at $palette" >&2
  exit 1
}

accent="$(flock -s "$state/palette.lock" python3 - "$palette" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data.get("accent")
if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
    raise SystemExit("palette has no accent")
print(value)
PY
)"
background="$(flock -s "$state/palette.lock" python3 - "$palette" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data.get("background")
if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
    raise SystemExit("palette has no background")
print(value)
PY
)"

mkdir -p "$art"
source="${VP_WALLPAPER_SOURCE:-}"
if [[ -z $source ]]; then
  current="$(current_background)"
  case "$current" in
    *"$art"*|"") ;;
    *.jpg|*.jpeg|*.png|*.webp|*.gif) source="$current" ;;
    *.mp4|*.webm|*.mkv|*.mov)
      if command -v ffmpeg >/dev/null 2>&1; then
        frame="$art/source-frame.png"
        if ffmpeg -y -ss 1 -i "$current" -frames:v 1 "$frame" >/dev/null 2>&1; then
          source="$frame"
        fi
      fi
      ;;
  esac
fi
if [[ -z $source || ! -f $source ]]; then
  source="$HOME/.config/omarchy/backgrounds/virtual-paradise/Glitch.jpg"
fi
if [[ ! -f $source ]]; then
  source="$HOME/.config/omarchy/themes/virtual-paradise/preview.jpg"
fi
if [[ ! -f $source ]]; then
  source="$HOME/.local/share/virtual-paradise/backgrounds/Glitch.jpg"
fi
[[ -f $source ]] || {
  echo "Could not find a wallpaper frame to tint." >&2
  exit 1
}

output="$art/wallpaper-${accent#\#}.jpg"
magick "$source" -auto-orient -resize 1920x1080^ -gravity center -extent 1920x1080 \
  -colorspace gray +level-colors "$background,$accent" -quality 92 "$output"
identify "$output" >/dev/null 2>&1 || {
  echo "ImageMagick did not produce a valid wallpaper." >&2
  rm -f "$output"
  exit 1
}
find "$art" -maxdepth 1 -name 'wallpaper-*.jpg' ! -name "wallpaper-${accent#\#}.jpg" -delete 2>/dev/null || true

if [[ $dry_run -eq 1 ]]; then
  printf '%s\n' "$output"
  exit 0
fi

mkdir -p "$art"
before="$(current_background)"
if [[ -n $before && $before != "$output" ]]; then
  printf '%s\n' "$before" >"$previous"
fi
omarchy theme bg set "$output"
printf 'Applied palette wallpaper: %s\n' "$output"
