#!/bin/bash
# Virtual☆Paradise — Post-theme-set hook.
#
# Omarchy runs this hook from its own shell when the active theme changes.
# $1 is the newly selected theme name. Honour XDG_CONFIG_HOME the same way
# install.sh does instead of assuming ~/.config.
#
# Installed by install.sh to:
#   $CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh
#
# Two branches:
#   - Entering Virtual Paradise: enable our plugins, apply the tracked override
#     layer, start the live wallpaper, and apply the theme bar layout only when
#     shell.json is still ours to change.
#   - Leaving Virtual Paradise: disable our plugins, restore stock ones, revert
#     the override layer, stop the live wallpaper, and restore GTK/fastfetch.
#     A user-customised shell.json is preserved in both directions.
#
# This hook must not depend on the repository: it uses the copies install.sh
# places in ~/.local/share/virtual-paradise. If a copy is missing it degrades to
# doing nothing rather than writing a guessed file.

set -uo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
THEME_NAME="${1:-}"
VP_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/virtual-paradise"
VP_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise"

# ---------------------------------------------------------------------------
# Plugin state helpers
# ---------------------------------------------------------------------------
# Every `omarchy plugin enable/disable` walks the whole plugin catalogue, and
# the hook used to make about thirty of those calls on every theme change and
# every login - three seconds of pure no-ops, because the state was already
# correct. Asking the shell once what is enabled and only touching the
# difference turns that into a single query in the common case.
_PLUGIN_STATE=""
_PLUGIN_STATE_LOADED=0

_load_plugin_state() {
  [[ $_PLUGIN_STATE_LOADED -eq 1 ]] && return 0
  _PLUGIN_STATE_LOADED=1
  command -v omarchy >/dev/null 2>&1 || return 0
  _PLUGIN_STATE="$(omarchy plugin list --json 2>/dev/null || true)"
  return 0
}

