#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Window Death daemon
# ==============================================================================
#  Keeps the death burst warm so a death costs no Quickshell startup: the
#  burst surfaces stay mapped, and a trigger turns the next frame into the
#  glitch - before the window starts to close. Started from the Hyprland
#  autostart.
# ==============================================================================

CURRENT_THEME="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo "")"
[[ "$CURRENT_THEME" != "virtual-paradise" ]] && exit 0

command -v quickshell &>/dev/null || exit 0

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

# FileView only watches paths that exist when the shell starts: create the
# trigger file up front (empty), so the very first death is seen.
: > "$RUNTIME_DIR/vp_death_trigger"

# One daemon per session. Check the pidfile's process directly: pgrep -f
# would also match any shell whose command line happens to mention the qml
# file, and the daemon would refuse to start.
PIDFILE="$RUNTIME_DIR/vp_death_daemon.pid"
if [[ -f "$PIDFILE" ]]; then
  OLD_PID="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null \
    && grep -qa 'vp_death_daemon\.qml' "/proc/$OLD_PID/cmdline" 2>/dev/null; then
    exit 0
  fi
fi

# The death script finds the daemon through this pidfile instead of running
# pgrep on every close: exec keeps the PID, so the pid stays valid for the
# whole session.
echo $$ > "$PIDFILE"

exec quickshell -p "${VP_DEATH_DAEMON_QML:-$HOME/.local/bin/vp_death_daemon.qml}"
