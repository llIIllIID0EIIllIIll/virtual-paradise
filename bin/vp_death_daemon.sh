#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Window Death daemon
# ==============================================================================
#  Keeps the death burst warm so a death costs no Quickshell startup: the
#  daemon watches the trigger file and maps the burst in a single frame, in
#  the same breath as the close. Started from the Hyprland autostart.
# ==============================================================================

CURRENT_THEME="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo "")"
[[ "$CURRENT_THEME" != "virtual-paradise" ]] && exit 0

command -v quickshell &>/dev/null || exit 0

# FileView only watches paths that exist when the shell starts: create the
# trigger file up front (empty), so the very first death is seen.
: > "${XDG_RUNTIME_DIR:-/tmp}/vp_death_trigger"

# One daemon per session.
if pgrep -f "[v]p_death_daemon\.qml" &>/dev/null; then
  exit 0
fi

exec quickshell -p "${VP_DEATH_DAEMON_QML:-$HOME/.local/bin/vp_death_daemon.qml}"
