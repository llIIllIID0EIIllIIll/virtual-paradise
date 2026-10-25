#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Window Death
# ==============================================================================
#  Close the active window the way it deserves, without making the close
#  feel slow: the border burns neon red, the window is captured frame and
#  all, and the window closes right after the capture - about a tenth of a
#  second after the keypress, as close to instant as a death rite gets.
#  The glitch burst rises over the rectangle a beat later as the window's
#  afterimage, tearing the captured frame apart. The script never waits for
#  the burst: a burst that is late must not make the close late.
# ==============================================================================

set -euo pipefail

command -v quickshell &>/dev/null || exit 0
command -v hyprctl &>/dev/null || exit 0

# One parse for everything: address and geometry in a single python.
read -r ADDR X Y W H <<< "$(hyprctl activewindow -j 2>/dev/null \
  | python3 -c 'import json,sys
w = json.load(sys.stdin)
print(w.get("address") or "", w["at"][0], w["at"][1], w["size"][0], w["size"][1])' 2>/dev/null)" || exit 0
if [[ -z "${ADDR:-}" || "$ADDR" == "0x0" || -z "${W:-}" ]]; then
  exit 0
fi

# Widen the rectangle past the border and into the shadow, so the captured
# frame - and the burst that tears it - carries the window's whole edge.
X=$((X - 12))
Y=$((Y - 12))
W=$((W + 24))
H=$((H + 24))

# 1. The window burns red while it is still alive.
hyprctl eval "
  local d1 = hl.dsp.window.set_prop({ window = 'address:$ADDR', prop = 'active_border_color', value = 'rgba(ff0055ff) rgba(ff1744ff) rgba(ff003cff) 45deg' })
  local d2 = hl.dsp.window.set_prop({ window = 'address:$ADDR', prop = 'inactive_border_color', value = 'rgba(ff0055bb) rgba(ff174499) 45deg' })
  hl.dispatch(d1)
  hl.dispatch(d2)
" &>/dev/null || true

# 2. Capture the red window, border included. The burst tears this frame.
#    Three frames of grace so the red border is on screen before the shot.
FRAME="${XDG_RUNTIME_DIR:-/tmp}/vp_death_frame.png"
sleep 0.03
if command -v grim &>/dev/null; then
  grim -g "$X,$Y ${W}x${H}" "$FRAME" &>/dev/null || FRAME=""
else
  FRAME=""
fi

QML="${VP_DEATH_QML:-$HOME/.local/bin/window_death.qml}"
if [[ -f "$QML" ]]; then
  # 3. The burst rises on its own; the compositor's layer animation is off
  #    for its namespace, so it appears in one frame when it arrives.
  VP_DEATH_RECT="$X,$Y,$W,$H" VP_DEATH_IMAGE="$FRAME" \
    quickshell -p "$QML" &>/dev/null &
fi

# 4. Close at once. The burst is an afterimage, not a gate: waiting for its
#    surface to map added a third of a second to every close and made the
#    desktop feel laggy. A late burst must never make a late close.
#
# Hyprland 0.56 parses `hyprctl dispatch` arguments as Lua, so the plain
# `closewindow address:0x...` form is a syntax error there and the window
# silently survives. The dispatcher object is the supported spelling.
hyprctl dispatch "hl.dsp.window.close(\"address:$ADDR\")" &>/dev/null || true
