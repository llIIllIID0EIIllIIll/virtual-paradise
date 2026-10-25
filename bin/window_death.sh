#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Window Death
# ==============================================================================
#  Close the active window the way it deserves, at full speed: the border
#  burns neon red, the window is captured frame and all, the death is
#  announced to the resident daemon, and the window closes in the same
#  breath. The daemon maps the burst in a single frame - burst and close
#  land together, no afterimage, no waiting.
#
#  Measured: ~150 ms from keypress to the close dispatch, the burst on
#  screen within a frame of that. Without the daemon (fresh session, not
#  yet autostarted) the script falls back to spawning the burst itself,
#  which trails the close by its startup time.
# ==============================================================================

set -euo pipefail

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
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
FRAME="$RUNTIME_DIR/vp_death_frame.$(date +%s%N).png"
rm -f "$RUNTIME_DIR"/vp_death_frame.*.png 2>/dev/null || true
sleep 0.03
if command -v grim &>/dev/null; then
  grim -g "$X,$Y ${W}x${H}" "$FRAME" &>/dev/null || FRAME=""
else
  FRAME=""
fi

# 3. Announce the death. The resident daemon maps the burst within a frame
#    of this write; without it, spawn the burst ourselves as a fallback.
QML="${VP_DEATH_QML:-$HOME/.local/bin/window_death.qml}"
if pgrep -f "[v]p_death_daemon\.qml" &>/dev/null; then
  printf '%s %s\n' "$X,$Y,$W,$H" "$FRAME" > "$RUNTIME_DIR/vp_death_trigger"
elif [[ -f "$QML" ]] && command -v quickshell &>/dev/null; then
  VP_DEATH_RECT="$X,$Y,$W,$H" VP_DEATH_IMAGE="$FRAME" \
    quickshell -p "$QML" &>/dev/null &
fi

# 4. Close in the same breath as the announcement.
#
# Hyprland 0.56 parses `hyprctl dispatch` arguments as Lua, so the plain
# `closewindow address:0x...` form is a syntax error there and the window
# silently survives. The dispatcher object is the supported spelling.
hyprctl dispatch "hl.dsp.window.close(\"address:$ADDR\")" &>/dev/null || true
