#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — manual settings UI smoke test
# ==============================================================================
#  Usage:
#    tools/ui-smoke.sh [--screenshots DIR]
#
#  Drives the live settings panel through its IPC surface: open Settings, set a
#  role, generate a harmony, then assert undo/redo/reset using palette.json.
#  The original palette and variant are restored on exit.
#
#  This needs a running Omarchy session and is not part of CI. --screenshots
#  captures the panel with grim for a manual visual check.
# ==============================================================================

set -euo pipefail

state="$HOME/.local/state/virtual-paradise"
palette="$state/palette.json"
variant_file="$state/current_variant"

screens=""
if [[ ${1:-} == --screenshots ]]; then
  screens="${2:-}"
  [[ -n $screens ]] || {
    echo "--screenshots needs a directory." >&2
    exit 2
  }
  mkdir -p "$screens"
fi

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

baseline="$(mktemp)"
cp "$palette" "$baseline"
baseline_variant="$(cat "$variant_file" 2>/dev/null || echo cyberpunk)"

role() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$palette" "$1"
}

restore_palette() {
  if [[ $baseline_variant == custom ]]; then
    local -a colors=()
    while IFS= read -r value; do colors+=("$value"); done < <(python3 - "$baseline" <<'PY'
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
  rm -f "$baseline"
}

cleanup() {
  omarchy-shell doe.tools close >/dev/null 2>&1 || true
  sleep 0.6
  restore_palette
}
trap cleanup EXIT INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect() {
  local expected="$1" actual="$2" label="$3"
  [[ $expected == "$actual" ]] || fail "$label: expected $expected, got $actual"
}

base_accent="$(role accent)"
base_secondary="$(role secondary)"
base_tertiary="$(role tertiary)"

omarchy-shell doe.tools settings >/dev/null 2>&1 || fail "could not open Settings"
sleep 0.9
[[ -z $screens ]] || grim "$screens/01-settings.png" 2>/dev/null || true

omarchy-shell doe.tools setRole accent "#123456" >/dev/null 2>&1 || fail "setRole IPC failed"
sleep 1.0
expect "#123456" "$(role accent)" "setRole accent"

omarchy-shell doe.tools generateTheme triad >/dev/null 2>&1 || fail "generateTheme IPC failed"
sleep 1.2
triad_secondary="$(role secondary)"
triad_tertiary="$(role tertiary)"
[[ -n $triad_secondary && -n $triad_tertiary ]] || fail "triad did not fill secondary/tertiary"
[[ -z $screens ]] || grim "$screens/02-triad.png" 2>/dev/null || true

omarchy-shell doe.tools undoTheme >/dev/null 2>&1 || fail "undo IPC failed"
sleep 1.2
expect "$base_secondary" "$(role secondary)" "undo secondary"
expect "$base_tertiary" "$(role tertiary)" "undo tertiary"

omarchy-shell doe.tools redoTheme >/dev/null 2>&1 || fail "redo IPC failed"
sleep 1.2
expect "$triad_secondary" "$(role secondary)" "redo secondary"
expect "$triad_tertiary" "$(role tertiary)" "redo tertiary"

omarchy-shell doe.tools resetTheme >/dev/null 2>&1 || fail "reset IPC failed"
sleep 1.2
expect "$base_accent" "$(role accent)" "reset accent"
expect "$base_secondary" "$(role secondary)" "reset secondary"
expect "$base_tertiary" "$(role tertiary)" "reset tertiary"

[[ -z $screens ]] || grim "$screens/03-reset.png" 2>/dev/null || true
omarchy-shell doe.tools close >/dev/null 2>&1 || true
trap - EXIT INT TERM
sleep 0.6
restore_palette
echo "PASS: settings UI smoke test"
