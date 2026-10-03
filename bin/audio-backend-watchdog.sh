#!/usr/bin/env bash
# Restart the ssupt.audio-control backend if it stops answering.
#
# The panel cannot recover from a wedged daemon on its own. The relay probes the
# socket only at startup (connect_ready), so once the daemon accepts a connection
# but stops replying, every later panel load reconnects to the same dead socket
# and reports "Audio service is unavailable" until the daemon is killed.
#
# Healthy path is a single short round-trip. Only a failed probe kills anything.
#
# Exit: 0 healthy (or nothing to check) and 0 after a successful reset; 2 when
# the probe failed but there was no daemon to kill. A reset is a successful run,
# so it must not exit non-zero and leave the unit shown as failed in
# `systemctl --user status`; the journal records what happened.

set -uo pipefail

PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/ssupt.audio-control"
BIN_REL="bin/omarchy-audio-service"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SOCKET_DIR="$RUNTIME_DIR/omarchy-audio-control"
PROBE_TIMEOUT="${AUDIO_WATCHDOG_TIMEOUT:-5}"

command -v python3 >/dev/null 2>&1 || exit 0
[[ -x $PLUGIN_DIR/$BIN_REL ]] || exit 0

shopt -s nullglob
sockets=("$SOCKET_DIR"/backend-*.sock)
shopt -u nullglob
(( ${#sockets[@]} )) || exit 0

# Probe every socket; all must answer. Prints one line per socket.
probe() {
  python3 - "$@" <<'PY'
import json, socket, sys

timeout = float(sys.argv[1])
for path in sys.argv[2:]:
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(path)
        f = s.makefile("rwb")
        f.write(b'{"version":1,"id":"watchdog","method":"hello","params":{}}\n')
        f.flush()
        line = f.readline()
        if not line:
            print(f"{path}\tno-reply")
            continue
        reply = json.loads(line)
        print(f"{path}\t{'ok' if reply.get('result') else 'bad-reply'}")
    except Exception as exc:
        print(f"{path}\t{type(exc).__name__}")
PY
}

report="$(probe "$PROBE_TIMEOUT" "${sockets[@]}")"
bad=0
while IFS=$'\t' read -r path state; do
  [[ -n ${path:-} ]] || continue
  if [[ $state == "ok" ]]; then
    continue
  fi
  bad=1
  printf 'watchdog: %s -> %s\n' "$(basename "$path")" "$state" >&2
done <<<"$report"

(( bad )) || exit 0

# A wedged daemon holds the lock and the socket. Kill by exact binary path and
# the --plugin-daemon argument so no other process can match, then clear the
# stale socket so the next relay start binds a fresh one. Quickshell respawns
# the daemon; do not start it here, it needs the panel's stdio relay.
mapfile -t pids < <(pgrep -f "^$PLUGIN_DIR/$BIN_REL --plugin-daemon$" || true)

if (( ${#pids[@]} == 0 )); then
  printf 'watchdog: socket unresponsive but no daemon process found; removing stale socket\n' >&2
  rm -f "${sockets[@]}"
  exit 2
fi

printf 'watchdog: killing wedged daemon pid(s): %s\n' "${pids[*]}" >&2
kill "${pids[@]}" 2>/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleep 0.5
  still=0
  for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && still=1; done
  (( still )) || break
done
for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null; done

rm -f "${sockets[@]}"
printf 'watchdog: backend reset; the shell will respawn it on the next panel load\n' >&2
exit 0