#!/usr/bin/env bash
# Virtual Paradise - Omarchy plugin override layer.
#
# Every change this dotfile makes to a *git-managed* Omarchy plugin (theme
# colours, QML rice, API compatibility fixes) is recorded in a state file so it
# can be applied and, crucially, reverted again.
#
# Why revert matters: `omarchy plugin update` fast-forwards each plugin with
# `git merge --ff-only`, which refuses to run when the working tree is dirty.
# Patching a plugin in place therefore blocks its own updates forever. The
# updater reverts this layer, updates, then re-applies it.
#
# Source this file; do not execute it. Set PARADISE_CONFIG_DIR to override
# ~/.config and PARADISE_REPO_DIR to override the repository root.

[[ -n ${_PARADISE_OVERRIDES_LOADED:-} ]] && return 0
_PARADISE_OVERRIDES_LOADED=1

PARADISE_CONFIG_DIR="${PARADISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}}"
PARADISE_STATE_DIR="${PARADISE_STATE_DIR:-$HOME/.local/state/virtual-paradise}"
PARADISE_OVERRIDE_STATE="$PARADISE_STATE_DIR/overrides.state"

# Locate overrides/ relative to this file, so the layer works whether it was
# sourced from the repo or from the copy install.sh places in
# ~/.local/share/virtual-paradise/ (where the installed updater runs from).
if [[ -z ${PARADISE_REPO_DIR:-} ]]; then
  _po_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _po_candidate in "$_po_self_dir/.." "$_po_self_dir" "$HOME/.local/share/virtual-paradise"; do
    if [[ -d "$_po_candidate/overrides" ]]; then
      PARADISE_REPO_DIR="$(cd "$_po_candidate" && pwd)"
      break
    fi
  done
  unset _po_self_dir _po_candidate
fi
PARADISE_REPO_DIR="${PARADISE_REPO_DIR:-}"

po_plugins_dir() { printf '%s/omarchy/plugins\n' "$PARADISE_CONFIG_DIR"; }
po_state_file() { printf '%s/overrides.state\n' "$PARADISE_STATE_DIR"; }

po_log() { printf '%s\n' "$*" >&2; }

po_die() {
  po_log "plugin-overrides: $*"
  return 1
}

# Absolute path of an installed plugin directory.
po_plugin_dir() { printf '%s/%s\n' "$(po_plugins_dir)" "$1"; }

# Resolve a plugin manifest entryPoint to a path relative to the plugin dir.
# Plugins may ship their QML inside a versioned runtime/<hash>/ tree, so an
# override copied to the plugin root would never be loaded by Quickshell.
po_resolve_entrypoint() {
  # Note: these must stay on separate `local` statements. Bash expands every word
  # of a `local` command before performing any of its assignments, so
  # `local a="$1" b="$a/x"` would expand $a while it is still unset.
  local plugin_dir="$1" kind="$2"
  local manifest="$plugin_dir/manifest.json"
  [[ -f $manifest ]] || return 1
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
}

# ---------------------------------------------------------------------------
# State tracking
# ---------------------------------------------------------------------------
# Format: <action>\t<plugin-id>\t<path-relative-to-plugin-dir>
# action is "modified" (tracked upstream, restore with git checkout) or
# "created" (our own file, remove on revert).

po_state_reset() {
  mkdir -p "$PARADISE_STATE_DIR"
  : >"$PARADISE_OVERRIDE_STATE"
}

po_state_record() {
  local action="$1" plugin_id="$2" abs="$3"
  local dir rel
  dir="$(po_plugin_dir "$plugin_id")"
  rel="${abs#"$dir"/}"
  [[ $rel == "$abs" ]] && return 0 # not inside the plugin, nothing to revert
  local line
  line="$action"$'\t'"$plugin_id"$'\t'"$rel"
  grep -qxF "$line" "$PARADISE_OVERRIDE_STATE" 2>/dev/null && return 0
  printf '%s\n' "$line" >>"$PARADISE_OVERRIDE_STATE"
}

# Record an existing file before mutating it in place.
po_touch_existing() {
  local plugin_id="$1" abs="$2"
  [[ -f $abs ]] || return 0
  po_state_record modified "$plugin_id" "$abs"
}

