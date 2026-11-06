#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Transition, Then Act
# ==============================================================================
#  Plays the same glitch curtain the wallpaper switch uses and then runs an
#  action, so the handover to Plymouth (reboot, shutdown) or to the greeter
#  (logout) starts with the transition instead of a hard cut.
#
#    transition.sh logout
#    transition.sh reboot
#    transition.sh shutdown
# ==============================================================================

set -uo pipefail

ACTION="${1:-}"
QML="$HOME/.local/bin/glitch_transition.qml"
READY="${XDG_RUNTIME_DIR:-/tmp}/virtual_paradise_wallpaper_ready"
HOLD="${VP_TRANSITION_HOLD:-1.2}"

case "$ACTION" in
  logout|reboot|shutdown) ;;
  *)
    printf 'Usage: %s <logout|reboot|shutdown>\n' "$0" >&2
    exit 2
    ;;
esac

# Omarchy 4.5 folded the old omarchy-system-* binaries into
# `omarchy system <logout|reboot|shutdown>`.
command -v omarchy &>/dev/null || {
  printf 'transition: omarchy is not available\n' >&2
  exit 1
}

if [[ -f $QML ]] && command -v quickshell &>/dev/null; then
  rm -f "$READY"
  export VP_WALLPAPER_READY_FILE="$READY"
  export WALLPAPER_TARGET="${ACTION^^} SEQUENCE"
  setsid -f quickshell -p "$QML" >/dev/null 2>&1

  # Let the curtain play before the screen changes hands.
  sleep "$HOLD"
  touch "$READY" 2>/dev/null || true
  sleep 0.4
else
  printf 'transition: the curtain is not available, continuing without it\n' >&2
fi

exec omarchy system "$ACTION"
