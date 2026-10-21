#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Session Splash
# ==============================================================================
#  Covers the gap between the greeter handing the screen to the session and
#  the desktop having something to show.
#
#  It is the same glitch curtain the live wallpaper switch uses, over the
#  theme's cyber artwork, and it waits for the shell to answer before it
#  opens - so the whole way from the firmware to the desktop is one picture
#  instead of a black screen.
# ==============================================================================

set -uo pipefail

QML="$HOME/.local/bin/glitch_transition.qml"
BASE="$HOME/.local/bin/session_base.png"

[[ -f $QML ]] || exit 0
command -v quickshell &>/dev/null || exit 0

export VP_TRANSITION_IMAGE="session_base.png"
export VP_TRANSITION_WAIT_SHELL="1"
export VP_TRANSITION_TIMEOUT="20000"
# The full "TV with a bad antenna" look: the picture crawls, the lines roll
# and the whole frame jumps around.
export VP_TRANSITION_NOISE="1.0"
export WALLPAPER_TARGET="SESSION"

[[ -f $BASE ]] || export VP_TRANSITION_IMAGE="Glitch.jpg"

exec quickshell -p "$QML"
