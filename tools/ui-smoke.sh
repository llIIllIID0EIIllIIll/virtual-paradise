#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — manual settings UI smoke test
# ==============================================================================
#  Usage:
#    tools/ui-smoke.sh [--screenshots DIR] [--baseline DIR] [--baseline-auto DIR]
#                      [--crop WxH+X+Y] [--threshold N]
#
#  Drives the live settings panel through its IPC surface: open Settings, set a
#  role, generate a harmony, then assert undo/redo/reset using palette.json.
#  The original palette and variant are restored on exit.
#
#  --screenshots DIR saves 01/02/03 captures. --baseline DIR compares against a
#  saved set the first time it is empty, then diffs later runs through
#  tools/ui-diff.sh. --crop excludes the live bar clock.
# ==============================================================================

set -euo pipefail

state="$HOME/.local/state/virtual-paradise"
palette="$state/palette.json"
variant_file="$state/current_variant"

screens=""
baseline_dir=""
baseline_auto=""
crop=""
threshold=1000
while [[ $# -gt 0 ]]; do
  case "$1" in
    --screenshots) screens="${2:-}"; shift 2 ;;
    --baseline) baseline_dir="${2:-}"; shift 2 ;;
    --baseline-auto) baseline_auto="${2:-}"; shift 2 ;;
    --crop) crop="${2:-}"; shift 2 ;;
    --threshold) threshold="${2:-}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

# grim wants "x,y WxH"; accept the ImageMagick "WxH+X+Y" form too.
crop_grim="$crop"
if [[ $crop =~ ^([0-9]+),([0-9]+)[[:space:]]+([0-9]+)x([0-9]+)$ ]]; then
  crop_grim="$crop"
elif [[ $crop =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]; then
  crop_grim="${BASH_REMATCH[3]},${BASH_REMATCH[4]} ${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
fi

if [[ -n $baseline_auto ]]; then
  command -v hyprctl >/dev/null 2>&1 || {
    echo "--baseline-auto needs hyprctl (run inside Hyprland)." >&2
    exit 2
  }
  monitor_name="$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    monitors = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
if not monitors:
    raise SystemExit(1)
monitor = next((m for m in monitors if m.get("focused")), monitors[0])
scale = ("%.2f" % float(monitor.get("scale", 1))).rstrip("0").rstrip(".")
print(str(monitor.get("width", 0)) + "x" + str(monitor.get("height", 0)) + "-scale" + scale)
')" || {
    echo "Could not detect the focused monitor geometry." >&2
    exit 2
  }
  baseline_dir="$baseline_auto/$monitor_name"
fi

if [[ -n $baseline_dir ]]; then
  mkdir -p "$baseline_dir"
  if compgen -G "$baseline_dir/*.png" >/dev/null; then
    screens="$(mktemp -d)"
    compare_dir="$screens"
  else
    screens="$baseline_dir"
    save_baseline=1
  fi
fi
[[ -z $screens ]] || mkdir -p "$screens"

for cmd in omarchy-shell python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing command: $cmd (run this inside Omarchy)." >&2
    exit 2
  }
done
[[ -f $palette ]] || {
  echo "No live palette at $palette; install/apply the theme first." >&2
  exit 2
}

snapshot="$(mktemp)"
cp "$palette" "$snapshot"
baseline_variant="$(cat "$variant_file" 2>/dev/null || echo cyberpunk)"

role() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$palette" "$1"
}

capture() {
  local name="$1"
  [[ -n $screens ]] || return 0
  command -v grim >/dev/null 2>&1 || return 0
  if [[ -n $crop_grim ]]; then
    grim -g "$crop_grim" "$screens/$name" 2>/dev/null || true
  else
    grim "$screens/$name" 2>/dev/null || true
  fi
}

restore_palette() {
  if [[ $baseline_variant == custom ]]; then
    local -a colors=()
    while IFS= read -r value; do colors+=("$value"); done < <(python3 - "$snapshot" <<'PY'
import json, sys
roles = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
data = json.load(open(sys.argv[1], encoding="utf-8"))
for role in roles:
    print(data[role].lstrip("#"))
PY
)
    if [[ ${#colors[@]} -eq 8 ]]; then
      VP_NO_THEME_REFRESH=1 "$HOME/.local/bin/theme-switcher.sh" custom "${colors[@]}" >/dev/null 2>&1 || true
    fi
  else
    "$HOME/.local/bin/theme-switcher.sh" "$baseline_variant" >/dev/null 2>&1 || true
  fi
  rm -f "$snapshot"
}

cleanup() {
  omarchy-shell doe.tools close >/dev/null 2>&1 || true
  sleep 0.6
  restore_palette
  [[ -n ${compare_dir:-} ]] && rm -rf "$compare_dir"
}
trap cleanup EXIT INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

wait_role() {
  local expected="$1" label="$2" role_name="$3"
  for _ in $(seq 1 30); do
    [[ "$(role "$role_name")" == "$expected" ]] && return 0
    sleep 0.2
  done
  fail "$label: expected $expected, got $(role "$role_name")"
}

base_accent="$(role accent)"
base_secondary="$(role secondary)"
base_tertiary="$(role tertiary)"

omarchy-shell doe.tools settings >/dev/null 2>&1 || fail "could not open Settings"
sleep 0.9
capture 01-settings.png

omarchy-shell doe.tools setRole accent "#123456" >/dev/null 2>&1 || fail "setRole IPC failed"
sleep 1.0
wait_role "#123456" "setRole accent" accent

omarchy-shell doe.tools generateTheme triad >/dev/null 2>&1 || fail "generateTheme IPC failed"
sleep 1.2
triad_secondary="$(role secondary)"
triad_tertiary="$(role tertiary)"
[[ -n $triad_secondary && -n $triad_tertiary ]] || fail "triad did not fill secondary/tertiary"
capture 02-triad.png

omarchy-shell doe.tools undoTheme >/dev/null 2>&1 || fail "undo IPC failed"
sleep 1.2
wait_role "$base_secondary" "undo secondary" secondary
wait_role "$base_tertiary" "undo tertiary" tertiary

omarchy-shell doe.tools redoTheme >/dev/null 2>&1 || fail "redo IPC failed"
sleep 1.2
wait_role "$triad_secondary" "redo secondary" secondary
wait_role "$triad_tertiary" "redo tertiary" tertiary

omarchy-shell doe.tools resetTheme >/dev/null 2>&1 || fail "reset IPC failed"
sleep 1.2
wait_role "$base_accent" "reset accent" accent
wait_role "$base_secondary" "reset secondary" secondary
wait_role "$base_tertiary" "reset tertiary" tertiary

capture 03-reset.png
omarchy-shell doe.tools close >/dev/null 2>&1 || true
trap - EXIT INT TERM
sleep 0.6
restore_palette

if [[ -n ${save_baseline:-} ]]; then
  echo "Baseline saved to $screens"
elif [[ -n ${compare_dir:-} ]]; then
  rc=0
  "$(dirname "${BASH_SOURCE[0]}")/ui-diff.sh" "$baseline_dir" "$compare_dir" \
    --threshold "$threshold" || rc=$?
  rm -rf "$compare_dir"
  exit "$rc"
elif [[ -n $screens ]]; then
  echo "Screenshots saved to $screens"
fi
echo "PASS: settings UI smoke test"
