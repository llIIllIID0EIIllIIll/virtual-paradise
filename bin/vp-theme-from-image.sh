#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — palette from an image or video
# ==============================================================================
#  Usage:
#    vp-theme-from-image.sh /path/to/image-or-video
#
#  Thin wrapper around `theme-switcher.sh wallpaper <path>` for the settings
#  panel. The shell-wide refresh is deferred to the panel's close, so the
#  settings card stays open while the bar recolors live.
# ==============================================================================

set -euo pipefail

src="${1:-}"
[[ -f $src ]] || {
  echo "No such image or video: $src" >&2
  exit 1
}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VP_NO_THEME_REFRESH=1 exec "$script_dir/theme-switcher.sh" wallpaper "$src"
