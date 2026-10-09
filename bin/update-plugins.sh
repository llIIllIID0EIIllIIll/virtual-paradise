#!/usr/bin/env bash
# Virtual Paradise - update git-managed Omarchy plugins.
#
# Wraps `omarchy plugin update`, which cannot be used directly on this setup:
# the dotfile's override layer patches plugin files in place, leaving every
# checkout dirty, and a dirty checkout cannot be fast-forwarded. This script
# reverts the override layer, lets Omarchy update and validate each plugin, then
# re-applies the layer.
#
# Modes:
#   (default), --check   fetch and report available updates; changes nothing
#   --apply              revert overrides, update, re-apply overrides, pin
#   --rollback           return every plugin to the SHA recorded in the lockfile
#   --status             show installed vs locked revisions
#   --revert-only        drop the override layer (for bisecting a broken plugin)
#   --pin                record installed revisions without updating anything

set -uo pipefail

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "$SELF")"

# Locate the override layer: explicit override, installed copy, then repo copy.
_resolve_lib() {
  local candidate
  for candidate in \
    "${PARADISE_LIB_FILE:-}" \
    "$SELF_DIR/../share/virtual-paradise/plugin-overrides.sh" \
    "$SELF_DIR/../lib/plugin-overrides.sh"; do
    [[ -n $candidate && -f $candidate ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done
  return 1
}

if ! LIB="$( _resolve_lib )"; then
  echo "update-plugins: cannot locate lib/plugin-overrides.sh" >&2
  echo "  looked in \$PARADISE_LIB_FILE, \$SELF_DIR/../share/virtual-paradise/," >&2
  echo "  and \$SELF_DIR/../lib/ (running from $SELF)" >&2
  exit 1
fi
# shellcheck source=../lib/plugin-overrides.sh
. "$LIB"

# The lib resolves PARADISE_REPO_DIR (and therefore overrides/) itself, from
# either the repo copy or the one install.sh mirrors next to it in
# ~/.local/share/virtual-paradise/.

PLUGINS_DIR="$(po_plugins_dir)"
LOCKFILE="${PARADISE_PLUGIN_LOCKFILE:-$PARADISE_STATE_DIR/plugin-versions.lock}"
BACKUP_DIR="$PARADISE_STATE_DIR/plugin-backups"

MODE="check"
ASSUME_YES=0
while (($#)); do
  case "$1" in
    --check | --dry-run) MODE="check" ;;
    --apply | --update) MODE="apply" ;;
    --rollback) MODE="rollback" ;;
    --status) MODE="status" ;;
    --revert-only) MODE="revert" ;;
    --pin) MODE="pin" ;;
    --yes | -y) ASSUME_YES=1 ;;
    -h | --help)
      # Print the header comment block, stopping at the first code line.
      awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$SELF"
      exit 0
      ;;
    *) echo "update-plugins: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

confirm() {
  ((ASSUME_YES)) && return 0
  [[ -t 0 && -t 1 ]] || {
    echo "Not a terminal; pass --yes to proceed." >&2
    return 1
  }
  gum confirm "$1"
}

