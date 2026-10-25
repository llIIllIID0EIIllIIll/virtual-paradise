#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Window Death
# ==============================================================================
#  Close the active window with a red glitch burst in its place: the burst
#  overlay is raised over the window's rectangle first, then the window is
#  closed, so what the eye sees is the window dying on screen rather than
#  vanishing between frames.
# ==============================================================================

set -euo pipefail

command -v quickshell &>/dev/null || exit 0
command -v hyprctl &>/dev/null || exit 0

WIN="$(hyprctl activewindow -j 2>/dev/null)" || exit 0

ADDR="$(printf '%s' "$WIN" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("address") or "")' 2>/dev/null)"
if [[ -z "$ADDR" || "$ADDR" == "0x0" ]]; then
  exit 0
fi

RECT="$(printf '%s' "$WIN" \
  | python3 -c 'import json,sys; w=json.load(sys.stdin); x,y=w["at"]; sw,sh=w["size"]; print(x,y,sw,sh,sep=",")' 2>/dev/null)"
if [[ -z "$RECT" ]]; then
  exit 0
fi

QML="${VP_DEATH_QML:-$HOME/.local/bin/window_death.qml}"
[[ -f "$QML" ]] || exit 0

VP_DEATH_RECT="$RECT" quickshell -p "$QML" &>/dev/null &

# The burst needs a moment to map its surface. Wait for it to actually
# appear in the layer tree before closing the window, so the window dies
# *under* the burst instead of leaving a gap of plain desktop first.
for _ in $(seq 1 20); do
  if hyprctl layers 2>/dev/null | grep -q "vp-window-death"; then
    break
  fi
  sleep 0.05
done
sleep 0.05

# Hyprland 0.56 parses `hyprctl dispatch` arguments as Lua, so the plain
# `closewindow address:0x...` form is a syntax error there and the window
# silently survives. The dispatcher object is the supported spelling.
hyprctl dispatch "hl.dsp.window.close(\"address:$ADDR\")" &>/dev/null || true
