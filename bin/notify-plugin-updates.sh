#!/usr/bin/env bash
# Notify the user when the plugin update check finds something.
#
# The check itself never updates anything; it only reports. This wrapper turns a
# non-empty report into a desktop notification and skips the noise when nothing
# changed or the machine is not on a graphical session.

set -uo pipefail

SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
UPDATER="$SELF_DIR/paradise-plugin-update"

[[ -x $UPDATER ]] || exit 0
[[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]] || exit 0
command -v notify-send >/dev/null 2>&1 || exit 0

REPORT="$("$UPDATER" --check 2>/dev/null)"

# "N plugin(s) have updates." is the only line worth surfacing.
if summary="$(grep -m1 'plugin(s) have updates' <<<"$REPORT")"; then
  detail="$(grep -cE '^[a-zA-Z0-9._-]+ +[0-9a-f]{7,}' <<<"$REPORT")"
  notify-send --app-name="Omarchy plugins" \
    --icon=software-update-available \
    --urgency=low \
    "$summary" \
    "$detail plugin(s) tracked. Apply with: paradise-plugin-update --apply"
fi