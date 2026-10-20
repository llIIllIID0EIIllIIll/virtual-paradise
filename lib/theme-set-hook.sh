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
#   - Entering Virtual Paradise: enable our plugins, apply overrides, start
#     the live wallpaper.
#   - Leaving Virtual Paradise: disable our plugins, restore stock ones, stop
#     the live wallpaper, restore GTK/fastfetch/shell layout.

set -uo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
THEME_NAME="${1:-}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Resolve a plugin's entryPoint path from its manifest.json. Some plugins ship
# QML inside a versioned runtime/<hash>/ tree; a file copied to the plugin root
# is a silent no-op.
_resolve_entrypoint() {
  local manifest="$1" kind="$2"
  [[ -f "$manifest" ]] || return 0
  python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as fh:
        entry = (json.load(fh).get('entryPoints') or {}).get(sys.argv[2])
except Exception:
    entry = None
print(entry or '')" "$manifest" "$kind" 2>/dev/null
}

# Copy an override file from the theme tree onto an installed plugin file,
# resolving entryPoints when the plugin uses a versioned layout.
_copy_override() {
  local override_dir="$1" plugin_dir="$2" filename="$3" entrypoint_kind="${4:-}"
  local src="$override_dir/$filename"
  [[ -f "$src" ]] || return 0

  local target
  if [[ -n "$entrypoint_kind" && -f "$plugin_dir/manifest.json" ]]; then
    local rel
    rel="$(_resolve_entrypoint "$plugin_dir/manifest.json" "$entrypoint_kind")"
    if [[ -n "$rel" ]]; then
      target="$plugin_dir/$rel"
    else
      target="$plugin_dir/$filename"
    fi
  else
    target="$plugin_dir/$filename"
  fi

  mkdir -p "$(dirname "$target")" 2>/dev/null || true
  cp "$src" "$target" 2>/dev/null || true
}

# Plugin state, read once per hook run.
#
# Every `omarchy plugin enable/disable` walks the whole plugin catalogue, and
# the hook used to make about thirty of those calls on every theme change and
# every login - three seconds of pure no-ops, because the state was already
# correct. Asking the shell once what is enabled and only touching the
# difference turns that into a single query in the common case.
#
# The shell is the source of truth here: `omarchy plugin list --json` is the
# same listPlugins call the enable/disable commands use.
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

# ---------------------------------------------------------------------------
# 1. Sync Cava visualizer colors to the newly selected theme
# ---------------------------------------------------------------------------
if [[ -x "$HOME/.local/bin/sync_cava_theme.py" ]]; then
  python3 "$HOME/.local/bin/sync_cava_theme.py" "$THEME_NAME" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 2. Enter / leave Virtual Paradise