# Copy a repo override onto an installed plugin file, recording either a
# modification (file existed) or a creation (it did not).
po_install_override() {
  local plugin_id="$1" source="$2" target="$3"
  [[ -f $source ]] || return 0
  local dir
  dir="$(po_plugin_dir "$plugin_id")"
  [[ -d $dir ]] || return 0
  mkdir -p "$(dirname "$target")"
  if [[ -f $target ]]; then
    po_touch_existing "$plugin_id" "$target"
  else
    po_state_record created "$plugin_id" "$target"
  fi
  cp "$source" "$target"
}

# ---------------------------------------------------------------------------
# Theme colours
# ---------------------------------------------------------------------------
# Keep third-party bar icons on the active theme accent instead of the default
# bar foreground, which is intentionally white in some Omarchy setups.
#
# The file is recorded in the state *before* the idempotence check: a file that
# already carries the marker from an earlier run is still part of the override
# layer and still has to be reverted later.
PO_ACCENT_MARKER="Virtual Paradise theme accent override"

po_patch_accent() {
  local plugin_id="$1" file="$2" script="$3"
  [[ -f $file ]] || return 0
  po_touch_existing "$plugin_id" "$file"
  grep -q "$PO_ACCENT_MARKER" "$file" && return 0
  sed -i "$script" "$file"
}

