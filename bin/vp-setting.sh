#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — safe shell.json setting writer
# ==============================================================================
#  Usage:
#    vp-setting.sh get bar.gapEffects
#    vp-setting.sh set bar.gapEffects false
#    vp-setting.sh set bar.hoverGlow true
#    vp-setting.sh set bar.reducedMotion true
#    vp-setting.sh set bar.liveTerminals false
#    vp-setting.sh set weather.autoLocation true
#
#  The QML settings panel and scripts use this instead of writing shell.json
#  directly. The write is serialised with flock and replaced atomically, so a
#  shell reload can never see a truncated file.
# ==============================================================================

set -euo pipefail

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

key="${2:-}"
value="${3:-}"
case "${1:-}" in
  get)
    [[ -n $key ]] || { usage >&2; exit 2; }
    ;;
  set)
    [[ -n $key && -n $value ]] || { usage >&2; exit 2; }
    ;;
  -h | --help | "")
    usage
    exit 2
    ;;
  *)
    echo "vp-setting: unknown command: $1" >&2
    usage >&2
    exit 2
    ;;
esac

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
[[ -f $cfg ]] || {
  echo "vp-setting: $cfg not found" >&2
  exit 1
}

state="${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise"
mkdir -p "$state" 2>/dev/null || true

python3 - "$cfg" "${1}" "$key" "$value" "$state/shell-config.lock" <<'PY'
import fcntl
import json
import os
import sys
import tempfile

path, mode, key, value, lock_path = sys.argv[1:6]

BAR_KEYS = ("bar.gapEffects", "bar.hoverGlow", "bar.reducedMotion", "bar.liveTerminals")
WEATHER_KEY = "weather.autoLocation"


def fail(message):
    print(f"vp-setting: {message}", file=sys.stderr)
    sys.exit(1)


def read_config():
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception as exc:
        fail(f"cannot read {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"{path} is not a JSON object")
    return data


def weather_entry(data):
    layout = (data.get("bar") or {}).get("layout") or {}
    for section in ("left", "center", "right"):
        entries = layout.get(section)
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if isinstance(entry, dict) and str(entry.get("id", "")).endswith(".weather"):
                return entry
    return None


def current(data):
    if key in BAR_KEYS:
        return (data.get("bar") or {}).get(key.split(".", 1)[1])
    if key == WEATHER_KEY:
        entry = weather_entry(data)
        return entry.get("autoLocation") if entry else None
    fail(f"unsupported key: {key}")


def write(data):
    directory = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=".shell.json.", suffix=".tmp", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


with open(lock_path, "a+", encoding="utf-8") as lock:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    data = read_config()

    if mode == "get":
        value_now = current(data)
        if value_now is None:
            sys.exit(3)
        print("true" if value_now is True else "false")
        sys.exit(0)

    if value not in ("true", "false"):
        fail(f"value must be true or false, got {value!r}")
    wanted = value == "true"

    if key in BAR_KEYS:
        bar = data.setdefault("bar", {})
        if not isinstance(bar, dict):
            fail("bar is not a JSON object")
        bar[key.split(".", 1)[1]] = wanted
    elif key == WEATHER_KEY:
        entry = weather_entry(data)
        if entry is None:
            fail("no weather entry in shell.json")
        entry["autoLocation"] = wanted
    else:
        fail(f"unsupported key: {key}")

    write(data)
    print(f"{key}={'true' if wanted else 'false'}")
PY

# Atomic replace changes the inode, so the shell's FileView may not see it.
# Ask the host to reload its config; harmless when the shell is not running.
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell reloadConfig >/dev/null 2>&1 || true
fi
