#!/usr/bin/env bash
#
# Shrink the repository by dropping media blobs that only exist in history.
#
#   ./tools/shrink-history.sh            dry run: report what would be removed
#   ./tools/shrink-history.sh --apply    rewrite history (needs git-filter-repo)
#
# Why this exists
# ---------------
# Large wallpapers were committed and later deleted or replaced. Git keeps every
# version forever, so .git carries ~146 MB of media that no checkout can reach.
# A fresh clone pays for all of it. The only way to reclaim it is to rewrite
# history, which is why this is a separate, deliberate, opt-in step rather than
# something install.sh does.
#
# What it does, precisely
# -----------------------
# It removes only blobs that are reachable from some commit but absent from the
# HEAD tree. File contents at HEAD are therefore untouched: afterwards
# `git ls-tree -r HEAD` is byte-identical to before, only the commit SHAs change.
#
# What that costs
# ---------------
# Rewriting history changes every SHA. Anything already pushed must be
# force-pushed, and every other clone of this repository must be re-cloned.
# A backup bundle is written first so the operation is reversible locally.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

cd "$REPO_DIR"

die() { printf 'shrink-history: %s\n' "$*" >&2; exit 1; }

# --- preconditions -----------------------------------------------------------
[[ -d .git ]] || die "not a git repository: $REPO_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
  die "working tree is dirty; commit or stash first so nothing is lost in the rewrite"
fi

extra=$(git rev-list --count --all --not HEAD 2>/dev/null || echo 0)
if (( extra > 0 )); then
  # Other branches would be rewritten too; make that an explicit decision.
  printf 'shrink-history: note: %s commit(s) outside HEAD will also be rewritten.\n' "$extra" >&2
fi

# --- find the dead weight ----------------------------------------------------
# Blobs reachable from any ref, minus the blobs in the HEAD tree.
printf 'Scanning history...\n'
git rev-list --objects --all | awk '{print $1}' > /tmp/vp-allobj.$$
trap 'rm -f /tmp/vp-allobj.$$ /tmp/vp-allblobs.$$ /tmp/vp-headblobs.$$ /tmp/vp-gone.$$' EXIT

git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize)' \
  < /tmp/vp-allobj.$$ 2>/dev/null \
  | awk '$1 == "blob" { print $2, $3 }' > /tmp/vp-allblobs.$$

git ls-tree -r HEAD | awk '{print $3}' | sort -u > /tmp/vp-headblobs.$$

awk '{print $1}' /tmp/vp-allblobs.$$ | sort -u \
  | comm -23 - /tmp/vp-headblobs.$$ > /tmp/vp-gone.$$

total=$(awk 'NR==FNR { size[$1]=$2; next } { s += size[$1] } END { printf "%.1f", s/1048576 }' \
        /tmp/vp-allblobs.$$ /tmp/vp-gone.$$)
count=$(wc -l < /tmp/vp-gone.$$)

if (( count == 0 )); then
  printf 'Nothing to do: no history-only blobs found.\n'
  exit 0
fi

printf 'History-only blobs: %d, totalling about %s MB\n' "$count" "$total"
printf 'Current size: .git %s, working tree %s\n' \
  "$(du -sh .git | cut -f1)" "$(du -sh --exclude=.git . | cut -f1)"

if (( APPLY == 0 )); then
  printf '\nLargest history-only blobs (path is the first one seen for each):\n'
  # rev-list --objects gives "<sha> <path>"; commits and trees have no path.
  git rev-list --objects --all | awk 'NF == 2 && !seen[$1]++ { print $1, $2 }' \
    > /tmp/vp-paths.$$
  while read -r id; do
    bytes=$(awk -v i="$id" '$1 == i { print $2; exit }' /tmp/vp-allblobs.$$)
    path=$(awk -v i="$id" '$1 == i { print $2; exit }' /tmp/vp-paths.$$)
    printf '%s %s\n' "${bytes:-0}" "$path"
  done < /tmp/vp-gone.$$ | sort -rn | head -10 \
    | while read -r bytes path; do
        awk -v b="$bytes" -v p="$path" \
          'BEGIN { printf "  %6.1f MB  %s\n", b/1048576, p }'
      done
  rm -f /tmp/vp-paths.$$
  printf '\nRe-run with --apply to rewrite history.\n'
  exit 0
fi

# --- apply -------------------------------------------------------------------
command -v git-filter-repo >/dev/null 2>&1 \
  || die "git-filter-repo not found. Install it (pacman -S git-filter-repo, or pip install git-filter-repo)."

stamp="$(date +%Y%m%d_%H%M%S)"
bundle="../$(basename "$REPO_DIR")-backup-$stamp.bundle"
printf '\nWriting a safety bundle to %s ...\n' "$bundle"
git bundle create "$bundle" --all

printf 'Rewriting history...\n'
git filter-repo --strip-blobs-with-ids /tmp/vp-gone.$$ --force

printf '\nVerifying that the HEAD tree is unchanged...\n'
if ! git ls-tree -r HEAD | awk '{print $3}' | sort -u > /tmp/vp-after.$$; then
  die "could not read the rewritten tree"
fi
if diff -q /tmp/vp-headblobs.$$ /tmp/vp-after.$$ >/dev/null; then
  printf 'OK: HEAD tree is byte-identical.\n'
else
  die "HEAD tree changed - restore from $bundle and investigate"
fi
rm -f /tmp/vp-after.$$

printf '\nAfter: .git %s, working tree %s\n' \
  "$(du -sh .git | cut -f1)" "$(du -sh --exclude=.git . | cut -f1)"

cat <<EOF

Done. To publish the rewritten history:

    git remote add origin git@github.com:llIIllIID0EIIllIIll/virtual-paradise.git
    git push --force origin main

Anyone else who has cloned this repository must re-clone; their existing
checkout cannot be reconciled with the new SHAs. The safety bundle is at
$bundle if you need to undo this locally.
EOF