po_apply_theme_colors() {
  local p
  p="$(po_plugins_dir)"

  po_patch_accent crmne.hyprmoncfg "$p/crmne.hyprmoncfg/BarWidget.qml" \
    "/id: button/,/text: root.monitorCount/ { /bar: root.bar/ a\\
    //$PO_ACCENT_MARKER\\
    foreground: Color.accent
    }"

  po_patch_accent onlyvishesh.power-manager "$p/onlyvishesh.power-manager/Panel.qml" \
    "/id: barBtn/,/text: ((root.config/ { /bar: root.bar/ a\\
    //$PO_ACCENT_MARKER\\
    foreground: Color.accent
    }"

  # webcam also needs the qs.Commons import for Color.accent to resolve.
  if [[ -f $p/io.github.kristoferlund.webcam/BarWidget.qml ]]; then
    po_touch_existing io.github.kristoferlund.webcam "$p/io.github.kristoferlund.webcam/BarWidget.qml"
    if ! grep -q "$PO_ACCENT_MARKER" "$p/io.github.kristoferlund.webcam/BarWidget.qml"; then
      sed -i '1a import qs.Commons' "$p/io.github.kristoferlund.webcam/BarWidget.qml"
      po_patch_accent io.github.kristoferlund.webcam "$p/io.github.kristoferlund.webcam/BarWidget.qml" \
        "/id: button/,/text: \"\U000f0100\"/ { /bar: root.bar/ a\\
    //$PO_ACCENT_MARKER\\
    foreground: root.bar ? root.bar.urgent : \"#00f5d4\"
    }"
    fi
  fi

  po_patch_accent jankeesvw.notification-center "$p/jankeesvw.notification-center/Panel.qml" \
    "/id: button/,/text: root.dnd/ { /bar: root.bar/ a\\
    //$PO_ACCENT_MARKER\\
    foreground: Color.accent
    }"

  po_patch_accent ssupt.bluetooth-audio "$p/ssupt.bluetooth-audio/Panel.qml" \
    "/id: button/,/text: root.icon/ { /bar: root.bar/ a\\
    //$PO_ACCENT_MARKER\\
    foreground: Color.accent
    }"

  # projector-cast ships a Style.radius() helper that no longer exists, and its
  # icon colour is a nested conditional on presentation state. Both are patched
  # in place and tracked, so a plugin update is re-patched by the same layer
  # rather than leaving the bar with a broken import or a non-themed icon.
  if [[ -f $p/io.github.jeffcortez23.omarchy-projector-cast/Panel.qml ]]; then
    po_touch_existing io.github.jeffcortez23.omarchy-projector-cast \
      "$p/io.github.jeffcortez23.omarchy-projector-cast/Panel.qml"
    sed -i \
      -e 's/Style\.radius(6)/Style.cornerRadius/g' \
      -e 's/foreground: root\.gndRunning ? Color\.accent : (root\.presentationMode ? Color\.accent : (root\.bar ? root\.bar\.foreground : Color\.foreground))/foreground: Color.accent/' \
      "$p/io.github.jeffcortez23.omarchy-projector-cast/Panel.qml"
  fi

  # omaproton draws its mark in the bar foreground, so it reads as white next
  # to the accent icons. Point its bar colour at the accent; the connected /
  # disconnected difference is carried by the glyph's opacity, not the hue.
  po_patch_accent io.github.grichard99.omaproton-vpn \
    "$p/io.github.grichard99.omaproton-vpn/Panel.qml" \
    "/readonly property color barIconColor/ {
      s/.*/  readonly property color barIconColor: Color.accent/
    }"

  # audio-control replaces an existing property rather than adding one.
  # `|| true` matters: an absent or partial plugin must degrade to the legacy
  # Panel.qml path instead of tripping `set -e` and aborting the whole install.
  local audio_rel audio_panel
  audio_rel="$(po_resolve_entrypoint "$p/ssupt.audio-control" barWidget || true)"
  if [[ -n $audio_rel ]]; then
    audio_panel="$p/ssupt.audio-control/$audio_rel"
  else
    audio_panel="$p/ssupt.audio-control/Panel.qml"
  fi
  po_patch_accent ssupt.audio-control "$audio_panel" \
    "/foreground: root.barForeground/ {
      i\\
          //$PO_ACCENT_MARKER
      s/foreground: root.barForeground/foreground: Color.accent/
    }"
}
# ---------------------------------------------------------------------------
# Revert
# ---------------------------------------------------------------------------
# Restore every plugin file this layer touched to its upstream state. Untracked
# files are left alone except the ones recorded as created: `git clean -fd`
# would also delete plugin runtime caches, which are not ours to delete.
po_revert_all() {
  local state
  state="$(po_state_file)"
  if [[ ! -s $state ]]; then
    po_log "No recorded overrides; nothing to revert."
    return 0
  fi

  local action plugin_id rel abs dir reverted=0 skipped=0
  while IFS=$'\t' read -r action plugin_id rel; do
    [[ -n ${action:-} && -n ${plugin_id:-} && -n ${rel:-} ]] || continue
    dir="$(po_plugin_dir "$plugin_id")"
    [[ -d $dir/.git ]] || {
      skipped=$((skipped + 1))
      continue
    }
    abs="$dir/$rel"
    case "$action" in
      created)
        if [[ -e $abs ]]; then rm -f "$abs" && reverted=$((reverted + 1)); fi
        ;;
      modified)
        # git checkout only if upstream actually tracks the path; otherwise the
        # file is one of ours and deleting it is the correct revert.
        if git -C "$dir" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
          git -C "$dir" checkout -- "$rel" && reverted=$((reverted + 1))
        elif [[ -e $abs ]]; then
          rm -f "$abs" && reverted=$((reverted + 1))
        fi
        ;;
    esac
  done <"$state"

  po_state_reset
  po_log "Reverted $reverted file(s); $skipped non-git plugin dir(s) skipped."
}

