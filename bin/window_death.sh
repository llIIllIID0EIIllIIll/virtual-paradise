#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Window Death
# ==============================================================================
#  Close the active window the way it deserves, faster than the close itself.
#
#  The glitch leads, the close follows. The resident daemon keeps its burst
#  surfaces mapped, so announcing the death puts the red static on screen in
#  a couple of frames - while the window is still alive. Only then is the
#  window captured, torn into slices and closed underneath the burst.
#
#  The capture is a foreign-toplevel grab (grim -T): it takes the window's
#  own surface tree, so the burst overlay already covering it does not end
#  up inside the corpse. JPEG at quality 70 keeps the grab at ~20 ms - PNG
#  encoding cost another 50 ms, and the burst tears the frame apart anyway.
#
#  Two trigger payloads, two beats:
#    "x,y,w,h /path/to/pending"  -> the glitch takes the live window
#    "x,y,w,h /path/to/frame"    -> the captured corpse snaps into it
#
#  Without the daemon (fresh session, not yet autostarted) the script falls
#  back to a one-shot burst: capture the screen region, spawn the overlay,
#  close at once. The burst then trails the close by its startup time,
#  which is exactly why the daemon exists.
# ==============================================================================

set -euo pipefail

command -v hyprctl &>/dev/null || exit 0

# One IPC for everything: address, geometry and the foreign-toplevel id.
# jq is ~20 ms faster than python here and this is the latency budget.
if command -v jq &>/dev/null; then
  read -r ADDR X Y W H SID <<< "$(hyprctl activewindow -j 2>/dev/null \
    | jq -r '[.address // "", .at[0], .at[1], .size[0], .size[1], (.stableId // "")] | @tsv' 2>/dev/null)" || true
else
  read -r ADDR X Y W H SID <<< "$(hyprctl activewindow -j 2>/dev/null \
    | python3 -c 'import json,sys
w = json.load(sys.stdin)
print(w.get("address") or "", w["at"][0], w["at"][1], w["size"][0], w["size"][1], w.get("stableId") or "", sep="\t")' 2>/dev/null)" || true
fi
if [[ -z "${ADDR:-}" || "$ADDR" == "0x0" || -z "${W:-}" || "${W:-0}" -le 0 ]]; then
  exit 0
fi

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
# The daemon may still be showing the previous corpse: only reap old frames.
find "$RUNTIME_DIR" -maxdepth 1 -name 'vp_death_frame.*' -mmin +2 -delete 2>/dev/null || true

NS="$(date +%s%N)"
FRAME="$RUNTIME_DIR/vp_death_frame.$NS.jpg"
PENDING="$RUNTIME_DIR/vp_death_frame.pending.$NS.jpg"
QML="${VP_DEATH_QML:-$HOME/.local/bin/window_death.qml}"

# The daemon is found through its pidfile - a process search matches any
# shell whose command line mentions the qml file, and spawning one costs
# ~30 ms per close.
DAEMON_PID="$(cat "$RUNTIME_DIR/vp_death_daemon.pid" 2>/dev/null || true)"
if [[ -n "$DAEMON_PID" ]] && kill -0 "$DAEMON_PID" 2>/dev/null \
  && grep -qa 'vp_death_daemon\.qml' "/proc/$DAEMON_PID/cmdline" 2>/dev/null; then

  # 1. The glitch first: the burst surfaces are already mapped, so this
  #    lands on screen in a couple of frames, before the close.
  printf '%s %s\n' "$X,$Y,$W,$H" "$PENDING" > "$RUNTIME_DIR/vp_death_trigger"

  # 2. One frame of head start, then grab the window itself. grim -T takes
  #    the toplevel's surface tree, so the burst is not in the shot.
  sleep 0.016
  if [[ -n "$SID" ]] && command -v grim &>/dev/null; then
    grim -T "$SID" -t jpeg -q 70 "$FRAME" &>/dev/null || FRAME=""
  else
    FRAME=""
  fi

  # 3. Snap the corpse into the burst (a different payload re-fires the
  #    watcher), then close underneath it. The window's pop-out animation
  #    plays behind the glitch, never before it.
  if [[ -n "$FRAME" ]]; then
    printf '%s %s\n' "$X,$Y,$W,$H" "$FRAME" > "$RUNTIME_DIR/vp_death_trigger"
  fi
  hyprctl dispatch "hl.dsp.window.close(\"address:$ADDR\")" &>/dev/null || true
  exit 0
fi

# ---------------------------------------------------------------------------
#  Fallback: no resident daemon. Burn the border red, grab the padded
#  region (border and shadow included), spawn the one-shot overlay and
#  close at once.
# ---------------------------------------------------------------------------
hyprctl eval "
  local d1 = hl.dsp.window.set_prop({ window = 'address:$ADDR', prop = 'active_border_color', value = 'rgba(ff0055ff) rgba(ff1744ff) rgba(ff003cff) 45deg' })
  local d2 = hl.dsp.window.set_prop({ window = 'address:$ADDR', prop = 'inactive_border_color', value = 'rgba(ff0055bb) rgba(ff174499) 45deg' })
  hl.dispatch(d1)
  hl.dispatch(d2)
" &>/dev/null || true

X=$((X - 12)); Y=$((Y - 12)); W=$((W + 24)); H=$((H + 24))
sleep 0.016
if command -v grim &>/dev/null; then
  grim -g "$X,$Y ${W}x${H}" -t jpeg -q 70 "$FRAME" &>/dev/null || FRAME=""
else
  FRAME=""
fi

if [[ -f "$QML" ]] && command -v quickshell &>/dev/null; then
  VP_DEATH_RECT="$X,$Y,$W,$H" VP_DEATH_IMAGE="$FRAME" \
    quickshell -p "$QML" &>/dev/null &
fi

# Hyprland 0.56 parses `hyprctl dispatch` arguments as Lua, so the plain
# `closewindow address:0x...` form is a syntax error there and the window
# silently survives. The dispatcher object is the supported spelling.
hyprctl dispatch "hl.dsp.window.close(\"address:$ADDR\")" &>/dev/null || true
