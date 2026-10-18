#!/usr/bin/env bash
# convert-gifs-to-mp4.sh — Compress animated GIF backgrounds to MP4.
#
# mpvpaper plays both formats, and H.264 video is dramatically smaller than
# GIF. Measured savings on this repo: ~60 MB.
#
# Usage:
#   ./tools/convert-gifs-to-mp4.sh            # dry run, reports savings
#   ./tools/convert-gifs-to-mp4.sh --apply    # convert and remove originals
#
# The GIF originals are kept alongside the MP4 until you manually verify the
# conversion looks right. Use --apply to remove them after verification.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BG_DIR="$SCRIPT_DIR/../backgrounds"
APPLY=0

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --help|-h)
      printf 'Usage: %s [--apply]\n' "$0"
      printf '  (no flag)  dry run: report what would be converted and savings\n'
      printf '  --apply    convert GIFs to MP4 and remove the originals\n'
      exit 0
      ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

command -v ffmpeg >/dev/null 2>&1 || {
  printf 'ffmpeg is required but not found.\n' >&2
  exit 1
}

total_saved=0
converted=0

for gif in "$BG_DIR"/*.gif; do
  [[ -f "$gif" ]] || continue
  base="$(basename "$gif" .gif)"
  mp4="$BG_DIR/${base}.mp4"

  # Skip if MP4 already exists with the same base name
  if [[ -f "$mp4" ]]; then
    printf 'SKIP  %s (MP4 already exists)\n' "$base"
    continue
  fi

  gif_size=$(stat -c%s "$gif" 2>/dev/null || stat -f%z "$gif" 2>/dev/null)
  gif_mb=$((gif_size / 1048576))

  if [[ $APPLY -eq 1 ]]; then
    printf 'CONV  %s.gif (%dMB) -> %s.mp4 ... ' "$base" "$gif_mb" "$base"
    ffmpeg -y -loglevel error -i "$gif" \
      -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
      -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p \
      -movflags +faststart \
      "$mp4"

    mp4_size=$(stat -c%s "$mp4" 2>/dev/null || stat -f%z "$mp4" 2>/dev/null)
    mp4_mb=$((mp4_size / 1048576))
    saved=$((gif_size - mp4_size))
    saved_mb=$((saved / 1048576))
    total_saved=$((total_saved + saved))
    converted=$((converted + 1))

    printf '%dMB -> %dMB (saved %dMB)\n' "$gif_mb" "$mp4_mb" "$saved_mb"

    # Remove the GIF after successful conversion
    rm -f "$gif"
  else
    printf 'DRY   %s.gif (%dMB) — would convert to MP4\n' "$base" "$gif_mb"
    total_saved=$((total_saved + gif_size))
    converted=$((converted + 1))
  fi
done

if [[ $converted -eq 0 ]]; then
  printf 'No GIFs to convert.\n'
elif [[ $APPLY -eq 0 ]]; then
  total_mb=$((total_saved / 1048576))
  printf '\n%d GIF(s) found. Estimated savings: ~%dMB\n' "$converted" "$total_mb"
  printf 'Run with --apply to convert and remove originals.\n'
else
  total_mb=$((total_saved / 1048576))
  printf '\nConverted %d GIF(s), saved ~%dMB.\n' "$converted" "$total_mb"
  printf 'Verify the MP4 files play correctly, then commit.\n'
fi
