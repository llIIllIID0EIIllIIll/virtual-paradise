#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Terminal Banner
# ==============================================================================
#  Prints the themed ASCII banner.
#
#  The art is static and its colors come from the active theme, so it is
#  rendered once per theme and cached. Rendering it in Python cost ~30 ms of
#  every interactive shell - the interpreter startup, not the drawing - so the
#  cached copy is printed from the shell instead, in about a millisecond.
#
#  The cache key is the theme name plus the modification time of its
#  colors.toml, so a palette variant invalidates it as well.

set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/virtual-paradise"
CACHE_FILE="$CACHE_DIR/banner.txt"
THEME_NAME_FILE="$HOME/.local/state/omarchy/current/theme.name"
COLORS_FILE="$HOME/.local/state/omarchy/current/theme/colors.toml"

theme_name=""
[[ -f $THEME_NAME_FILE ]] && theme_name="$(<"$THEME_NAME_FILE")"
colors_stamp=0
[[ -f $COLORS_FILE ]] && colors_stamp="$(stat -c '%Y' "$COLORS_FILE" 2>/dev/null || echo 0)"

key="${theme_name:-none}:${colors_stamp}"

if [[ -f $CACHE_FILE ]]; then
  cached_key="$(head -n1 "$CACHE_FILE" 2>/dev/null)"
  if [[ $cached_key == "# $key" ]]; then
    # Skip the key line and print the cached banner.
    tail -n +2 "$CACHE_FILE"
    exit 0
  fi
fi

# Nothing cached (or stale): render it and keep the result.
renderer="$HOME/.local/bin/paradise_banner.py"
if [[ ! -f $renderer ]]; then
  renderer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/paradise_banner.py"
fi

if [[ -f $renderer ]]; then
  banner="$(python3 "$renderer" 2>/dev/null)" || banner=""
  if [[ -n $banner ]]; then
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    { printf '# %s\n' "$key"; printf '%s\n' "$banner"; } >"$CACHE_FILE" 2>/dev/null || true
    printf '%s\n' "$banner"
    exit 0
  fi
fi

exit 0