# Is a plugin currently enabled?
#   0 = enabled, 1 = known to be disabled, 2 = unknown (no readable state)
_plugin_state_of() {
  local id="$1"
  _load_plugin_state
  if [[ -z $_PLUGIN_STATE ]] || ! command -v jq >/dev/null 2>&1; then
    return 2
  fi
  if printf '%s' "$_PLUGIN_STATE" | jq -e --arg id "$id" \
    'any(.[]; .id == $id and .enabled == true)' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Is a plugin installed at all? This is the difference between "enable the
# replacement" and "fall back to the stock widget"; the old hook disabled the
# stock plugin unconditionally, so a failed external install left the bar with
# no widget at all. Unknown state is treated as installed to preserve the old
# behaviour on a system without jq/python3.
_plugin_installed() {
  local id="$1"
  _load_plugin_state
  [[ -z $_PLUGIN_STATE ]] && return 0
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$_PLUGIN_STATE" | jq -e --arg id "$id" \
      'any(.[]; .id == $id)' >/dev/null 2>&1
    return $?
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$_PLUGIN_STATE" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(data, list):
    sys.exit(1)
sys.exit(0 if any(isinstance(p, dict) and p.get("id") == sys.argv[1] for p in data) else 1)
' "$id" >/dev/null 2>&1
    return $?
  fi
  printf '%s' "$_PLUGIN_STATE" | grep -qF "\"$id\""
}

# Enable a plugin, suppressing errors. A plugin that is already enabled is
# left alone.
_plugin_enable() {
  local id="$1" state
  _plugin_state_of "$id"; state=$?
  [[ $state -eq 0 ]] && return 0
  omarchy plugin enable "$id" >/dev/null 2>&1 || true
  _PLUGIN_STATE_LOADED=0
  return 0
}

# Disable a plugin, suppressing errors. A plugin that is already disabled is
# left alone.
_plugin_disable() {
  local id="$1" state
  _plugin_state_of "$id"; state=$?
  [[ $state -eq 1 ]] && return 0
  omarchy plugin disable "$id" >/dev/null 2>&1 || true
  _PLUGIN_STATE_LOADED=0
  return 0
}

# Enable the replacement and disable the stock widget only when the replacement
# is actually installed. Otherwise keep the stock widget enabled.
_plugin_replace() {
  local custom="$1" stock="${2:-}"
  if _plugin_installed "$custom"; then
    _plugin_enable "$custom"
    [[ -n $stock ]] && _plugin_disable "$stock"
  else
    [[ -n $stock ]] && _plugin_enable "$stock"
  fi
  return 0
}

_restart_shell() {
  if command -v omarchy-restart-shell >/dev/null 2>&1; then
    omarchy-restart-shell >/dev/null 2>&1 || true
  elif command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell >/dev/null 2>&1 || true
  fi
}

# Run one function from the installed override layer. Missing libs are a no-op:
# the hook is not allowed to fail a theme switch.
_po() {
  local fn="$1"
  [[ -f "$VP_DATA/plugin-overrides.sh" ]] || return 0
  PARADISE_CONFIG_DIR="$CFG" \
  PARADISE_STATE_DIR="$VP_STATE" \
  PARADISE_REPO_DIR="$VP_DATA" \
    bash -c '. "$1"; "$2"' _ "$VP_DATA/plugin-overrides.sh" "$fn" >/dev/null 2>&1 || true
}

# Run one function from the installed shell-layout rules and return its stdout.
_layout() {
  local fn="$1"
  [[ -f "$VP_DATA/shell-layout.sh" ]] || return 0
  VP_CONFIG_DIR="$CFG" VP_STATE_DIR="$VP_STATE" \
    bash -c '. "$1"; "$2"' _ "$VP_DATA/shell-layout.sh" "$fn" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 1. Sync Cava visualizer colors to the newly selected theme
# ---------------------------------------------------------------------------
if [[ -x "$HOME/.local/bin/sync_cava_theme.py" ]] && command -v python3 >/dev/null 2>&1; then
  python3 "$HOME/.local/bin/sync_cava_theme.py" "$THEME_NAME" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 2. Enter / leave Virtual Paradise
# ---------------------------------------------------------------------------
if [[ "$THEME_NAME" == "virtual-paradise" ]]; then
  # ── ENTERING ──────────────────────────────────────────────────────────────

  # 2a. Plugin state: enable ours, disable the stock ones we replace. Every
  # replacement is conditional on the custom plugin existing, so a failed
  # external install falls back to the stock widget instead of removing it.
  if command -v omarchy >/dev/null 2>&1; then
    u="${USER:-$(id -un)}"

    _plugin_replace "crmne.hyprmoncfg" ""
    _plugin_replace "io.github.jeffcortez23.omarchy-projector-cast" ""
    _plugin_replace "jankeesvw.notification-center" ""

    # Vitals supersedes both the memory widget and harshith.system-monitor. If
    # it is missing, keep the stock memory widget instead of an empty slot.
    if _plugin_installed "io.github.woogy7.vitals"; then
      _plugin_enable "io.github.woogy7.vitals"
      _plugin_disable "harshith.system-monitor"
      _plugin_disable "${u}.memory"
      _plugin_disable "omarchy.memory"
    else
      _plugin_enable "harshith.system-monitor"
      _plugin_enable "omarchy.memory"
    fi

    _plugin_replace "onlyvishesh.power-manager" "omarchy.power"
    _plugin_installed "onlyvishesh.power-manager" && _plugin_disable "${u}.power"

    _plugin_replace "io.github.erikburdett.wavebar" "omarchy.media"

    _plugin_replace "ssupt.audio-control" "omarchy.audio"
    _plugin_installed "ssupt.audio-control" && _plugin_disable "${u}.audio"

    _plugin_replace "ssupt.bluetooth-audio" "omarchy.bluetooth"
    _plugin_installed "ssupt.bluetooth-audio" && _plugin_disable "${u}.bluetooth"

    _plugin_replace "io.github.tyrichards.workspaces-jap" "omarchy.workspaces"
    _plugin_installed "io.github.tyrichards.workspaces-jap" && _plugin_disable "${u}.workspaces"

    _plugin_replace "io.github.adamcbrewer.voxtype-aura" ""

    # The bar itself. If the first-party copy is missing, keep omarchy.bar
    # enabled; shell.json may still name the island bar and Omarchy's
    # activeBarId will fall back without us rewriting the user's layout.
    if _plugin_installed "${u}.island-bar"; then
      _plugin_enable "${u}.island-bar"
      _plugin_disable "omarchy.bar"
      _plugin_disable "mscurtescu.island-bar"
    else
      _plugin_enable "omarchy.bar"
    fi

    for _uw in clock weather cputemp indicators active-window menu system-update network microphone; do
      _plugin_replace "${u}.${_uw}" "omarchy.${_uw}"
    done
    unset _uw
  fi

  # 2b. Apply the tracked override layer. The old hook copied overrides without
  # recording them, so switching away left the plugins permanently patched and
  # `omarchy plugin update` could no longer fast-forward. The shared layer
  # records every touched file and reverts it on the leaving branch.
  _po po_apply_all

  # 2c. Fastfetch config.
  if [[ -f "$CFG/fastfetch/virtual-paradise.jsonc" ]]; then
    cp "$CFG/fastfetch/virtual-paradise.jsonc" "$CFG/fastfetch/config.jsonc" 2>/dev/null || true
  fi

  # 2d. Bar layout. Three-way ownership: missing/stock/previous-theme/applied
  # layouts may be replaced; a user-customised layout is preserved.
  _layout_result="$(_layout vp_layout_enter)"
  if [[ "$_layout_result" == "applied" ]]; then
    _restart_shell
    sleep 1
  fi
  unset _layout_result

  # Re-enable voxtype after a shell layout reload, which can rebuild the
  # plugin registry from shell.json. Guard on installation: enabling a plugin
  # that is not present is a no-op at best and a stale error at worst.
  if command -v omarchy >/dev/null 2>&1 && _plugin_installed "io.github.adamcbrewer.voxtype-aura"; then
    _plugin_enable "io.github.adamcbrewer.voxtype-aura"
  fi

  # 2e. GTK styling.
  if [[ -f "$CFG/omarchy/themes/virtual-paradise/config/gtk.css" ]]; then
    mkdir -p "$CFG/gtk-4.0" "$CFG/gtk-3.0"
    cp "$CFG/omarchy/themes/virtual-paradise/config/gtk.css" "$CFG/gtk-4.0/gtk.css" 2>/dev/null || true
    cp "$CFG/omarchy/themes/virtual-paradise/config/gtk.css" "$CFG/gtk-3.0/gtk.css" 2>/dev/null || true
  fi

  # 2e2. Tool themes that Omarchy does not manage itself: Yazi, Bat and tmux.
  # The theme directory carries the sources; the hook only has to put them
  # back in place and keep the pre-theme copies when the user had their own.
  _vp_tools="$CFG/omarchy/themes/virtual-paradise/config"
  if [[ -f "$_vp_tools/yazi/theme.toml" ]]; then
    mkdir -p "$CFG/yazi"
    if [[ -f "$CFG/yazi/theme.toml" ]] \
      && ! cmp -s "$_vp_tools/yazi/theme.toml" "$CFG/yazi/theme.toml" \
      && [[ ! -f "$CFG/yazi/theme.toml.paradise.bak" ]]; then
      cp "$CFG/yazi/theme.toml" "$CFG/yazi/theme.toml.paradise.bak" 2>/dev/null || true
    fi
    cp "$_vp_tools/yazi/theme.toml" "$CFG/yazi/theme.toml" 2>/dev/null || true
  fi
  if [[ -d "$_vp_tools/bat/themes" ]]; then
    mkdir -p "$CFG/bat/themes"
    cp "$_vp_tools/bat/themes"/*.tmTheme "$CFG/bat/themes/" 2>/dev/null || true
    command -v bat >/dev/null 2>&1 && bat cache --build >/dev/null 2>&1 || true
  fi
  if [[ -f "$_vp_tools/tmux/paradise.conf" ]]; then
    mkdir -p "$CFG/tmux"
    cp "$_vp_tools/tmux/paradise.conf" "$CFG/tmux/paradise.conf" 2>/dev/null || true
    if [[ -f "$CFG/tmux/tmux.conf" ]] \
      && ! grep -q 'Virtual☆Paradise tmux theme' "$CFG/tmux/tmux.conf"; then
      [[ -f "$CFG/tmux/tmux.conf.paradise.bak" ]] \
        || cp "$CFG/tmux/tmux.conf" "$CFG/tmux/tmux.conf.paradise.bak" 2>/dev/null || true
      printf '\n# Virtual☆Paradise tmux theme (managed by install.sh; remove this block to opt out)\nsource-file %s\n' \
        "$CFG/tmux/paradise.conf" >> "$CFG/tmux/tmux.conf"
    fi
  fi
  unset _vp_tools

  # 2f. Live wallpaper: start if not already running.
  if [[ -x "$HOME/.local/bin/toggle_live_wallpaper.sh" ]]; then
    if ! pgrep -f mpvpaper >/dev/null 2>&1; then
      ("$HOME/.local/bin/toggle_live_wallpaper.sh" init >/dev/null 2>&1 &)
    fi
  fi

else
  # ── LEAVING ───────────────────────────────────────────────────────────────

  # 2a. Plugin state: disable ours, enable stock ones.
  if command -v omarchy >/dev/null 2>&1; then
    u="${USER:-$(id -un)}"

    _plugin_disable "crmne.hyprmoncfg"
    _plugin_disable "io.github.jeffcortez23.omarchy-projector-cast"
    _plugin_disable "jankeesvw.notification-center"
    _plugin_disable "harshith.system-monitor"
    _plugin_enable "omarchy.memory"
    _plugin_enable "omarchy.monitor"
    _plugin_disable "onlyvishesh.power-manager"
    _plugin_enable "omarchy.power"
    _plugin_disable "io.github.erikburdett.wavebar"
    _plugin_enable "omarchy.media"
    # Disable ours, THEN enable the stock one. Chaining with `||` meant the
    # fallback only ran when the disable *failed*, leaving no audio widget.
    _plugin_disable "ssupt.audio-control"
    _plugin_enable "omarchy.audio"
    _plugin_disable "ssupt.bluetooth-audio"
    _plugin_enable "omarchy.bluetooth"
    _plugin_disable "io.github.tyrichards.workspaces-jap"
    _plugin_enable "omarchy.workspaces"
    _plugin_disable "io.github.adamcbrewer.voxtype-aura"
    _plugin_disable "mscurtescu.island-bar"
    _plugin_enable "omarchy.bar"

    for _uw in clock weather cputemp indicators active-window menu system-update network microphone; do
      _plugin_disable "${u}.${_uw}"
      _plugin_enable "omarchy.${_uw}"
    done
    unset _uw

    _plugin_enable "omarchy.agents"
    _plugin_enable "omarchy.keyboard-layout"
    _plugin_enable "omarchy.tray"
  fi

  # 2b. Revert the tracked override layer. This must happen while leaving the
  # theme, not only on uninstall: otherwise the plugins stay patched and their
  # next `omarchy plugin update` cannot fast-forward.
  _po po_revert_all

  # 2c. Stop live wallpaper so new theme background displays properly.
  pkill -f mpvpaper 2>/dev/null || true

  # 2d. Restore default Fastfetch.
  rm -f "$CFG/fastfetch/config.jsonc" 2>/dev/null || true

  # 2e. Restore default GTK CSS so other themes keep their native look.
  for _gtk in gtk-4.0 gtk-3.0; do
    if [[ -f "$CFG/$_gtk/gtk.css.bak_default" ]] && ! grep -q "Virtual" "$CFG/$_gtk/gtk.css.bak_default"; then
      cp "$CFG/$_gtk/gtk.css.bak_default" "$CFG/$_gtk/gtk.css" 2>/dev/null || true
    else
      rm -f "$CFG/$_gtk/gtk.css" "$CFG/$_gtk/gtk.css.bak_default" 2>/dev/null || true
    fi
  done
  unset _gtk

  # 2e2. Restore the tool themes that are not part of the Omarchy theme
  # system: Yazi, Bat and tmux.
  if [[ -f "$CFG/yazi/theme.toml.paradise.bak" ]]; then
    cp "$CFG/yazi/theme.toml.paradise.bak" "$CFG/yazi/theme.toml" 2>/dev/null || true
    rm -f "$CFG/yazi/theme.toml.paradise.bak" 2>/dev/null || true
  else
    rm -f "$CFG/yazi/theme.toml" 2>/dev/null || true
  fi
  rm -f "$CFG/bat/themes/VirtualParadise.tmTheme" 2>/dev/null || true
  command -v bat >/dev/null 2>&1 && bat cache --build >/dev/null 2>&1 || true
  if [[ -f "$CFG/tmux/tmux.conf.paradise.bak" ]]; then
    cp "$CFG/tmux/tmux.conf.paradise.bak" "$CFG/tmux/tmux.conf" 2>/dev/null || true
    rm -f "$CFG/tmux/tmux.conf.paradise.bak" 2>/dev/null || true
  elif [[ -f "$CFG/tmux/tmux.conf" ]]; then
    sed -i '/# Virtual☆Paradise tmux theme (managed by install.sh/,+1d' "$CFG/tmux/tmux.conf" 2>/dev/null || true
  fi
  rm -f "$CFG/tmux/paradise.conf" 2>/dev/null || true

  # 2f. Restore the stock shell layout only if the live file is still the theme
  # layout or the last layout this theme applied. A user edit survives.
  _layout_result="$(_layout vp_layout_leave)"
  if [[ "$_layout_result" == "restored" ]]; then
    _restart_shell
  fi
  unset _layout_result
fi
