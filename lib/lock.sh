#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — one session-wide lock
# ==============================================================================
#  install, the theme-set hook, the post-update hook and the plugin updater all
#  mutate the same override state, shell.json and plugin checkouts. A single
#  flock keeps two of them from reverting or re-applying the layer at once.
#
#  The depth counter makes nested calls safe: an outer wrapper holds the lock
#  and an inner one only bumps the depth instead of trying to re-lock the same
#  file (which would deadlock) or releasing it early.
# ==============================================================================

VP_LOCK_DEPTH=0
VP_LOCK_FD=""

vp_lock_dir() {
  printf '%s\n' "${VP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise}"
}

vp_lock() {
  if (( VP_LOCK_DEPTH > 0 )); then
    VP_LOCK_DEPTH=$((VP_LOCK_DEPTH + 1))
    return 0
  fi
  local dir lock
  dir="$(vp_lock_dir)"
  lock="$dir/virtual-paradise.lock"
  mkdir -p "$dir" 2>/dev/null || return 1
  exec {VP_LOCK_FD}>"$lock" || return 1
  if command -v flock >/dev/null 2>&1; then
    if ! flock -w 60 "$VP_LOCK_FD"; then
      exec {VP_LOCK_FD}>&-
      VP_LOCK_FD=""
      return 1
    fi
  fi
  VP_LOCK_DEPTH=1
  return 0
}

vp_unlock() {
  if (( VP_LOCK_DEPTH > 1 )); then
    VP_LOCK_DEPTH=$((VP_LOCK_DEPTH - 1))
    return 0
  fi
  if [[ -n ${VP_LOCK_FD:-} ]]; then
    exec {VP_LOCK_FD}>&-
  fi
  VP_LOCK_FD=""
  VP_LOCK_DEPTH=0
  return 0
}
