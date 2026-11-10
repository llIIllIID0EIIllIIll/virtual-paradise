#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034
# SC2154: installer globals are set by install.sh before these run.
# SC2034: variables are read by install.sh, not here.
# ==============================================================================
#  Virtual☆Paradise — plugin install/enable step
# ==============================================================================
#  Synchronises the theme's plugins, applies the override layer and enables the
#  widget set. Sourced by install.sh after the helper libraries.
# ==============================================================================

po_install_island_bar() {
  local src_dir="$REPO_DIR/bars/island-bar"
  local dest_root="/usr/share/omarchy/shell/plugins"
  local dest_dir="$dest_root/${CURRENT_USER}.island-bar"
  local data_dir="$HOME/.local/share/virtual-paradise"
  local repair_dir="$data_dir/island-bar"

  if [[ ! -d "$src_dir" ]]; then
    log_warn "Island Bar sources missing at $src_dir"
    return 1
  fi

  # Render the bundle once into a user-owned repair copy. The post-update hook
  # uses this when the first-party copy is missing; keeping it even when the
  # system copy cannot be written (--user-only, no sudo) means a later repair
  # does not need the repository to still exist.
  mkdir -p "$data_dir" 2>/dev/null || {
    log_warn "Could not create $data_dir — skipping Paradise Island Bar."
    return 1
  }
  local stage
  stage="$(mktemp -d "$data_dir/.island-bar-stage.XXXXXX")" || {
    log_warn "Could not create staging dir — skipping Paradise Island Bar."
    return 1
  }
  : >"$stage/.paradise-files"

  # Every file the bundle ships, rather than a hand-maintained subset: a QML
  # component added to bars/island-bar/ has to reach the deployed copy, or the
  # bar ends up importing a component that is not installed alongside it.
  local src f
  for src in "$src_dir"/*.qml "$src_dir"/*.js "$src_dir"/*.json; do
    [[ -f $src ]] || continue
    f="$(basename "$src")"
    if ! sed "s/__USER__/${CURRENT_USER}/g" "$src" >"$stage/$f" 2>/dev/null; then
      rm -rf "$stage"
      log_warn "Could not render $src"
      return 1
    fi
    printf '%s\n' "$f" >>"$stage/.paradise-files"
  done

  rm -rf "$repair_dir" 2>/dev/null || true
  if ! mv "$stage" "$repair_dir" 2>/dev/null; then
    rm -rf "$stage"
    log_warn "Could not publish the island bar repair copy at $repair_dir."
    return 1
  fi

  if [[ ! -w "$dest_root" && ! -d "$dest_dir" ]] && ! run_privileged true; then
    log_warn "Cannot write $dest_root and no sudo available — Paradise Island Bar skipped."
    log_info "  sudo mkdir -p '$dest_dir' && sudo cp -r '$src_dir'/* '$dest_dir'/"
    log_info "  A repair copy is available at $repair_dir for the post-update hook."
    return 1
  fi

  run_privileged mkdir -p "$dest_dir" 2>/dev/null || {
    log_warn "Could not create $dest_dir — skipping Paradise Island Bar."
    return 1
  }

  # The previous manifest lists the files this theme installed. Files removed
  # upstream are pruned so a stale component cannot keep loading; anything the
  # user added to the directory is not in the list and is left alone.
  local old_files=""
  if [[ -f "$dest_dir/.paradise-files" ]]; then
    old_files="$(cat "$dest_dir/.paradise-files" 2>/dev/null || true)"
  fi

  for src in "$repair_dir"/* "$repair_dir"/.paradise-files; do
    [[ -f $src ]] || continue
    f="$(basename "$src")"
    if ! run_privileged cp "$src" "$dest_dir/$f" 2>/dev/null; then
      # A pre-existing root-owned copy from an older run can block the write
      # even with sudo in play; surface it instead of failing silently.
      if ! run_privileged cp -f "$src" "$dest_dir/$f" 2>/dev/null; then
        log_warn "Could not write $dest_dir/$f"
        return 1
      fi
    fi
  done

  if [[ -n $old_files && -f "$repair_dir/.paradise-files" ]]; then
    while IFS= read -r f; do
      [[ -n $f ]] || continue
      grep -qxF "$f" "$repair_dir/.paradise-files" 2>/dev/null || \
        run_privileged rm -f "$dest_dir/$f" 2>/dev/null || true
    done <<<"$old_files"
  fi

  # The registry only rescans on demand, so ask for one now rather than
  # leaving the shell on the previous bar until the next restart.
  RUN_AS_INSTALL_USER omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  log_sub "Installed Paradise Island Bar to $dest_dir (repair copy: $repair_dir)"
}

INSTALL_AND_ENABLE_PLUGINS() {
  log_step "3" "$TOTAL_STEPS" "Installing and enabling custom Quickshell plugins for user '$CURRENT_USER'..."
  # These repo-owned clones were replaced by maintained external plugins.
  # Remove their installed copies so an install cannot briefly re-enable or
  # leave stale rice widgets in the plugin registry.
  local replaced_plugin
  for replaced_plugin in audio bluetooth monitor power workspaces media memory; do
    RUN_AS_INSTALL_USER omarchy plugin remove "${CURRENT_USER}.${replaced_plugin}" --yes 2>/dev/null || true
    rm -rf "$CONFIG_DIR/omarchy/plugins/${CURRENT_USER}.${replaced_plugin}"
  done

  # The background service clone is retired too: Omarchy 4.5 renders video
  # wallpapers itself, so the stock plugin takes the layer back. Leaving the
  # old copy behind kept a second IPC handler on the "background" target.
  RUN_AS_INSTALL_USER omarchy plugin remove "${CURRENT_USER}.background" --yes 2>/dev/null || true
  rm -rf "$CONFIG_DIR/omarchy/plugins/${CURRENT_USER}.background"
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.background" 2>/dev/null || true
  if [[ -d "$REPO_DIR/plugins" ]]; then
    local count=0
    for pdir in "$REPO_DIR"/plugins/*; do
      if [[ -d "$pdir" && -n "$(find "$pdir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        local plugin_name
        plugin_name=$(basename "$pdir")
        local target_plugin_id="${CURRENT_USER}.${plugin_name}"
        local target_dir="$CONFIG_DIR/omarchy/plugins/$target_plugin_id"

        mkdir -p "$target_dir"
        # --delete, not cp: a file we rename or drop upstream would otherwise
        # linger here forever and keep loading, reintroducing removed widgets or
        # double-registering an IPC handler against the current one.
        sync_tree "$pdir" "$target_dir" mirror

        # Dynamically update __USER__. to active username (${CURRENT_USER}.)
        find "$target_dir" -type f \( -name "*.json" -o -name "*.qml" -o -name "*.js" \) -exec sed -i \
          -e "s/__USER__\./${CURRENT_USER}./g" \
          -e "s/\"id\": \"[^\"]*\.${plugin_name}\"/\"id\": \"${target_plugin_id}\"/g" \
          -e "s/moduleName: \"[^\"]*\.${plugin_name}\"/moduleName: \"${target_plugin_id}\"/g" {} +
        count=$((count + 1))
      fi
    done
    log_sub "Synchronized and calibrated ${count} plugins for '${CURRENT_USER}'"

    # Trigger Quickshell plugin rescan
    if command -v omarchy-shell &>/dev/null; then
      RUN_AS_INSTALL_USER omarchy-shell shell rescanPlugins 2>/dev/null || true
    fi

    # Explicitly activate and register each plugin in Omarchy
    if command -v omarchy &>/dev/null; then
      local enabled_count=0
      for pdir in "$REPO_DIR"/plugins/*; do
        if [[ -d "$pdir" && -n "$(find "$pdir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
          local pname
          pname=$(basename "$pdir")
          local pid="${CURRENT_USER}.${pname}"
          RUN_AS_INSTALL_USER omarchy plugin enable "$pid" 2>/dev/null || true
          enabled_count=$((enabled_count + 1))
        fi
      done
      po_apply_all
      log_sub "Enabled all ${enabled_count} Virtual Paradise plugins in Omarchy shell"

      # The window-death burst moved from a second resident Quickshell into an
      # overlay plugin in this shell. Stop the old daemon if this install is
      # replacing it live; the autostart line is removed further down.
      pkill -f 'vp_death_daemon.qml' 2>/dev/null || true

      # Install the external webcam plugin but leave it off the minimal bar.
      # Enabling a bar-widget auto-adds it to shell.json; the user can bring
      # it back with `omarchy plugin enable io.github.kristoferlund.webcam`.
      if [[ ! -d "$CONFIG_DIR/omarchy/plugins/io.github.kristoferlund.webcam" ]] && ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.kristoferlund.webcam")' >/dev/null; then
        log_sub "Adding external Omarchy webcam plugin from git (kept off the bar)..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/kristoferlund/omarchy-webcam.git --yes 2>/dev/null || true
      fi

      # The notification bell was retired: Omarchy 4.5 ships its own
      # notification service (grouped stacks, inline actions, DND, history and
      # keybinds), and the third-party watcher leaked one inotifywait process
      # per shell reload - 121 of them, ~285 MB of RSS. Remove the stale
      # plugin and any orphaned watchers on every install.
      if [[ -d "$CONFIG_DIR/omarchy/plugins/jankeesvw.notification-center" ]] \
        || RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "jankeesvw.notification-center")' >/dev/null; then
        log_sub "Retiring the third-party notification center (stock service owns it now)..."
        RUN_AS_INSTALL_USER omarchy plugin remove "jankeesvw.notification-center" --yes 2>/dev/null || true
      fi
      rm -rf "$CONFIG_DIR/omarchy/plugins/jankeesvw.notification-center"
      pkill -f 'inotifywait.*omarchy/notifications' 2>/dev/null || true

      # hyprmoncfg is installed but kept off the minimal bar. The old
      # Display & Scaling widgets stay disabled to avoid duplicate controls.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "crmne.hyprmoncfg")' >/dev/null; then
        log_sub "Adding external Omarchy monitor manager plugin from git (kept off the bar)..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/crmne/omarchy-hyprmoncfg.git --yes 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.monitor" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.monitor" 2>/dev/null || true

      # Vitals replaces the memory-only widget in this theme's center bar slot.
      # It supersedes harshith.system-monitor, which could not show a GPU on
      # this machine: that plugin reads GPU telemetry from sysfs only, and the
      # proprietary NVIDIA driver exposes nothing there, so every GPU tile stayed
      # hidden. Vitals queries nvidia-smi and covers the same CPU/RAM/disk/net
      # data plus GPU, sensors and processes.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.woogy7.vitals")' >/dev/null; then
        log_sub "Adding external Vitals system monitor from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/Woogy7/omarchy-vitals.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.woogy7.vitals" 2>/dev/null || true
      fi
      # Retire the plugin Vitals supersedes, otherwise its RAM readout stays on
      # the bar next to Vitals' own chip.
      RUN_AS_INSTALL_USER omarchy plugin disable "harshith.system-monitor" 2>/dev/null || true
      po_apply_all
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.memory" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.memory" 2>/dev/null || true

      # Projector & Cast is installed but kept off the minimal bar too.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.jeffcortez23.omarchy-projector-cast")' >/dev/null; then
        log_sub "Adding external Projector & Cast plugin from git (kept off the bar)..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/JeffCortez23/omarchy-projector-cast.git --yes 2>/dev/null || true
      fi

      # The specialized widgets stay enabled (their services power the Tools
      # dropdown) but hidden: an enabled bar-widget is auto-added to
      # shell.json, so the layout below rewrites every one of them with
      # `"hidden": true`. The Tools button is their visible entry point.
      for _tool in io.github.randazraik.xray io.github.grichard99.omaproton-vpn \
                   io.github.kristoferlund.webcam crmne.hyprmoncfg \
                   io.github.jeffcortez23.omarchy-projector-cast ssuppt.bluetooth-audio; do
        RUN_AS_INSTALL_USER omarchy plugin enable "$_tool" 2>/dev/null || true
      done
      unset _tool
      # The stock Bluetooth widget stays off; ssuppt.bluetooth-audio is the
      # one hidden behind the Tools menu.
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.bluetooth" 2>/dev/null || true
      if [[ -f "$CONFIG_DIR/omarchy/shell.json" ]]; then
        python3 - "$CONFIG_DIR/omarchy/shell.json" <<'PY'
import json, os, sys
p = sys.argv[1]
try:
    with open(p) as fh:
        d = json.load(fh)
except Exception:
    sys.exit(0)
ids = ["io.github.randazraik.xray", "io.github.grichard99.omaproton-vpn",
       "io.github.kristoferlund.webcam", "crmne.hyprmoncfg",
       "io.github.jeffcortez23.omarchy-projector-cast", "ssupt.bluetooth-audio"]
stale = set(ids) | {"omarchy.bluetooth"}
layout = d.setdefault("bar", {}).setdefault("layout", {})
for section in ("left", "center", "right"):
    entries = layout.get(section) or []
    layout[section] = [e for e in entries
                       if not (isinstance(e, dict) and str(e.get("id", "")) in stale)]
right = layout.setdefault("right", [])
for widget_id in ids:
    right.append({"id": widget_id, "hidden": True})
with open(tmp := p + ".tmp", "w") as fh:
    json.dump(d, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
    fh.flush()
    os.fsync(fh.fileno())
os.replace(tmp, p)
PY
      fi
      po_apply_all

      # The external power manager replaces the cloned Power & Battery widget.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "onlyvishesh.power-manager")' >/dev/null; then
        log_sub "Adding external Omarchy power manager plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/onlyVishesh/omarchy-power-manager.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "onlyvishesh.power-manager" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.power" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.power" 2>/dev/null || true

      # Extra bar widgets for the rice. Each is a self-contained Quickshell
      # plugin; the VPN widget needs a Proton account before it does anything,
      # and the radar downloads its engine from upstream Releases on first use.
      while IFS='|' read -r extra_id extra_url; do
        [[ -n $extra_id ]] || continue
        if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null |
             jq -e --arg i "$extra_id" 'any(.[]; .id == $i)' >/dev/null; then
          log_sub "Adding external plugin ${extra_id} from git..."
          RUN_AS_INSTALL_USER omarchy plugin add "$extra_url" --enable --yes 2>/dev/null || true
        else
          RUN_AS_INSTALL_USER omarchy plugin enable "$extra_id" 2>/dev/null || true
        fi
      done <<'EXTRA_PLUGINS'
io.github.randazraik.xray|https://github.com/RandaZraik/omarchy-xray
io.github.grichard99.omaproton-vpn|https://github.com/grichard99/omaproton-vpn
EXTRA_PLUGINS
      po_apply_all

      # Advanced Audio Control replaces the cloned Omarchy audio widget.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "ssupt.audio-control")' >/dev/null; then
        log_sub "Adding external Omarchy audio control plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/ssupt/omarchy-audio-control.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "ssupt.audio-control" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.audio" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.audio" 2>/dev/null || true
      po_apply_all

      # Advanced Bluetooth Audio replaces the cloned Bluetooth widget while
      # retaining its bar position and native device-management behavior.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "ssupt.bluetooth-audio")' >/dev/null; then
        log_sub "Adding external Omarchy Bluetooth audio plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/ssupt/omarchy-bluetooth-audio.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "ssupt.bluetooth-audio" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.bluetooth" 2>/dev/null || true

      # Wavebar replaces the media/Cava widget in the center of the
      # Virtual Paradise bar.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.erikburdett.wavebar")' >/dev/null; then
        log_sub "Adding Omarchy Wavebar media widget from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/ErikBurdett/omarchy-wavebar.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.erikburdett.wavebar" 2>/dev/null || true
      fi
      po_apply_all

      # Workspaces (JAP) replaces the cloned Omarchy workspace widget.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.tyrichards.workspaces-jap")' >/dev/null; then
        log_sub "Adding external Japanese workspace plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/TyRichards/omarchy-workspaces-jap.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.tyrichards.workspaces-jap" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.workspaces" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.workspaces" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin remove "${CURRENT_USER}.media" --yes 2>/dev/null || true
      po_apply_all

      # Voxtype Aura provides the themed dictation overlay, but only with the
      # omarchy-voxtype package: without its status helper the overlay cannot
      # report state. Install it, then leave it off until the helper exists.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.adamcbrewer.voxtype-aura")' >/dev/null; then
        log_sub "Adding Voxtype Aura dictation overlay plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/adamcbrewer/voxtype-aura.git --yes 2>/dev/null || true
      fi
      if command -v omarchy-voxtype-status >/dev/null 2>&1; then
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.adamcbrewer.voxtype-aura" 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin disable "io.github.adamcbrewer.voxtype-aura" 2>/dev/null || true
      fi
      po_apply_all

      # Paradise Island Bar is installed as a first-party plugin so it inherits
      # the host ShellRoot. A third-party bar only ever receives a scoped
      # plugin shell whose serviceFor() is gated to the bar's own id, which is
      # why service-backed widgets (ssupt.audio-control) resolved null and
      # reported "Audio service is unavailable" over a healthy backend.
# A missing bar bundle is a warning, not a fatal error: every other
      # plugin is still usable, so don't let `set -e` abort the whole install.
      if po_install_island_bar; then
        if enable_plugin_retry "${CURRENT_USER}.island-bar"; then
          BAR_INSTALL_OK=1
        else
          log_warn "Paradise Island Bar could not be enabled: ${LAST_PLUGIN_ERROR:-unknown error}"
        fi
      else
        log_warn "Paradise Island Bar is unavailable; Omarchy will use its bundled bar."
      fi
      if (( BAR_INSTALL_OK == 1 )); then
        RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.bar" 2>/dev/null || true
        RUN_AS_INSTALL_USER omarchy plugin disable "mscurtescu.island-bar" 2>/dev/null || true
      else
        # Keep the stock bar enabled so the shell has a working bar even if the
        # first-party copy could not be installed. shell.json still names the
        # island bar; Omarchy's activeBarId falls back on its own, and the
        # post-update hook repairs the copy when it can.
        RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.bar" 2>/dev/null || true
      fi
      po_apply_all


      # The notification center owns the DND control. Disable a separately
      # installed DND plugin when present, but keep Omarchy's notification
      # service enabled because the new plugin uses it as its backend.
      local dnd_plugin_id
      for dnd_plugin_id in omarchy.dnd omarchy.do-not-disturb "${CURRENT_USER}.dnd"; do
        if RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e --arg id "$dnd_plugin_id" \
          'any(.[]; .id == $id)' >/dev/null; then
          RUN_AS_INSTALL_USER omarchy plugin disable "$dnd_plugin_id" 2>/dev/null || \
            log_warn "Could not disable legacy DND plugin '$dnd_plugin_id'."
        fi
      done
    fi
  fi
}

