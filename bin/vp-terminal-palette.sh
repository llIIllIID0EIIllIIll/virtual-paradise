#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — live terminal palette
# ==============================================================================
#  Usage:
#    vp-terminal-palette.sh [--dry-run | --list]
#
#  Reads palette.json and writes OSC 4 (ANSI colors), OSC 10 (foreground),
#  OSC 11 (background) and OSC 12 (cursor) to every writable pseudo-terminal
#  owned by the user. Terminals that do not support OSC simply ignore it.
#  --dry-run prints the escape stream (escaped for logs); --list prints the
#  terminals that would be touched.
# ==============================================================================

set -euo pipefail

mode="apply"
case "${1:-}" in
  --dry-run) mode="dry" ;;
  --list) mode="list" ;;
  "") ;;
  *)
    echo "Usage: vp-terminal-palette.sh [--dry-run | --list]" >&2
    exit 2
    ;;
esac

state="$HOME/.local/state/virtual-paradise"
palette="$state/palette.json"
mkdir -p "$state"
: >>"$state/palette.lock"
[[ -f $palette ]] || {
  echo "No live palette at $palette" >&2
  exit 1
}

flock -s "$state/palette.lock" python3 - "$palette" "$mode" <<'PY'
import glob
import json
import os
import sys

palette_path, mode = sys.argv[1:3]
roles = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
data = json.load(open(palette_path, encoding="utf-8"))


def valid(value):
    return isinstance(value, str) and len(value) == 7 and value[0] == "#" and all(
        c in "0123456789abcdefABCDEF" for c in value[1:])


colors = {}
for role in roles:
    if not valid(data.get(role)):
        raise SystemExit(f"palette.json has no valid {role}")
    colors[role] = data[role].lower()


def mix(a, b, amount):
    ar, ag, ab = (int(a[i:i + 2], 16) for i in (1, 3, 5))
    br, bg, bb = (int(b[i:i + 2], 16) for i in (1, 3, 5))
    return "#" + "".join(f"{round(x + (y - x) * amount):02x}"
                         for x, y in ((ar, br), (ag, bg), (ab, bb)))


ansi = [
    colors["background"],
    colors["hot"],
    colors["tertiary"],
    colors["warm"],
    colors["accent"],
    colors["pink"],
    colors["accent"],
    colors["foreground"],
    mix(colors["background"], colors["foreground"], 0.5),
    colors["hot"],
    colors["tertiary"],
    colors["warm"],
    colors["accent"],
    colors["pink"],
    colors["accent"],
    colors["foreground"],
]

stream = "".join(f"\033]4;{index};{color}\a" for index, color in enumerate(ansi))
stream += f"\033]10;{colors['foreground']}\a"
stream += f"\033]11;{colors['background']}\a"
stream += f"\033]12;{colors['accent']}\a"

terminals = []
for path in sorted(glob.glob("/dev/pts/[0-9]*")):
    if os.path.isdir(path):
        continue
    try:
        if not os.access(path, os.W_OK):
            continue
    except OSError:
        continue
    terminals.append(path)

if mode == "dry":
    print(stream.encode("unicode_escape").decode("ascii"))
elif mode == "list":
    for path in terminals:
        print(path)
else:
    applied = 0
    payload = stream.encode("ascii")
    for path in terminals:
        try:
            fd = os.open(path, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
        except OSError:
            continue
        try:
            os.write(fd, payload)
            applied += 1
        except OSError:
            pass
        finally:
            os.close(fd)
    print(f"Applied live palette to {applied} terminal(s).")
PY
