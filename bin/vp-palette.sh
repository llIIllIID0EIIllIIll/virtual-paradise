#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — live palette writer
# ==============================================================================
#  Usage:
#    vp-palette.sh accent secondary tertiary warm pink hot background foreground
#
#  Writes palette.json atomically and marks the variant custom. The island bar
#  watches the file, so its widgets recolor on the next frame without a shell
#  restart. theme-switcher.sh is still the debounced path that rewrites the
#  theme text files and terminal/GTK configs.
# ==============================================================================

set -euo pipefail

[[ $# -eq 8 ]] || {
  echo "Usage: vp-palette.sh accent secondary tertiary warm pink hot background foreground" >&2
  exit 2
}

state="${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise"
mkdir -p "$state"

python3 - "$state" "$@" <<'PY'
import fcntl
import json
import os
import sys
import tempfile

state, accent, secondary, tertiary, warm, pink, hot, background, foreground = sys.argv[1:10]
names = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
values = (accent, secondary, tertiary, warm, pink, hot, background, foreground)

for name, value in zip(names, values):
    if len(value) != 6 or any(c not in "0123456789abcdefABCDEF" for c in value):
        print(f"vp-palette: invalid {name}: {value}", file=sys.stderr)
        sys.exit(2)

palette = {"name": "custom"}
for name, value in zip(names, values):
    palette[name] = "#" + value
payload = json.dumps(palette, indent=2, ensure_ascii=False) + "\n"
target = os.path.join(state, "palette.json")

lock_path = os.path.join(state, "palette.lock")
with open(lock_path, "a+", encoding="utf-8") as lock:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    fd, tmp = tempfile.mkstemp(prefix=".palette.", suffix=".tmp", dir=state)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, target)
        # A rename replaces the inode; Quickshell's FileView watches the one it
        # opened and would miss it. Rewriting the same bytes in place (same
        # length, no truncate) emits the inotify modify the bar listens for.
        with open(target, "r+", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        with open(os.path.join(state, "current_variant"), "w", encoding="utf-8") as handle:
            handle.write("custom\n")
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
PY
