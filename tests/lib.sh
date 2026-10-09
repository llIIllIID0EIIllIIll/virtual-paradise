#!/usr/bin/env bash
# Shared helpers for the test suite.
#
# The suite must never touch the real machine: no writes to $HOME, no writes to
# /usr/share, no systemctl, no pacman. Everything runs against a throwaway
# sandbox HOME plus a PATH shim directory whose members log their argv and exit
# 0, so the installer exercises its real control flow without side effects.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/vp-tests.XXXXXX")"

PASS=0
FAIL=0
FAILED_NAMES=()

cleanup_sandbox() {
  [[ -n ${KEEP_SANDBOX:-} ]] && return 0
  rm -rf "$SANDBOX"
}
trap cleanup_sandbox EXIT

# --- reporting ---------------------------------------------------------------
GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

ok() {
  PASS=$((PASS + 1))
  printf '  %sPASS%s %s\n' "$GREEN" "$OFF" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("$1")
  printf '  %sFAIL%s %s\n' "$RED" "$OFF" "$1"
  [[ -n ${2:-} ]] && printf '       %s%s%s\n' "$DIM" "$2" "$OFF"
  return 0
}

check() {
  # check <name> <condition-exit-code> [detail]
  if [[ $2 -eq 0 ]]; then ok "$1"; else fail "$1" "${3:-}"; fi
}

section() { printf '\n%s%s%s\n' "$BOLD" "$1" "$OFF"; }

# --- sandbox -----------------------------------------------------------------
# Fresh HOME per case so installs cannot leak into one another.
new_sandbox() {
  local name="$1"
  local root="$SANDBOX/$name"
  rm -rf "$root"
  mkdir -p "$root/home"
  printf '%s' "$root"
}

# Build a PATH shim dir. Every listed command becomes a script that appends its
# argv to $SHIM_LOG and exits 0. git is deliberately NOT shimmed: the override
# layer and update-plugins.sh are built on real git behaviour, and a stub would
# hide exactly the bugs worth catching.
build_shims() {
  local dir="$1"
  mkdir -p "$dir"
  local c
  # fcitx5 gates CONFIGURE_FCITX_UNIKEY; without the shim that step is skipped
  # on a machine without fcitx5 installed and a test asserting the profile
  # backup would pass locally and fail in CI.
  for c in sudo pacman paru yay curl jq omarchy omarchy-shell systemctl \
           plymouth-set-default-theme nbfc nbfc_service asusctl nvidia-smi \
           ffmpeg ghc rustc cargo go make cmake gum notify-send fcitx5; do
    cat >"$dir/$c" <<EOF
#!/usr/bin/env bash
printf '[shim] $c' >>"\${SHIM_LOG:-/dev/null}"
for a in "\$@"; do printf ' %s' "\$a" >>"\${SHIM_LOG:-/dev/null}"; done
printf '\n' >>"\${SHIM_LOG:-/dev/null}"
exit 0
EOF
    chmod +x "$dir/$c"
  done
}

# run_installer <sandbox-root> [args...]  -> exit code, output at $root/install.log
run_installer() {
  local root="$1"; shift
  ( cd "$REPO_DIR" \
    && PATH="$root/bin:$PATH" \
       HOME="$root/home" \
       XDG_CONFIG_HOME="$root/home/.config" \
       SHIM_LOG="$root/shim.log" \
       timeout 900 bash ./install.sh --user-only --no-boot "$@" \
       >"$root/install.log" 2>&1 )
}

run_uninstaller() {
  local root="$1"; shift
  ( cd "$REPO_DIR" \
    && PATH="$root/bin:$PATH" \
       HOME="$root/home" \
       XDG_CONFIG_HOME="$root/home/.config" \
       SHIM_LOG="$root/shim.log" \
       timeout 900 bash ./uninstall.sh "$@" \
       >"$root/uninstall.log" 2>&1 )
}

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }

summary() {
  printf '\n%s────────────────────────────────────────%s\n' "$DIM" "$OFF"
  if ((FAIL == 0)); then
    printf '%s%d passed%s, 0 failed\n' "$GREEN" "$PASS" "$OFF"
    return 0
  fi
  printf '%s%d passed%s, %s%d failed%s\n' "$GREEN" "$PASS" "$OFF" "$RED" "$FAIL" "$OFF"
  local n
  for n in "${FAILED_NAMES[@]}"; do printf '  %s- %s%s\n' "$RED" "$n" "$OFF"; done
  return 1
}
