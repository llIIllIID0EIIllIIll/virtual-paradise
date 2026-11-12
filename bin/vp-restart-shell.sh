#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — single-flight shell restart
# ==============================================================================
#  `omarchy restart shell` spawns a fresh supervisor. Two concurrent calls can
#  race the `quickshell -n` duplicate check and leave two full shells (two bars)
#  mapped on the same output. This wrapper serialises the call; a second caller
#  exits immediately instead of starting another shell.
# ==============================================================================

set -euo pipefail

runtime="${XDG_RUNTIME_DIR:-/tmp}"
lock="$runtime/virtual-paradise-restart-shell.lock"

exec 9>"$lock"
if ! flock -n 9; then
  echo "vp-restart-shell: another restart is already in progress" >&2
  exit 0
fi

exec omarchy restart shell
