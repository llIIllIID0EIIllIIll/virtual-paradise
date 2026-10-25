#!/usr/bin/env bash
# Virtual☆Paradise — post-update repair hook.
#
# Installed to:
#   $XDG_CONFIG_HOME/omarchy/hooks/post-update.d/virtual-paradise.sh
#
# Omarchy runs this as the user after `omarchy update` finishes packages and
# migrations. The update itself must never fail because of this theme, so the
# hook is deliberately best-effort: no `set -e`, no interactive commands, no
# dependency on the repository still existing.
#
# What it protects:
#   * The first-party island bar lives in /usr/share/omarchy/shell/plugins.
#     A package update cannot delete it (it is not package-owned), but a broken
#     or partially removed copy must not leave the user without a bar. The host
#     already falls back to omarchy.bar at runtime; this hook tries to repair
#     the copy first and only then reports the fallback.
#   * Plugin overrides are re-applied if Virtual Paradise is the active theme,
#     because `omarchy update` may have updated a third-party plugin.
#   * shell.json is re-owned only through the same three-way rules as install.sh
#     and the theme-set hook: a user-customised layout is preserved.
#   * User systemd timers that belong to the theme are re-enabled if a migration
#     or a reset left them disabled.
#
# Nothing here edits a package-owned Omarchy file.

set -uo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/virtual-paradise"
FIRST_PARTY_DIR="${PARADISE_FIRST_PARTY_DIR:-/usr/share/omarchy/shell/plugins}"
CURRENT_USER="${USER:-$(id -un)}"
BAR_ID="${CURRENT_USER}.island-bar"
BAR_DIR="$FIRST_PARTY_DIR/$BAR_ID"
SHELL_JSON="$CFG/omarchy/shell.json"
REPAIR_DIR="$DATA/island-bar"
LOG_TAG="virtual-paradise post-update"

mkdir -p "$STATE" 2>/dev/null || true

log() { printf '%s: %s\n' "$LOG_TAG" "$*" >&2; }

notify() {
  local message="$1" urgency="${2:-normal}"
  command -v notify-send >/dev/null 2>&1 || return 0
  [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]] || return 0
  notify-send --app-name="Virtual☆Paradise" --urgency="$urgency" \
    "Virtual☆Paradise" "$message" >/dev/null 2>&1 || true
}

notify_once() {
  local key="$1" message="$2"
  local marker="$STATE/$key"
  [[ -f $marker ]] && return 0
  printf '%s\n' "$message" >"$marker" 2>/dev/null || true
  notify "$message"
}

