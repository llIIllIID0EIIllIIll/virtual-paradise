#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034
# SC2154: installer globals (CURRENT_USER, CONFIG_DIR, SUDO_CMD, ...) are set
#         by install.sh before these helpers are called.
# SC2034: LAST_PLUGIN_ERROR / colour vars are read by install.sh, not here.
# ==============================================================================
#  Virtual☆Paradise — installer helpers
# ==============================================================================
#  Logging, colour, privilege, file-sync and Hyprland-backup helpers shared by
#  install.sh (and available to any other installer entry point). Sourced, not
#  executed. Functions read the installer globals (CURRENT_USER, CONFIG_DIR,
#  SUDO_CMD, ...) at call time, so this file can be sourced before those are
#  set.
# ==============================================================================

# Color helpers
C_CYAN="\033[38;2;0;245;212m"
C_GREEN="\033[38;2;0;255;136m"
C_PINK="\033[38;2;255;183;213m"
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"

TOTAL_STEPS="10"

log_step() {
  local num="$1"
  local total="$2"
  local msg="$3"
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "${C_CYAN}[${num}/${total}]${C_RESET} ${C_BOLD}${msg}${C_RESET}"
  fi
}

log_sub() {
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "  ${C_GREEN}➔${C_RESET} ${C_DIM}$*${C_RESET}"
  fi
}

log_warn() {
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "  ${C_PINK}⚠${C_RESET} $*"
  fi
}

log_info() {
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "$*"
  fi
}

cleanup_install() {
  local ec=$?
  if [[ -n "${SUDO_KEEP_ALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null || true
  fi
  if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    chown -R "$CURRENT_USER:$CURRENT_USER" "$CONFIG_DIR" "$LOCAL_BIN" "$CACHE_DIR" "$HOME/.local" "$HOME/.zshrc"* "$HOME/.oh-my-zsh" 2>/dev/null || true
  fi
  exit $ec
}

RUN_AS_INSTALL_USER() {
  if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    sudo -u "$CURRENT_USER" \
      HOME="$HOME" \
      XDG_CONFIG_HOME="$CONFIG_DIR" \
      XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$CURRENT_USER")}" \
      WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
      DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
      OMARCHY_PATH="$OMARCHY_PATH" \
      "$@"
  else
    "$@"
  fi
}

# `omarchy restart shell` returns as soon as the old shell is signalled, and the
# replacement answers "omarchy-shell is not responding" for the first few
# seconds, so a plugin enable issued straight afterwards fails even though the
# plugin exists. Retry for up to ~15s, and keep the last error message so a real
# failure is reported with its cause instead of a bare warning.
LAST_PLUGIN_ERROR=""
enable_plugin_retry() {
  local plugin_id="$1" out
  local attempt=0
  LAST_PLUGIN_ERROR=""
  while (( attempt < 15 )); do
    attempt=$((attempt + 1))
    if out=$(RUN_AS_INSTALL_USER omarchy plugin enable "$plugin_id" 2>&1); then
      return 0
    fi
    LAST_PLUGIN_ERROR="$out"
    sleep 1
  done
  return 1
}

# Run a privileged command only when elevation is actually available.
# $SUDO_CMD is empty when the installer could not obtain sudo (non-interactive
# hook, --user-only), so bare "$SUDO_CMD cmd" would silently run unprivileged
# and fail halfway through the boot setup instead of being skipped cleanly.
run_privileged() {
  # USER_ONLY is checked before EUID: root does not override an explicit
  # request to leave the system alone. Not going through sudo here is what
  # keeps `install.sh --user-only` safe to run inside a container or as root.
  if (( USER_ONLY == 1 )); then
    log_warn "Skipping privileged step: --user-only was requested."
    return 1
  fi
  local can_sudo=0
  if (( EUID == 0 )); then
    can_sudo=1
  elif [[ -n "${SUDO_CMD:-}" ]] && sudo -n true 2>/dev/null; then
    can_sudo=1
  elif command -v sudo &>/dev/null && [[ -t 0 ]]; then
    log_info "  ${C_PINK}🔑 Requesting sudo permission for system-wide setup...${C_RESET}"
    if sudo -v; then
      SUDO_CMD="sudo"
      can_sudo=1
    fi
  fi

  if [[ $can_sudo -eq 0 ]]; then
    log_warn "Skipping privileged step: no sudo available."
    return 1
  fi
  if (( EUID == 0 )); then
    "$@"
  else
    # sudo resets the environment, so OMARCHY_PATH has to be handed over
    # explicitly: the commands that run as root (the boot setup, the theme
    # libraries) call omarchy themselves.
    $SUDO_CMD env OMARCHY_PATH="$OMARCHY_PATH" "$@"
  fi
}

# Mirror or merge a directory tree. rsync is in the package list and step 1
# installs it, but --user-only runs, containers and non-Omarchy distros may not
# have it; a missing tool must not turn into a silent half-install.
sync_tree() {
  local src="$1" dst="$2" mode="${3:-merge}"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    if [[ $mode == mirror ]]; then
      rsync -a --delete "$src"/ "$dst"/
    else
      rsync -a "$src"/ "$dst"/
    fi
    return 0
  fi
  if [[ $mode == mirror ]]; then
    rm -rf "${dst:?}"
    mkdir -p "$dst"
  fi
  cp -a "$src"/. "$dst"/
}

hypr_backup() {
  local src="$1"
  [[ -f "$src" ]] || return 0
  if [[ -z "$HYPR_BAK_DIR" ]]; then
    HYPR_BAK_DIR="$CONFIG_DIR/hypr/backup_$BACKUP_TIMESTAMP"
    mkdir -p "$HYPR_BAK_DIR"
  fi
  cp "$src" "$HYPR_BAK_DIR/" 2>/dev/null || true
}

# Copy a tree without deleting files the user added, while still pruning files
# the theme shipped in an earlier run and no longer ships. The manifest in
# $dst/.vp-files lists source-relative paths, so a user file can never become
# "theme-owned" and a stale theme file is removed on the next install.
sync_manifest() {
  local src="$1" dst="$2"; shift 2
  local list="$dst/.vp-files" old rel rc=0
  mkdir -p "$dst"
  old="$(mktemp)"
  [[ -f $list ]] && cp "$list" "$old"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$@" "$src"/ "$dst"/ || rc=$?
  else
    cp -a "$src"/. "$dst"/ 2>/dev/null || rc=$?
  fi
  : >"$list"
  (
    cd "$dst" || exit 1
    find . -type f -printf '%P\n'
  ) | while IFS= read -r rel; do
    [[ -n $rel && $rel != ".vp-files" ]] || continue
    [[ -f "$src/$rel" ]] && printf '%s\n' "$rel"
  done | sort >"$list"
  if [[ -s $old ]]; then
    while IFS= read -r rel; do
      [[ -n $rel ]] || continue
      grep -qxF "$rel" "$list" || rm -f "$dst/$rel"
    done <"$old"
  fi
  rm -f "$old"
  return $rc
}
