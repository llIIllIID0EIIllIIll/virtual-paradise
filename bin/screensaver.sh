#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — screensaver launcher
# ==============================================================================
#  Usage: screensaver.sh [matrix|starfield|miku]
#  Default: matrix. Quit matrix/starfield with Ctrl+C, miku with q.
# ==============================================================================

set -uo pipefail

mode="${1:-matrix}"
self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$mode" in
  matrix)
    exec python3 "$self_dir/virtual_matrix.py"
    ;;
  starfield)
    exec python3 "$self_dir/starfield.py"
    ;;
  miku)
    theme_dir="$HOME/.config/omarchy/backgrounds/virtual-paradise"
    for f in "$theme_dir/Miku_animated_full.mp4" "$theme_dir/Miku_live.mp4"; do
      if [[ -f $f ]] && command -v mpv >/dev/null 2>&1; then
        exec mpv --fs --loop-file=inf --no-audio --really-quiet --no-osc "$f"
      fi
    done
    echo "screensaver: no Miku animation found in $theme_dir" >&2
    exit 1
    ;;
  *)
    echo "Usage: $0 [matrix|starfield|miku]" >&2
    exit 1
    ;;
esac
