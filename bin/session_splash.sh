#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Session Splash
# ==============================================================================
#  Shows the theme's cyber artwork from the moment the compositor is up until
#  the shell has something to draw.
#
#  The greeter hands the screen to the session and the session needs a couple
#  of seconds before the desktop appears. Without this, that gap is a black
#  screen; with it, the boot splash and the login screen are one continuous
#  picture.
# ==============================================================================

set -uo pipefail

QML="$HOME/.local/bin/session_splash.qml"

[[ -f $QML ]] || exit 0
command -v quickshell &>/dev/null || exit 0

exec quickshell -p "$QML"
