#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — palette Plymouth artwork
# ==============================================================================
#  Usage:
#    vp-plymouth-art.sh [--dry-run] [--no-rebuild] [apply]
#    vp-plymouth-art.sh [--no-rebuild] restore
#
#  Tints every PNG in the installed Plymouth theme with the live Accent,
#  backs up the originals and rebuilds the initramfs. Restore puts the
#  original frames back and rebuilds again. This touches boot art, so it is
#  deliberately opt-in and validated before any file is installed.
# ==============================================================================

set -euo pipefail

state="$HOME/.local/state/virtual-paradise"
palette="$state/palette.json"
art="$state/artwork/plymouth"
originals="$art/original"
theme_dir="${VP_PLYMOUTH_THEME_DIR:-/usr/share/plymouth/themes/virtual-paradise}"

dry_run=0
rebuild=1
action="apply"
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --no-rebuild) rebuild=0 ;;
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
  echo "ImageMagick (magick) is required for Plymouth artwork." >&2
  exit 1
}

run_privileged() {
  if sudo -n true 2>/dev/null; then
    sudo "$@"
  elif [[ -t 0 && -t 1 ]]; then
    sudo "$@"
  elif command -v pkexec >/dev/null 2>&1; then
    pkexec "$@"
  else
    echo "Root is required to change Plymouth artwork; run with sudo." >&2
    return 1
  fi
}

rebuild_initrd() {
  [[ $rebuild -eq 1 ]] || return 0
  command -v plymouth-set-default-theme >/dev/null 2>&1 || {
    echo "plymouth-set-default-theme is missing; assets are installed but the initramfs was not rebuilt." >&2
    return 1
  }
  run_privileged plymouth-set-default-theme -R
}

if [[ $action == restore ]]; then
  [[ -d $originals ]] || {
    echo "No saved Plymouth artwork to restore." >&2
    exit 1
  }
  count="$(find "$originals" -maxdepth 1 -name '*.png' | wc -l)"
  [[ $count -gt 0 ]] || {
    echo "The Plymouth backup is empty." >&2
    exit 1
  }
  if [[ $dry_run -eq 1 ]]; then
    printf 'Would restore %s PNG(s) to %s\n' "$count" "$theme_dir"
    exit 0
  fi
  run_privileged cp -f "$originals"/*.png "$theme_dir"/
  run_privileged chmod 644 "$theme_dir"/*.png
  rebuild_initrd
  printf 'Restored Plymouth artwork in %s\n' "$theme_dir"
  exit 0
fi

[[ -f $palette ]] || {
  echo "No live palette at $palette" >&2
  exit 1
}
[[ -d $theme_dir ]] || {
  echo "Plymouth theme is not installed at $theme_dir" >&2
  exit 1
}

accent="$(python3 - "$palette" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data.get("accent")
if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
    raise SystemExit("palette has no accent")
if any(c not in "0123456789abcdefABCDEF" for c in value[1:]):
    raise SystemExit("palette has an invalid accent")
print(value)
PY
)"

mkdir -p "$art/out" "$originals"

# Keep the first real copy, never a tinted one. Do not use `find | grep -q`
# here: with pipefail a SIGPIPE from find would look like "empty" and overwrite
# the backup with the already-tinted theme.
if [[ -z "$(find "$originals" -maxdepth 1 -name '*.png' -print -quit)" ]]; then
  cp -a "$theme_dir"/*.png "$originals"/
fi
count="$(find "$originals" -maxdepth 1 -name '*.png' | wc -l)"
[[ $count -gt 0 ]] || {
  echo "No PNG assets found in $theme_dir" >&2
  exit 1
}

stamp="$art/stamp"
signature="$accent:$count"
if [[ -f $stamp && "$(cat "$stamp")" == "$signature" && -d "$art/out" ]] \
   && [[ "$(find "$art/out" -maxdepth 1 -name '*.png' | wc -l)" -eq $count ]]; then
  : # Reuse the tinted frames for this exact palette and frame set.
else
  rm -rf "$art/out"
  mkdir -p "$art/out"
  magick mogrify -path "$art/out" -fill "$accent" -colorize 35% "$originals"/*.png
  out_count="$(find "$art/out" -maxdepth 1 -name '*.png' | wc -l)"
  [[ $out_count -eq $count ]] || {
    echo "Plymouth tint produced $out_count of $count frames; refusing to install." >&2
    exit 1
  }
  identify "$art/out"/*.png >/dev/null 2>&1 || {
    echo "Plymouth tint produced an invalid PNG; refusing to install." >&2
    exit 1
  }
  printf '%s\n' "$signature" >"$stamp"
fi

if [[ $dry_run -eq 1 ]]; then
  printf '%s\n' "$art/out"
  exit 0
fi

run_privileged cp -f "$art/out"/*.png "$theme_dir"/
run_privileged chmod 644 "$theme_dir"/*.png
rebuild_initrd
printf 'Applied palette Plymouth artwork to %s (%s frames)\n' "$theme_dir" "$count"
