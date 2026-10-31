#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — variant by time of day
# ==============================================================================
#  Day (07:00-19:00): cyberpunk. Evening and night: sakura.
#  Runs from paradise-variant-by-time.timer; safe to run by hand.
#  Does nothing when another theme is active, so it never fights the user.
# ==============================================================================

set -uo pipefail

SWITCHER="$HOME/.local/bin/theme-switcher.sh"
[[ -x $SWITCHER ]] || exit 0

current="$(omarchy theme current 2>/dev/null || true)"
case "$current" in
  [Vv]irtual*) ;;
  *) exit 0 ;;
esac

hour="$(date +%H)"
hour="${hour#0}"
if (( hour >= 7 && hour < 19 )); then
  variant="cyberpunk"
else
  variant="sakura"
fi

exec "$SWITCHER" "$variant"
