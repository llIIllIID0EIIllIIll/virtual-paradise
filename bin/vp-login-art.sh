#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — palette login artwork
# ==============================================================================
#  Usage:
#    vp-login-art.sh [--dry-run] [apply]
#    vp-login-art.sh restore
#
#  Builds palette-tinted SDDM login assets (backdrop, still, frame) from the
#  active Background/Accent and installs them into the Virtual Paradise SDDM
#  theme. The original assets are backed up under
#  ~/.local/state/virtual-paradise/artwork/login/original for restore.
#
#  Plymouth/boot artwork is not touched: changing it needs sudo plus an
#  initramfs rebuild and can leave a machine unable to show its splash.
# ==============================================================================

set -euo pipefail

state="$HOME/.local/state/virtual-paradise"
palette="$state/palette.json"
art="$state/artwork/login"
originals="$art/original"
theme_dir="${VP_SDDM_THEME_DIR:-/usr/share/sddm/themes/virtual-paradise}"

dry_run=0
action="apply"
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    apply|restore) action="$arg" ;;
    -h|--help)
      sed -n '4,17p' "$0" | sed 's/^#  //'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

command -v magick >/dev/null 2>&1 || {
  echo "ImageMagick (magick) is required for login artwork." >&2
  exit 1
}

run_privileged() {
  if sudo -n true 2>/dev/null; then
    sudo "$@"
  elif [[ -t 0 && -t 1 ]]; then
    # Interactive CLI: let sudo prompt normally instead of spawning a
    # polkit dialog that can be dismissed independently of the command.
    sudo "$@"
  elif command -v pkexec >/dev/null 2>&1; then
    pkexec "$@"
  else
    echo "Root is required to install login artwork; run with sudo." >&2
    return 1
  fi
}

if [[ $action == restore ]]; then
  [[ -f "$originals/backdrop.png" ]] || {
    echo "No saved login artwork to restore." >&2
    exit 1
  }
  files=(backdrop.png still.png frame.png)
  if [[ $dry_run -eq 1 ]]; then
    printf 'Would restore %s to %s\n' "${files[*]}" "$theme_dir"
    exit 0
  fi
  for file in "${files[@]}"; do
    [[ -f "$originals/$file" ]] || continue
    run_privileged install -m 644 "$originals/$file" "$theme_dir/$file"
  done
  printf 'Restored login artwork in %s\n' "$theme_dir"
  exit 0
fi

[[ -f $palette ]] || {
  echo "No live palette at $palette" >&2
  exit 1
}

read -r accent background < <(flock -s "$state/palette.lock" python3 - "$palette" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
roles = []
for key in ("accent", "background"):
    value = data.get(key)
    if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
        raise SystemExit(f"palette has no {key}")
    if any(c not in "0123456789abcdefABCDEF" for c in value[1:]):
        raise SystemExit(f"palette has an invalid {key}")
    roles.append(value)
print(*roles)
PY
)

backdrop_source="${VP_LOGIN_BACKDROP:-$theme_dir/backdrop.png}"
still_source="${VP_LOGIN_STILL:-$theme_dir/still.png}"
frame_source="${VP_LOGIN_FRAME:-$theme_dir/frame.png}"
[[ -f $backdrop_source ]] || backdrop_source="$HOME/.local/share/virtual-paradise/plymouth/backdrop.png"
[[ -f $backdrop_source ]] || backdrop_source="$HOME/plymouth/backdrop.png"
[[ -f $still_source ]] || still_source="$HOME/.local/share/virtual-paradise/sddm/assets/still.png"
[[ -f $still_source ]] || still_source="$HOME/sddm/assets/still.png"
[[ -f $frame_source ]] || frame_source="$HOME/.local/share/virtual-paradise/plymouth/frame.png"
[[ -f $frame_source ]] || frame_source="$HOME/plymouth/frame.png"
for source in "$backdrop_source" "$still_source" "$frame_source"; do
  [[ -f $source ]] || {
    echo "Missing login artwork source: $source" >&2
    exit 1
  }
done

mkdir -p "$art/out" "$originals"

# Keep the first real copy, never a tinted one, as the restore source.
if [[ ! -f "$originals/backdrop.png" && $backdrop_source == "$theme_dir/backdrop.png" ]]; then
  cp -f "$backdrop_source" "$originals/backdrop.png"
fi
if [[ ! -f "$originals/still.png" && $still_source == "$theme_dir/still.png" ]]; then
  cp -f "$still_source" "$originals/still.png"
fi
if [[ ! -f "$originals/frame.png" && $frame_source == "$theme_dir/frame.png" ]]; then
  cp -f "$frame_source" "$originals/frame.png"
fi

# If originals exist, always tint from them so repeated applies stay clean.
[[ -f "$originals/backdrop.png" ]] && backdrop_source="$originals/backdrop.png"
[[ -f "$originals/still.png" ]] && still_source="$originals/still.png"
[[ -f "$originals/frame.png" ]] && frame_source="$originals/frame.png"

out="$art/out"
signature="$accent:$background"
stamp="$art/stamp"
if ! [[ -f $stamp && "$(cat "$stamp")" == "$signature" && -f "$out/backdrop.png" \
        && -f "$out/still.png" && -f "$out/frame.png" ]]; then
  magick "$backdrop_source" -auto-orient -resize 1920x1080^ -gravity center -extent 1920x1080 \
    -colorspace gray +level-colors "$background,$accent" -quality 92 "$out/backdrop.png"
  magick "$still_source" -fill "$accent" -colorize 38% -quality 92 "$out/still.png"
  magick "$frame_source" -fill "$accent" -colorize 65% -quality 92 "$out/frame.png"
  for file in backdrop.png still.png frame.png; do
    identify "$out/$file" >/dev/null 2>&1 || {
      echo "ImageMagick did not produce a valid $file" >&2
      exit 1
    }
  done
  printf '%s\n' "$signature" >"$stamp"
fi

if [[ $dry_run -eq 1 ]]; then
  printf '%s\n' "$out"
  exit 0
fi

if [[ ! -d $theme_dir ]]; then
  echo "SDDM theme is not installed at $theme_dir" >&2
  exit 1
fi

for file in backdrop.png still.png frame.png; do
  run_privileged install -m 644 "$out/$file" "$theme_dir/$file"
done
printf 'Applied palette login artwork to %s\n' "$theme_dir"
