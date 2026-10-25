#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Window Death
# ==============================================================================
#  Close the active window the way it deserves: the border burns neon red,
#  the window is captured frame and all, and a glitch burst tears that
#  capture apart - slices jumping, red static burning through - exactly
#  where the window was. The window closes *under* the burst, so what the
#  eye sees is the window shaking itself to death, border included.
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

read -r X Y W H <<< "$(printf '%s' "$WIN" \
  | python3 -c 'import json,sys; w=json.load(sys.stdin); print(w["at"][0], w["at"][1], w["size"][0], w["size"][1])' 2>/dev/null)"
if [[ -z "${W:-}" ]]; then
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
FRAME="${XDG_RUNTIME_DIR:-/tmp}/vp_death_frame.png"
rm -f "$FRAME"
sleep 0.09
if command -v grim &>/dev/null; then
  grim -g "$X,$Y ${W}x${H}" "$FRAME" &>/dev/null || FRAME=""
else
  FRAME=""
fi

QML="${VP_DEATH_QML:-$HOME/.local/bin/window_death.qml}"
[[ -f "$QML" ]] || exit 0

# 3. The burst appears in one frame over the captured rectangle: the
#    compositor's layer animation is disabled for its namespace, so nothing
#    slides, nothing fades in - the glitch is simply suddenly there.
VP_DEATH_RECT="$X,$Y,$W,$H" VP_DEATH_IMAGE="$FRAME" \
  quickshell -p "$QML" &>/dev/null &

# 4. Wait for the burst surface to map, then close the window under it.
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