clear_notice() { rm -f "$STATE/$1" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# Minimal JSON readers. The hook must work even when jq was removed by an
# update; python3 is the fallback, and the last resort is a targeted sed match.
# ---------------------------------------------------------------------------
json_entrypoint() {
  local manifest="$1" kind="$2"
  if command -v jq >/dev/null 2>&1; then
    local out
    out="$(jq -r --arg k "$kind" '(.entryPoints // {})[$k] // empty' "$manifest" 2>/dev/null)" || out=""
    if [[ -n $out ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$manifest" "$kind" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1]) as fh:
        entry = (json.load(fh).get("entryPoints") or {}).get(sys.argv[2])
except Exception:
    entry = None
if entry:
    print(entry)
PY
    return 0
  fi
  sed -n "s/.*\"${kind}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$manifest" 2>/dev/null | head -n1
  return 0
}

json_id() {
  local manifest="$1"
  if command -v jq >/dev/null 2>&1; then
    local out
    out="$(jq -r '.id // empty' "$manifest" 2>/dev/null)" || out=""
    if [[ -n $out ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$manifest" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1]) as fh:
        print(json.load(fh).get("id") or "")
except Exception:
    pass
PY
    return 0
  fi
  sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" 2>/dev/null | head -n1
  return 0
}

selected_bar_id() {
  [[ -f $SHELL_JSON ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    local out
    out="$(jq -r '.bar.id // empty' "$SHELL_JSON" 2>/dev/null)" || out=""
    if [[ -n $out ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$SHELL_JSON" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1]) as fh:
        bar = json.load(fh).get("bar") or {}
        print(bar.get("id") or "")
except Exception:
    pass
PY
    return 0
  fi
  # The bar id is the first top-level id in the layout Omarchy writes.
  sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SHELL_JSON" 2>/dev/null | head -n1
  return 0
}

bar_healthy() {
  local manifest="$BAR_DIR/manifest.json" rel id
  [[ -f $manifest ]] || return 1
  id="$(json_id "$manifest")"
  [[ $id == "$BAR_ID" ]] || return 1
  rel="$(json_entrypoint "$manifest" bar)"
  [[ -n $rel && -s "$BAR_DIR/$rel" ]]
}

can_sudo() {
  command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1
}

# Copy the last installed, already-rendered bar bundle over the first-party
# copy. The source is user-owned, so an update cannot delete it; the destination
# needs root only because Omarchy's plugin directory does.
repair_bar() {
  local rel f old_list=""
  [[ -d $REPAIR_DIR ]] || return 1
  [[ -f "$REPAIR_DIR/manifest.json" ]] || return 1
  rel="$(json_entrypoint "$REPAIR_DIR/manifest.json" bar)"
  [[ -n $rel && -s "$REPAIR_DIR/$rel" ]] || return 1
  can_sudo || return 1
  sudo -n mkdir -p "$BAR_DIR" 2>/dev/null || return 1

  # Read the previous manifest before overwriting it: it is the only record of
  # which files the theme installed and may no longer ship.
  if [[ -f "$BAR_DIR/.paradise-files" ]]; then
    old_list="$(cat "$BAR_DIR/.paradise-files" 2>/dev/null || true)"
  fi

  for f in "$REPAIR_DIR"/* "$REPAIR_DIR"/.paradise-files; do
    [[ -f $f ]] || continue
    sudo -n cp -f "$f" "$BAR_DIR/$(basename "$f")" 2>/dev/null || return 1
  done
  sudo -n chmod 0644 "$BAR_DIR"/* "$BAR_DIR"/.paradise-files 2>/dev/null || true

  # Remove files this theme installed earlier but no longer ships. Only names
  # listed in the previous manifest are touched, so a user addition survives.
  if [[ -n $old_list && -f "$REPAIR_DIR/.paradise-files" ]]; then
    while IFS= read -r f; do
      [[ -n $f ]] || continue
      grep -qxF "$f" "$REPAIR_DIR/.paradise-files" 2>/dev/null || \
        sudo -n rm -f "$BAR_DIR/$f" 2>/dev/null || true
    done <<<"$old_list"
  fi
  return 0
}

restart_shell() {
  command -v omarchy >/dev/null 2>&1 || return 0
  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
  omarchy restart shell >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# 1. Island bar: verify, repair, or explain the host fallback.
# ---------------------------------------------------------------------------
RESTART_NEEDED=0
BAR_SELECTED=0
if selected="$(selected_bar_id 2>/dev/null)"; then
  [[ $selected == "$BAR_ID" ]] && BAR_SELECTED=1
fi

if (( BAR_SELECTED == 1 )); then
  if bar_healthy; then
    clear_notice bar-missing
    # The host only needs the plugin enabled when it is the selected bar.
    if command -v omarchy >/dev/null 2>&1; then
      omarchy plugin enable "$BAR_ID" >/dev/null 2>&1 || true
    fi
  elif repair_bar && bar_healthy; then
    clear_notice bar-missing
    log "repaired the island bar at $BAR_DIR"
    if command -v omarchy >/dev/null 2>&1; then
      omarchy plugin enable "$BAR_ID" >/dev/null 2>&1 || true
    fi
    RESTART_NEEDED=1
    notify "Island bar repaired after the update." "low"
  else
    # No sudo, no repair source, or the copy is still invalid. Omarchy's
    # activeBarId already falls back to the bundled bar; say so once instead of
    # rewriting the user's shell.json behind their back.
    log "island bar is missing or invalid at $BAR_DIR; Omarchy is using the bundled bar"
    notify_once bar-missing \
      "The island bar could not be restored after the update. Omarchy is using the stock bar; re-run install.sh to repair it."
  fi
else
  clear_notice bar-missing
fi

# ---------------------------------------------------------------------------
# 2. Active theme: re-apply the override layer and shell layout.
# ---------------------------------------------------------------------------
active_theme() {
  local theme=""
  if [[ -f "$HOME/.local/state/omarchy/current/theme.name" ]]; then
    theme="$(head -n1 "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
  elif [[ -f "$CFG/omarchy/current/theme.name" ]]; then
    theme="$(head -n1 "$CFG/omarchy/current/theme.name" 2>/dev/null || true)"
  elif command -v omarchy >/dev/null 2>&1; then
    theme="$(omarchy theme current 2>/dev/null || true)"
  fi
  printf '%s\n' "$theme"
}

theme_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9._-'
}

if [[ "$(theme_slug "$(active_theme)")" == "virtual-paradise" ]]; then
  if [[ -f "$DATA/plugin-overrides.sh" ]]; then
    PARADISE_CONFIG_DIR="$CFG" \
    PARADISE_STATE_DIR="$STATE" \
    PARADISE_REPO_DIR="$DATA" \
      bash -c '. "$1"; po_apply_all' _ "$DATA/plugin-overrides.sh" >/dev/null 2>&1 \
      || log "could not re-apply plugin overrides"
  else
    log "plugin override layer is not installed; skipping re-apply"
  fi

  if [[ -f "$DATA/shell-layout.sh" ]]; then
    layout_result="$(
      VP_CONFIG_DIR="$CFG" VP_STATE_DIR="$STATE" \
        bash -c '. "$1"; vp_layout_enter' _ "$DATA/shell-layout.sh" 2>/dev/null || true
    )"
    case "$layout_result" in
      applied)
        log "re-applied the Virtual Paradise shell layout"
        RESTART_NEEDED=1
        ;;
      preserved)
        log "kept the user-customised shell layout"
        ;;
    esac
    unset layout_result
  fi
else
  # Another theme is active. Never apply the Virtual Paradise layout there;
  # the theme-set hook already restored the stock layout when it was left.
  :
fi

# ---------------------------------------------------------------------------
# 3. User timers and compositor health: report, never block the update.
# ---------------------------------------------------------------------------
if command -v systemctl >/dev/null 2>&1; then
  for unit in paradise-plugin-check.timer paradise-audio-watchdog.timer; do
    [[ -f "$CFG/systemd/user/$unit" ]] || continue
    if ! systemctl --user is-enabled "$unit" >/dev/null 2>&1; then
      systemctl --user enable --now "$unit" >/dev/null 2>&1 \
        || log "$unit is installed but could not be enabled"
    fi
  done
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  config_errors="$(hyprctl configerrors 2>/dev/null || true)"
  [[ -n $config_errors ]] && log "hyprctl configerrors: $config_errors"
  unset config_errors
fi

if (( RESTART_NEEDED == 1 )); then
  restart_shell
fi

exit 0