# ---------------------------------------------------------------------------
if [[ "$THEME_NAME" == "virtual-paradise" ]]; then
  # ── ENTERING ──────────────────────────────────────────────────────────────

  # 2a. Apply overrides from the theme tree onto installed plugins.
  # Each override is a full file replacement: the theme ships its own QML for
  # the bar widgets it restyles.

  _vp_overrides="$CFG/omarchy/themes/virtual-paradise/overrides"
  _vp_plugins="$CFG/omarchy/plugins"

  # Simple 1:1 overrides (one file, one plugin).
  _copy_override "$_vp_overrides/io.github.tyrichards.workspaces-jap" \
    "$_vp_plugins/io.github.tyrichards.workspaces-jap" "Workspaces.qml"

  _copy_override "$_vp_overrides/io.github.adamcbrewer.voxtype-aura" \
    "$_vp_plugins/io.github.adamcbrewer.voxtype-aura" "Service.qml"

  _copy_override "$_vp_overrides/io.github.woogy7.vitals" \
    "$_vp_plugins/io.github.woogy7.vitals" "BarWidget.qml"

  # wavebar: multi-file override.
  if [[ -d "$_vp_overrides/io.github.erikburdett.wavebar" \
     && -d "$_vp_plugins/io.github.erikburdett.wavebar" ]]; then
    for _f in BarWidget.qml Waveform.qml MediaModel.js Service.qml Panel.qml manifest.json; do
      _copy_override "$_vp_overrides/io.github.erikburdett.wavebar" \
        "$_vp_plugins/io.github.erikburdett.wavebar" "$_f"
    done
    if [[ -f "$_vp_overrides/io.github.erikburdett.wavebar/waveform.py" ]]; then
      _copy_override "$_vp_overrides/io.github.erikburdett.wavebar" \
        "$_vp_plugins/io.github.erikburdett.wavebar" "waveform.py"
      chmod +x "$_vp_plugins/io.github.erikburdett.wavebar/waveform.py" 2>/dev/null || true
    fi
  fi

  # audio-control: versioned runtime/<hash>/ layout — resolve via entryPoints.
  if [[ -d "$_vp_overrides/ssupt.audio-control" \
     && -d "$_vp_plugins/ssupt.audio-control" ]]; then
    _copy_override "$_vp_overrides/ssupt.audio-control" \
      "$_vp_plugins/ssupt.audio-control" "Panel.qml" "barWidget"
    # Model.js sits next to the service entryPoint, not the bar widget.
    _svc_rel="$(_resolve_entrypoint "$_vp_plugins/ssupt.audio-control/manifest.json" "service")"
    if [[ -n "$_svc_rel" ]]; then
      _copy_override "$_vp_overrides/ssupt.audio-control" \
        "$_vp_plugins/ssupt.audio-control/$(dirname "$_svc_rel")" "Model.js"
    else
      _copy_override "$_vp_overrides/ssupt.audio-control" \
        "$_vp_plugins/ssupt.audio-control" "Model.js"
    fi
    unset _svc_rel
  fi
  unset _vp_overrides _vp_plugins _f

  # 2b. Plugin state: enable ours, disable the stock ones we replace.
  if command -v omarchy >/dev/null 2>&1; then
    u="${USER:-$(id -un)}"

    _plugin_enable "crmne.hyprmoncfg"
    _plugin_enable "io.github.jeffcortez23.omarchy-projector-cast"
    _plugin_enable "io.github.woogy7.vitals"
    _plugin_disable "harshith.system-monitor"
    _plugin_disable "${u}.memory"
    _plugin_disable "omarchy.memory"

    # projector-cast: patch removed API and apply accent colour.
    _proj_panel="$CFG/omarchy/plugins/io.github.jeffcortez23.omarchy-projector-cast/Panel.qml"
    if [[ -f "$_proj_panel" ]]; then
      sed -i \
        -e 's/Style\.radius(6)/Style.cornerRadius/g' \
        -e 's/foreground: root\.gndRunning ? Color\.accent : (root\.presentationMode ? Color\.accent : (root\.bar ? root\.bar\.foreground : Color\.foreground))/foreground: Color.accent/' \
        "$_proj_panel"
    fi
    unset _proj_panel

    _plugin_disable "${u}.monitor"
    _plugin_disable "omarchy.monitor"
    _plugin_enable "onlyvishesh.power-manager"
    _plugin_disable "${u}.power"
    _plugin_disable "omarchy.power"
    _plugin_enable "io.github.erikburdett.wavebar"
    _plugin_enable "ssupt.audio-control"
    _plugin_disable "${u}.audio"
    _plugin_disable "omarchy.audio"
    _plugin_enable "ssupt.bluetooth-audio"
    _plugin_disable "${u}.bluetooth"
    _plugin_enable "io.github.tyrichards.workspaces-jap"
    _plugin_disable "${u}.workspaces"
    _plugin_disable "omarchy.workspaces"
    _plugin_enable "io.github.adamcbrewer.voxtype-aura"
    _plugin_enable "${u}.island-bar"
    _plugin_disable "omarchy.bar"
    _plugin_disable "mscurtescu.island-bar"

    for _uw in clock weather cputemp indicators active-window menu system-update network microphone; do
      _plugin_enable "${u}.${_uw}"
      _plugin_disable "omarchy.${_uw}"
    done
    unset _uw
  fi

  # 2c. Fastfetch config.
  if [[ -f "$CFG/fastfetch/virtual-paradise.jsonc" ]]; then
    cp "$CFG/fastfetch/virtual-paradise.jsonc" "$CFG/fastfetch/config.jsonc" 2>/dev/null || true
  fi

  # 2d. Bar layout: apply Virtual Paradise shell.json only if it changed.
  if [[ -f "$CFG/omarchy/shell-paradise.json" ]]; then
    if ! cmp -s "$CFG/omarchy/shell-paradise.json" "$CFG/omarchy/shell.json" 2>/dev/null; then
      cp "$CFG/omarchy/shell-paradise.json" "$CFG/omarchy/shell.json"
      omarchy-restart-shell >/dev/null 2>&1 || true
      sleep 1
    fi
  fi

  # Re-enable voxtype after a shell layout reload, which can rebuild the
  # plugin registry from shell.json.
  if command -v omarchy >/dev/null 2>&1; then
    _plugin_enable "io.github.adamcbrewer.voxtype-aura"
  fi

  # 2e. GTK styling.
  if [[ -f "$CFG/omarchy/themes/virtual-paradise/config/gtk.css" ]]; then
    mkdir -p "$CFG/gtk-4.0" "$CFG/gtk-3.0"
    cp "$CFG/omarchy/themes/virtual-paradise/config/gtk.css" "$CFG/gtk-4.0/gtk.css" 2>/dev/null || true
    cp "$CFG/omarchy/themes/virtual-paradise/config/gtk.css" "$CFG/gtk-3.0/gtk.css" 2>/dev/null || true
  fi

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
    _plugin_disable "harshith.system-monitor"
    _plugin_enable "omarchy.memory"
    _plugin_enable "omarchy.monitor"
    _plugin_disable "onlyvishesh.power-manager"
    _plugin_enable "omarchy.power"
    _plugin_disable "io.github.erikburdett.wavebar"
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

  # 2b. Stop live wallpaper so new theme background displays properly.
  pkill -f mpvpaper 2>/dev/null || true

  # 2c. Restore default Fastfetch.
  rm -f "$CFG/fastfetch/config.jsonc" 2>/dev/null || true

  # 2d. Restore default GTK CSS so other themes keep their native look.
  for _gtk in gtk-4.0 gtk-3.0; do
    if [[ -f "$CFG/$_gtk/gtk.css.bak_default" ]] && ! grep -q "Virtual" "$CFG/$_gtk/gtk.css.bak_default"; then
      cp "$CFG/$_gtk/gtk.css.bak_default" "$CFG/$_gtk/gtk.css" 2>/dev/null || true
    else
      rm -f "$CFG/$_gtk/gtk.css" "$CFG/$_gtk/gtk.css.bak_default" 2>/dev/null || true
    fi
  done
  unset _gtk

  # 2e. Restore canonical default Omarchy Bar Layout only if it changed.
  if [[ -f "$CFG/omarchy/shell-default.json" ]]; then
    if ! cmp -s "$CFG/omarchy/shell-default.json" "$CFG/omarchy/shell.json" 2>/dev/null; then
      cp "$CFG/omarchy/shell-default.json" "$CFG/omarchy/shell.json"
      omarchy-restart-shell >/dev/null 2>&1 || true
    fi
  fi
fi
