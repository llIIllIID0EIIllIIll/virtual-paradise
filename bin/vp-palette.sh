#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — live palette writer
# ==============================================================================
#  Usage:
#    vp-palette.sh [--seq N] accent secondary tertiary warm pink hot background foreground
#
#  Writes palette.json atomically and marks the variant custom. The island bar
#  polls the file, so its widgets recolor on the next tick without a shell
#  restart. theme-switcher.sh is still the debounced path that rewrites the
#  theme text files and terminal/GTK configs.
# ==============================================================================

set -euo pipefail

seq=""
if [[ ${1:-} == --seq ]]; then
  seq="${2:-}"
  [[ $seq =~ ^[0-9]+$ ]] || {
    echo "--seq needs a number." >&2
    exit 2
  }
  shift 2
fi

[[ $# -eq 8 ]] || {
  echo "Usage: vp-palette.sh [--seq N] accent secondary tertiary warm pink hot background foreground" >&2
  exit 2
}

# Keep the same location as theme-switcher.sh and the QML readers. XDG_STATE_HOME
# is intentionally not consulted here: the rest of the theme uses HOME, and a
# split location would make the bar watch a different palette than this writes.
state="$HOME/.local/state/virtual-paradise"
mkdir -p "$state"

python3 - "$state" "$seq" "$@" <<'PY'
import fcntl
import json
import os
import sys
import tempfile

state, seq, accent, secondary, tertiary, warm, pink, hot, background, foreground = sys.argv[1:11]
seq = int(seq) if seq else None
names = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
values = (accent, secondary, tertiary, warm, pink, hot, background, foreground)

for name, value in zip(names, values):
    if len(value) != 6 or any(c not in "0123456789abcdefABCDEF" for c in value):
        print(f"vp-palette: invalid {name}: {value}", file=sys.stderr)
        sys.exit(2)

palette = {"name": "custom"}
if seq is not None:
    palette["sequence"] = seq
for name, value in zip(names, values):
    palette[name] = "#" + value
payload = json.dumps(palette, indent=2, ensure_ascii=False) + "\n"
target = os.path.join(state, "palette.json")

lock_path = os.path.join(state, "palette.lock")
with open(lock_path, "a+", encoding="utf-8") as lock:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    try:
        with open(target, "r", encoding="utf-8") as handle:
            existing_raw = handle.read()
        unchanged = existing_raw == payload
        existing = json.loads(existing_raw)
        existing_seq = existing.get("sequence") if isinstance(existing, dict) else None
        if seq is not None and isinstance(existing_seq, int) and existing_seq > seq:
            # A newer click already reached the file; this older process lost
            # the race and must not paint over it.
            unchanged = True
    except (OSError, ValueError):
        unchanged = False

    fd, tmp = tempfile.mkstemp(prefix=".palette.", suffix=".tmp", dir=state)
    try:
        if not unchanged:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(tmp, target)
            # A rename replaces the inode; Quickshell's FileView watches the one
            # it opened and would miss it. Rewriting the same bytes in place
            # (same length, no truncate) emits the modify event the bar needs.
            with open(target, "r+", encoding="utf-8") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
        else:
            os.close(fd)
            os.unlink(tmp)
        variant = os.path.join(state, "current_variant")
        try:
            with open(variant, "r", encoding="utf-8") as handle:
                variant_unchanged = handle.read() == "custom\n"
        except OSError:
            variant_unchanged = False
        if not variant_unchanged:
            with open(variant, "w", encoding="utf-8") as handle:
                handle.write("custom\n")
                handle.flush()
                os.fsync(handle.fileno())
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
PY