# ---------------------------------------------------------------------------
# Rice / compatibility overrides
# ---------------------------------------------------------------------------
po_apply_repo_overrides() {
  [[ -n $PARADISE_REPO_DIR ]] || return 0
  local o="$PARADISE_REPO_DIR/overrides"
  [[ -d $o ]] || return 0

  po_install_override io.github.tyrichards.workspaces-jap \
    "$o/io.github.tyrichards.workspaces-jap/Workspaces.qml" \
    "$(po_plugin_dir io.github.tyrichards.workspaces-jap)/Workspaces.qml"

  po_install_override io.github.adamcbrewer.voxtype-aura \
    "$o/io.github.adamcbrewer.voxtype-aura/Service.qml" \
    "$(po_plugin_dir io.github.adamcbrewer.voxtype-aura)/Service.qml"

  # mscurtescu.island-bar override was dropped along with the plugin: the bar
  # is now ${CURRENT_USER}.island-bar, which lives in /usr/share and so is not
  # reachable through this user-writable override layer.

  # wavebar ships a forked widget; the whole set must land together.
  local wb_src="$o/io.github.erikburdett.wavebar"
  local wb_dst
  wb_dst="$(po_plugin_dir io.github.erikburdett.wavebar)"
  if [[ -d $wb_src && -d $wb_dst ]]; then
    local f
    for f in BarWidget.qml Waveform.qml MediaModel.js Service.qml Panel.qml manifest.json; do
      [[ -f $wb_src/$f ]] && po_install_override io.github.erikburdett.wavebar \
        "$wb_src/$f" "$wb_dst/$f"
    done
    if [[ -f $wb_src/waveform.py ]]; then
      po_install_override io.github.erikburdett.wavebar \
        "$wb_src/waveform.py" "$wb_dst/waveform.py"
      chmod +x "$wb_dst/waveform.py" 2>/dev/null || true
    fi
  fi

  # harshith.system-monitor had a Panel.qml override here. The plugin is
  # retired in favour of io.github.woogy7.vitals, which reads nvidia-smi and so
  # can actually show the GPU on proprietary-driver NVIDIA cards.

  # Vitals ships a bare BarIconButton upstream, which reads as a flat grey glyph
  # beside the themed widgets. Restyle its bar entry only; the panel is
  # untouched so it keeps upstream behaviour and updates.
  po_install_override io.github.woogy7.vitals \
    "$o/io.github.woogy7.vitals/BarWidget.qml" \
    "$(po_plugin_dir io.github.woogy7.vitals)/BarWidget.qml"

  # X-Ray draws its glyph in the bar foreground (near-white) where every other
  # icon here uses the accent.
  po_install_override io.github.randazraik.xray \
    "$o/io.github.randazraik.xray/BarWidget.qml" \
    "$(po_plugin_dir io.github.randazraik.xray)/BarWidget.qml"

  # audio-control ships QML under runtime/<hash>/; resolve both entryPoints.
  local a_src="$o/ssupt.audio-control"
  local a_dst panel_rel panel_target model_rel model_target
  a_dst="$(po_plugin_dir ssupt.audio-control)"
  if [[ -d $a_src && -d $a_dst ]]; then
    panel_rel="$(po_resolve_entrypoint "$a_dst" barWidget || true)"
    model_rel="$(po_resolve_entrypoint "$a_dst" service || true)"
    panel_target="${panel_rel:+$a_dst/$panel_rel}"
    panel_target="${panel_target:-$a_dst/Panel.qml}"
    # Model.js is imported as ../core/Model.js relative to the barWidget tree.
    model_target="${model_rel:+$a_dst/$(dirname "$model_rel")/Model.js}"
    model_target="${model_target:-$a_dst/Model.js}"

    [[ -f $a_src/Panel.qml ]] &&
      po_install_override ssupt.audio-control "$a_src/Panel.qml" "$panel_target"
    [[ -f $a_src/Model.js ]] &&
      po_install_override ssupt.audio-control "$a_src/Model.js" "$model_target"
  fi

  # projector-cast still uses the removed Style.radius(6) helper.
  local proj
  proj="$(po_plugin_dir io.github.jeffcortez23.omarchy-projector-cast)/Panel.qml"
  if [[ -f $proj ]]; then
    po_touch_existing io.github.jeffcortez23.omarchy-projector-cast "$proj"
    sed -i 's/Style\.radius(6)/Style.cornerRadius/g' "$proj"
    sed -i 's/foreground: root\.gndRunning ? Color\.accent : (root\.presentationMode ? Color\.accent : (root\.bar ? root\.bar\.foreground : Color\.foreground))/foreground: Color.accent/' "$proj"
  fi
}

# Applied after every plugin add so that a freshly cloned plugin directory gets
# the overrides rather than shipping upstream. Idempotent, but called ~10x per
# install, so the summary is only printed when PO_VERBOSE is set.
po_apply_all() {
  mkdir -p "$PARADISE_STATE_DIR"
  [[ -f $PARADISE_OVERRIDE_STATE ]] || po_state_reset
  po_apply_theme_colors
  po_apply_repo_overrides
  if [[ -n "${PO_VERBOSE:-}" ]]; then
    local n
    n=$(grep -c . "$PARADISE_OVERRIDE_STATE" 2>/dev/null || echo 0)
    po_log "Override layer applied ($n file(s) tracked in $(po_state_file))."
  fi
}