git_plugins() {
  local d
  for d in "$PLUGINS_DIR"/*/; do
    d="${d%/}"
    [[ -d $d/.git ]] && printf '%s\n' "$(basename "$d")"
  done
}

# --- mode: status ----------------------------------------------------------
mode_status() {
  printf '%-46s %-10s %s\n' PLUGIN INSTALLED LOCKED
  local id cur locked
  while read -r id; do
    cur="$(git -C "$PLUGINS_DIR/$id" rev-parse --short HEAD 2>/dev/null)"
    locked="$(awk -v k="$id" '$1==k{print $2}' "$LOCKFILE" 2>/dev/null)"
    if [[ -z $locked ]]; then
      printf '%-46s %-10s %s\n' "$id" "$cur" "(unpinned)"
    elif [[ ${locked:0:7} == "$cur" ]]; then
      printf '%-46s %-10s %s\n' "$id" "$cur" "ok"
    else
      printf '%-46s %-10s %s\n' "$id" "$cur" "${locked:0:7} DRIFTED"
    fi
  done < <(git_plugins)
}

# --- mode: check -----------------------------------------------------------
# Report only. Never touches the working tree.
mode_check() {
  local id cur new behind available=0 failed=0
  while read -r id; do
    if ! git -C "$PLUGINS_DIR/$id" fetch --quiet origin HEAD 2>/dev/null; then
      printf '%-46s %s\n' "$id" "fetch failed (offline?)"
      failed=$((failed + 1))
      continue
    fi
    cur="$(git -C "$PLUGINS_DIR/$id" rev-parse --short HEAD)"
    new="$(git -C "$PLUGINS_DIR/$id" rev-parse --short FETCH_HEAD)"
    if [[ $cur == "$new" ]]; then
      printf '%-46s %s\n' "$id" "up to date"
    else
behind="$(git -C "$PLUGINS_DIR/$id" rev-list --count HEAD..FETCH_HEAD)"
    note=""
    # Warn when our override layer also touches files upstream changed.
    if grep -qF "$id" "$(po_state_file)" 2>/dev/null &&
      git -C "$PLUGINS_DIR/$id" diff --name-only HEAD FETCH_HEAD |
        grep -qxFf <(grep -P "^\S+\t$id\t" "$(po_state_file)" | cut -f3) 2>/dev/null; then
      note=" [override overlaps changed file - will re-apply]"
    fi
      printf '%-46s %s -> %s  (+%s commit(s))%s\n' "$id" "$cur" "$new" "$behind" "$note"
      available=$((available + 1))
    fi
  done < <(git_plugins)

  echo
  if ((available)); then
    echo "$available plugin(s) have updates. Apply with: paradise-plugin-update --apply"
  else
    echo "All git-managed plugins are up to date."
  fi
  ((failed)) && echo "$failed plugin(s) could not be fetched."
  return 0
}

# --- mode: revert ----------------------------------------------------------
mode_revert() {
  po_revert_all
}

# --- mode: apply -----------------------------------------------------------
snapshot_overrides() {
  # git worktree archive of each dirty plugin, so a failed update is recoverable
  # even though the override layer itself is about to be reverted.
  local stamp
  stamp="$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
  local id created=0
  mkdir -p "$stamp"
  while read -r id; do
    if ! git -C "$PLUGINS_DIR/$id" diff --quiet 2>/dev/null ||
      [[ -n $(git -C "$PLUGINS_DIR/$id" ls-files --others --exclude-standard 2>/dev/null) ]]; then
      mkdir -p "$stamp/$id"
      git -C "$PLUGINS_DIR/$id" diff >"$stamp/$id/worktree.patch" 2>/dev/null
      # Untracked files are the override copies; tar them as-is. Read them into
      # an array: a plugin path with a space would otherwise split into two
      # arguments and tar would archive the wrong things.
      local -a untracked=()
      mapfile -t untracked < <(git -C "$PLUGINS_DIR/$id" ls-files --others --exclude-standard 2>/dev/null)
      if ((${#untracked[@]})); then
        tar -C "$PLUGINS_DIR/$id" -czf "$stamp/$id/untracked.tar.gz" \
          -- "${untracked[@]}" 2>/dev/null || true
      fi
      created=$((created + 1))
    fi
  done < <(git_plugins)
  [[ $created -gt 0 ]] && printf '%s\n' "$stamp"
  return 0
}

# One snapshot dir per --apply, forever, in the same state dir that
# uninstall.sh wipes. Keep the newest few and the oldest, drop the middle.
# shellcheck disable=SC2120  # the argument is optional; callers use the default
prune_snapshots() {
  local keep="${1:-5}" n=0 total=0 f
  local -a snaps=()
  shopt -s nullglob
  snaps=("$BACKUP_DIR"/*/)
  shopt -u nullglob
  (( ${#snaps[@]} <= keep + 1 )) && return 0
  total=${#snaps[@]}
  while read -r f; do
    n=$((n + 1))
    if (( n == 1 )); then continue; fi
    if (( n == total )); then continue; fi
    if (( n > keep )); then rm -rf "$f"; fi
  done < <(printf '%s\n' "${snaps[@]}" | sort -r)
}

write_lockfile() {
  local tmp="$LOCKFILE.tmp"
  : >"$tmp"
  local id
  while read -r id; do
    printf '%s %s\n' "$id" "$(git -C "$PLUGINS_DIR/$id" rev-parse HEAD)" >>"$tmp"
  done < <(git_plugins)
  mkdir -p "$(dirname "$LOCKFILE")"
  mv "$tmp" "$LOCKFILE"
}

mode_apply() {
  local backup
  backup="$(snapshot_overrides)"
  [[ -n $backup ]] && echo "Override snapshot: $backup"
  prune_snapshots

  echo "Reverting override layer so checkouts can fast-forward..."
  po_revert_all

  echo
  echo "Updating plugins..."
  local rc=0
  omarchy plugin update --yes || rc=$?

  echo
  echo "Re-applying override layer..."
  po_apply_all

  # Only re-pin when every plugin actually updated. A partial failure leaves a
  # mix of old and new checkouts; recording that as the lockfile would replace
  # the last known-good revisions and make --rollback return to exactly the
  # broken state the user is trying to escape.
  if ((rc == 0)); then
    write_lockfile
    echo "Recorded revisions in $LOCKFILE"
  else
    if [[ -s $LOCKFILE ]]; then
      cp -a "$LOCKFILE" "$LOCKFILE.last-good" 2>/dev/null || true
      echo "Update failed; kept the previous revisions in $LOCKFILE" >&2
      echo "  (a copy is also at $LOCKFILE.last-good)" >&2
    else
      echo "Update failed and there is no previous lockfile; nothing was pinned." >&2
    fi
  fi

  echo
  echo "Restarting shell to load updated plugins..."
  omarchy restart shell >/dev/null 2>&1 || echo "  (restart failed; run 'omarchy restart shell' manually)"

  echo
  if ((rc)); then
    echo "One or more plugins failed to update (exit $rc). Run 'paradise-plugin-update --status' to compare against the lockfile." >&2
    return "$rc"
  fi
  echo "Done. Review with 'paradise-plugin-update --status'."
}

# --- mode: pin -------------------------------------------------------------
# Record the currently installed revisions without touching anything. install.sh
# calls this once plugin installation settles, so a fresh install is immediately
# reproducible and --rollback has a known-good target even before the first
# --apply. It does not prevent `omarchy plugin add` from running upstream HEAD
# once, but it makes what got installed explicit and reversible.
mode_pin() {
  mkdir -p "$(dirname "$LOCKFILE")"
  write_lockfile
  local n
  n=$(grep -c . "$LOCKFILE" 2>/dev/null || echo 0)
  echo "Pinned $n plugin revision(s) in $LOCKFILE"
}


# --- mode: rollback --------------------------------------------------------
mode_rollback() {
  if [[ ! -s $LOCKFILE ]]; then
    echo "No lockfile at $LOCKFILE; nothing pinned to roll back to." >&2
    return 1
  fi

  echo "This will return every git-managed plugin to its pinned revision."
  echo "Pinned revisions:"
  sed 's/^/  /' "$LOCKFILE"
  echo
  confirm "Roll back all plugins?" || {
    echo "Aborted."
    return 0
  }

  po_revert_all

  local id sha cur rc=0
  while read -r id sha; do
    [[ -d $PLUGINS_DIR/$id/.git ]] || continue
    cur="$(git -C "$PLUGINS_DIR/$id" rev-parse --short HEAD)"
    if [[ $(git -C "$PLUGINS_DIR/$id" rev-parse --short "$sha" 2>/dev/null) == "$cur" ]]; then
      printf '%-46s already at %s\n' "$id" "$cur"
      continue
    fi
    if git -C "$PLUGINS_DIR/$id" checkout --quiet "$sha" 2>/dev/null; then
      printf '%-46s %s -> %s\n' "$id" "$cur" "${sha:0:7}"
    else
      printf '%-46s FAILED (unknown revision %s)\n' "$id" "${sha:0:7}" >&2
      rc=1
    fi
  done <"$LOCKFILE"

  po_apply_all
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy restart shell >/dev/null 2>&1 || true
  return "$rc"
}

mkdir -p "$PARADISE_STATE_DIR"
case "$MODE" in
  check) mode_check ;;
  status) mode_status ;;
  apply) mode_apply ;;
  revert) mode_revert ;;
  pin) mode_pin ;;
  rollback) mode_rollback ;;
esac