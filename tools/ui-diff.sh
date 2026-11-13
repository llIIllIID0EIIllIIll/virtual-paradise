#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — manual UI screenshot diff
# ==============================================================================
#  Usage:
#    tools/ui-diff.sh BASELINE_DIR NEW_DIR [--crop WxH+X+Y] [--threshold N]
#
#  Runs ui-smoke.sh --screenshots twice, then compares the captures with
#  ImageMagick. BASELINE_DIR and NEW_DIR must contain the same 01/02/03 PNGs.
#  --crop is applied to both before comparing, which is how the live bar clock
#  is excluded from a panel-only baseline.
# ==============================================================================

set -euo pipefail

baseline="${1:-}"
new="${2:-}"
[[ -n $baseline && -n $new ]] || {
  sed -n '4,12p' "$0" | sed 's/^#  //'
  exit 2
}
shift 2

crop=""
threshold=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --crop) crop="${2:-}"; shift 2 ;;
    --threshold) threshold="${2:-}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
command -v magick >/dev/null 2>&1 || {
  echo "ImageMagick (magick) is required." >&2
  exit 1
}

fail=0
for file in "$baseline"/*.png; do
  [[ -f $file ]] || continue
  name="$(basename "$file")"
  other="$new/$name"
  [[ -f $other ]] || {
    echo "MISSING $name in $new" >&2
    fail=1
    continue
  }
  left="$file"
  right="$other"
  tmpdir="$(mktemp -d)"
  if [[ -n $crop ]]; then
    magick "$file" -crop "$crop" +repage "$tmpdir/left.png"
    magick "$other" -crop "$crop" +repage "$tmpdir/right.png"
    left="$tmpdir/left.png"
    right="$tmpdir/right.png"
  fi
  metric="$(magick compare -metric AE -fuzz 2% "$left" "$right" null: 2>&1 || true)"
  echo "$name: $metric differing pixel(s)"
  if awk -v metric="$metric" -v threshold="$threshold" 'BEGIN { exit !(metric + 0 > threshold + 0) }'; then
    fail=1
  fi
  rm -rf "$tmpdir"
done

[[ $fail -eq 0 ]] && echo "PASS: screenshots within threshold $threshold"
exit "$fail"
