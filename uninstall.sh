#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="virtual-paradise"

if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  CURRENT_USER="$SUDO_USER"
  USER_HOME="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f6 || true)"
  [[ -n $USER_HOME ]] || USER_HOME="$HOME"
  export HOME="$USER_HOME"
else
  CURRENT_USER="${USER:-$(id -un)}"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
BACKUP_DIR="$HOME/.local/state/virtual-paradise/uninstall-backup-$(date +%Y%m%d_%H%M%S)"

# Omarchy's own environment. sudo resets the environment, so OMARCHY_PATH is
# missing when the uninstaller runs as root: every `omarchy ...` call would
# answer "OMARCHY_PATH is not set" and the plugins, theme and shell would
# never be touched. Resolve it the way Omarchy does.
# shellcheck source=lib/omarchy-env.sh
if [[ -f "$REPO_DIR/lib/omarchy-env.sh" ]]; then
  . "$REPO_DIR/lib/omarchy-env.sh"
  omarchy_export_env
  # The Hyprland instance, the Wayland display and the session bus are reset
  # by sudo too; without them the shell and the compositor cannot be reached.
  omarchy_resolve_session_env "$CURRENT_USER" || true
else
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
fi

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

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: %s [--keep-backups] [--purge-defaults]\n' "$0"
  printf 'Remove Virtual Paradise files and restore backed-up Omarchy defaults.\n'
  printf '  --keep-backups     keep shell-default.json and the snapshot dir\n'
  printf '  --purge-defaults   also delete shell-default.json (irreversible)\n'
  exit 0
fi

PURGE_DEFAULTS=0
KEEP_BACKUPS=0
for arg in "$@"; do
  case "$arg" in
    --keep-backups) KEEP_BACKUPS=1 ;;
    --purge-defaults) PURGE_DEFAULTS=1 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

# Same contract as install.sh: a missing $SUDO_CMD (non-interactive, no cached
# credential) must skip privileged work with a warning instead of running it
# unprivileged and failing halfway.
run_privileged() {
  local can_sudo=0
  if (( EUID == 0 )); then
    can_sudo=1
  elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
    can_sudo=1
  elif command -v sudo &>/dev/null && [[ -t 0 ]]; then
    if sudo -v; then can_sudo=1; fi
  fi
  if [[ $can_sudo -eq 0 ]]; then
    return 1
  fi
  if (( EUID == 0 )); then
    "$@"
  else
    # sudo resets the environment: hand OMARCHY_PATH over explicitly.
    sudo env OMARCHY_PATH="$OMARCHY_PATH" "$@"
  fi
}

mkdir -p "$BACKUP_DIR"
printf 'Removing Virtual☆Paradise for %s...\n' "$CURRENT_USER"

restore_or_remove() {
  local current="$1"
  local backup="$2"
  if [[ -e "$backup" || -L "$backup" ]]; then
    rm -rf "$current"
    mkdir -p "$(dirname "$current")"
    cp -a "$backup" "$current"
  else
    printf 'Preserving %s because no installer backup was found.\n' "$current"
  fi
}

# Snapshot the files we are about to delete or overwrite. uninstall.sh prints
# BACKUP_DIR as a recovery point, so it has to actually contain something;
# otherwise a mistake here is unrecoverable once the originals are gone.
snapshot() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  mkdir -p "$BACKUP_DIR/$(dirname "${path#$HOME/}")"
  cp -a "$path" "$BACKUP_DIR/${path#$HOME/}" 2>/dev/null || true
}

# Stop theme processes
# Only patterns that exist in this repo. The previous list also matched
# paradise_agent, rice-btop, rice-cava, rice-momoi and fastfetch-agent, none of
# which exist anywhere in the tree, so they matched nothing while widening the
# kill across every process of this user.
pkill -u "$CURRENT_USER" -f 'mpvpaper|virtual_matrix|momoisay|paradise_banner' 2>/dev/null || true
# The death daemon is matched by the path this install owns. A bare
# vp_death_daemon.qml pattern also killed the developer's live daemon when
# the test suite ran uninstall.sh in a sandbox with a different HOME.
pkill -u "$CURRENT_USER" -f "$HOME/.local/bin/vp_death_daemon\.qml" 2>/dev/null || true

# Switch theme if current theme is Virtual Paradise
if command -v omarchy &>/dev/null; then
  current_theme="$(RUN_AS_INSTALL_USER omarchy theme current 2>/dev/null || echo "")"
  if [[ "$current_theme" =~ ^[Vv]irtual ]]; then
    fallback_theme=""
    for candidate in "Catppuccin" "Tokyo Night" "Gruvbox" "Nord" "Everforest" "Rose Pine"; do
      if RUN_AS_INSTALL_USER omarchy theme list 2>/dev/null | grep -qx "$candidate"; then
        fallback_theme="$candidate"
        break
      fi
    done
    if [[ -n "$fallback_theme" ]]; then
      printf 'Switching active theme from "%s" to fallback "%s"...\n' "$current_theme" "$fallback_theme"
      RUN_AS_INSTALL_USER omarchy theme set "$fallback_theme" 2>/dev/null || true
    fi
  fi
fi

snapshot "$CONFIG_DIR/omarchy/shell.json"
# Restore the stock layout only when the live file is still the theme layout or
# the last layout this theme applied. A user-customised shell.json is preserved;
# that is the same rule the installer and theme hook use.
if [[ -f "$REPO_DIR/lib/shell-layout.sh" ]]; then
  # shellcheck source=lib/shell-layout.sh
  . "$REPO_DIR/lib/shell-layout.sh"
  layout_result="$(VP_CONFIG_DIR="$CONFIG_DIR" \
    VP_STATE_DIR="$HOME/.local/state/virtual-paradise" \
    vp_layout_leave 1 2>/dev/null || true)"
  case "$layout_result" in
    restored) printf 'Restored the stock Omarchy shell layout.\n' ;;
    preserved) printf 'Preserving shell.json because it contains customizations.\n' ;;
    already) : ;;
  esac
  unset layout_result
else
  restore_or_remove "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell-default.json"
fi
rm -f "$CONFIG_DIR/omarchy/shell-paradise.json" "$CONFIG_DIR/omarchy/extensions/paradise.json"
rm -f "$HOME/.local/state/virtual-paradise/shell-layout.applied.json"
snapshot "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
# The wallpapers were moved out of the theme directory so Omarchy does not
# copy ~95 MB of video on every theme switch. Remove them from both places.
rm -rf "$CONFIG_DIR/omarchy/backgrounds/$THEME_NAME"
rm -f "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
rm -f "$CONFIG_DIR/omarchy/hooks/post-update.d/virtual-paradise.sh"

# Plugin update check + audio backend watchdog. Stop the timers before removing
# the units, otherwise systemd keeps re-running commands that no longer exist.
if command -v systemctl &>/dev/null; then
  for paradise_timer in paradise-plugin-check.timer paradise-audio-watchdog.timer; do
    systemctl --user disable --now "$paradise_timer" >/dev/null 2>&1 || true
  done
  systemctl --user reset-failed >/dev/null 2>&1 || true
fi
rm -f "$CONFIG_DIR/systemd/user/paradise-plugin-check.service" \
      "$CONFIG_DIR/systemd/user/paradise-plugin-check.timer" \
      "$CONFIG_DIR/systemd/user/paradise-audio-watchdog.service" \
      "$CONFIG_DIR/systemd/user/paradise-audio-watchdog.timer"
systemctl --user daemon-reload >/dev/null 2>&1 || true

# The override layer is recorded in a state file; drop it and restore any plugin
# files it still has patched.
if [[ -f "$HOME/.local/share/virtual-paradise/plugin-overrides.sh" ]]; then
  bash -c '. "$HOME/.local/share/virtual-paradise/plugin-overrides.sh"; po_revert_all' \
    >/dev/null 2>&1 || true
fi
rm -rf "$HOME/.local/share/virtual-paradise"
rm -f "$HOME/.local/state/virtual-paradise/overrides.state" \
      "$HOME/.local/state/virtual-paradise/plugin-versions.lock" \
      "$HOME/.local/state/virtual-paradise/current_variant" \
      "$HOME/.local/state/virtual-paradise/current_live_wallpaper" \
      "$HOME/.local/state/virtual-paradise/theme-variant-map"
rm -rf "$HOME/.local/state/virtual-paradise/plugin-backups" \
       "$HOME/.local/state/virtual-paradise/theme-variant-orig"
rm -f /tmp/virtual_paradise_wallpaper_ready /tmp/mpv-live.sock 2>/dev/null || true
rm -f "${XDG_RUNTIME_DIR:-/tmp}/virtual_paradise_wallpaper_ready" \
      "${XDG_RUNTIME_DIR:-/tmp}/mpv-live.sock" 2>/dev/null || true
rm -f "$HOME/.local/bin/paradise-plugin-update" \
      "$HOME/.local/bin/update-plugins.sh" \
      "$HOME/.local/bin/notify-plugin-updates.sh" \
      "$HOME/.local/bin/audio-backend-watchdog.sh"

if [[ -d "$REPO_DIR/plugins" ]]; then
  for plugin_source in "$REPO_DIR"/plugins/*; do
    [[ -d "$plugin_source" ]] || continue
    rm -rf "$CONFIG_DIR/omarchy/plugins/${CURRENT_USER}.$(basename "$plugin_source")"
  done
fi

if [[ -d "$REPO_DIR/bin" ]]; then
  for bin_source in "$REPO_DIR"/bin/*; do
    rm -f "$LOCAL_BIN/$(basename "$bin_source")"
  done
fi

for file in \
  paradise_banner.py paradise-banner paradise-agent offline-agent rice_layout.sh rice cast_screen.sh cast-screen \
  toggle_cooler_boost.sh toggle_live_wallpaper.sh toggle_btop.sh toggle_voxtype_config.sh memory_detail_notify.sh \
  virtual_matrix virtual_matrix.py momoisay momoisay.real sync_cava_theme.py format-docx format-docx-vn.py vn-docx \
  hypr_window_error_shake.sh hypr_window_error_restore.sh logout_splash.qml curtain_transition.qml glitch_transition.qml \
  session_splash.sh session_splash.qml transition.sh session_base.png noise.jpg scanlines.png backdrop.png frame.png still.png \
  window_death.sh window_death.qml vp_death_daemon.sh vp_death_daemon.qml \
  Glitch.jpg Miku_missing.gif Miku_missing.mp4 uninstall-virtual-paradise widgets.sh; do
  rm -f "$LOCAL_BIN/$file"
done

for file in "$CONFIG_DIR/cava/config" "$CONFIG_DIR/cava/config_bar" "$CONFIG_DIR/fastfetch/virtual-paradise.jsonc"; do
  rm -f "$file"
done

# Use $CONFIG_DIR, not $HOME/.config: the installer wrote the .bak_default
# copies through XDG_CONFIG_HOME, so a hardcoded path misses them and deletes
# the stylesheet instead of restoring it.
for gtk_version in gtk-4.0 gtk-3.0; do
  if [[ -f "$CONFIG_DIR/$gtk_version/gtk.css.bak_default" ]]; then
    cp "$CONFIG_DIR/$gtk_version/gtk.css.bak_default" "$CONFIG_DIR/$gtk_version/gtk.css"
  else
    rm -f "$CONFIG_DIR/$gtk_version/gtk.css"
  fi
done

# ------------------------------------------------------------------------------
# Restore the config files the installer overwrote or edited in place.
#
# Each was copied aside before the first change, so uninstall must put it back;
# otherwise the user is left with the rice's shell, terminal, input method and
# editor settings and an orphaned backup nobody knows to look for.
# ------------------------------------------------------------------------------

# ~/.zshrc. The oldest snapshot is the genuine pre-install file (prune_backups
# always keeps it), so restore that rather than the newest post-install copy.
zsh_backup="$(ls -1d "$HOME"/.zshrc.bak.* 2>/dev/null | sort | head -n 1 || true)"
if [[ -n $zsh_backup && -f $zsh_backup ]]; then
  cp "$zsh_backup" "$HOME/.zshrc"
  printf 'Restored ~/.zshrc from %s\n' "$(basename "$zsh_backup")"
elif [[ -f "$HOME/.zshrc" ]]; then
  # No snapshot means the installer created the file outright, so removing it
  # puts the machine back where it started.
  rm -f "$HOME/.zshrc"
fi
rm -f "$HOME/.zshrc.zwc"

# Put the recorded login shell back. install.sh only writes this file after a
# successful chsh, and only with a path that /etc/shells accepts verbatim.
prev_login_shell_file="$HOME/.local/state/virtual-paradise/login-shell.previous"
if [[ -f "$prev_login_shell_file" ]]; then
  prev_login_shell="$(head -n1 "$prev_login_shell_file" 2>/dev/null || true)"
  if [[ -n $prev_login_shell && -x $prev_login_shell ]] \
      && grep -qxF "$prev_login_shell" /etc/shells 2>/dev/null; then
    if run_privileged chsh -s "$prev_login_shell" "$CURRENT_USER" 2>/dev/null; then
      rm -f "$prev_login_shell_file"
      printf 'Restored the login shell to %s\n' "$prev_login_shell"
    else
      printf 'Could not restore the login shell to %s (needs sudo).\n' "$prev_login_shell"
    fi
  else
    printf 'Not restoring login shell "%s": it is not a valid entry in /etc/shells.\n' "$prev_login_shell"
  fi
fi

# Files the installer edited in place, each with a .paradise.bak sibling.
for pair in \
  "$CONFIG_DIR/ghostty/config" \
  "$CONFIG_DIR/fcitx5/profile" \
  "$CONFIG_DIR/micro/settings.json"; do
  if [[ -f "$pair.paradise.bak" ]]; then
    cp "$pair.paradise.bak" "$pair"
    rm -f "$pair.paradise.bak"
    printf 'Restored %s\n' "${pair#"$HOME"/}"
  elif [[ "$pair" != *"/ghostty/"* && -f $pair ]]; then
    # No snapshot: fcitx5 and micro have no Omarchy default, so this file is one
    # the installer created and removing it is the true revert. ghostty always
    # pre-exists on Omarchy and is only edited in place, so it is left alone.
    rm -f "$pair"
    printf 'Removed %s\n' "${pair#"$HOME"/}"
  fi
done

# ------------------------------------------------------------------------------
# Hypr config the installer rewrote. It snapshotted looknfeel/input/bindings and
# monitors/autostart/hyprland into hypr/backup_<ts>/ before touching them, so
# restore that snapshot. With no snapshot those files are ours: drop the ones we
# ship outright and strip the blocks we appended, leaving any surrounding lines
# the user added intact.
# ------------------------------------------------------------------------------
# Prefer the snapshot recorded by install.sh: the first backup of a cycle is the
# user's pre-install config. The newest one is the themed file from the last
# re-install, so restoring it (as this used to) leaves Virtual☆Paradise
# bindings behind after uninstall. Falling back to the oldest directory also
# repairs machines that were installed before the state file existed.
hypr_state="$HOME/.local/state/virtual-paradise/hypr-backup-dir"
hypr_bak=""
if [[ -f "$hypr_state" ]]; then
  hypr_bak="$(head -n1 "$hypr_state" 2>/dev/null || true)"
  [[ -d $hypr_bak ]] || hypr_bak=""
fi
[[ -n $hypr_bak ]] || hypr_bak="$(ls -1d "$CONFIG_DIR"/hypr/backup_* 2>/dev/null | sort | head -n 1 || true)"

for file in looknfeel.lua input.lua bindings.lua; do
  target="$CONFIG_DIR/hypr/$file"
  [[ -e $target ]] || continue
  if [[ -n $hypr_bak && -f "$hypr_bak/$file" ]]; then
    cp "$hypr_bak/$file" "$target"
    printf 'Restored hypr/%s\n' "$file"
  elif [[ -f "$REPO_DIR/hypr/$file" ]] && cmp -s "$REPO_DIR/hypr/$file" "$target"; then
    # No snapshot: only remove a file that is byte-for-byte ours. A file the
    # user edited is left alone instead of being deleted.
    rm -f "$target"
    printf 'Removed hypr/%s\n' "$file"
  fi
done

if [[ -n $hypr_bak ]]; then
  for file in monitors.lua autostart.lua hyprland.lua; do
    [[ -f "$hypr_bak/$file" ]] && cp "$hypr_bak/$file" "$CONFIG_DIR/hypr/$file"
  done
fi

# monitors.lua and autostart.lua are shipped verbatim — the repo already carries
# the toolkit envs and the wallpaper hook — so a snapshot-less file that now
# matches the repo is one the installer created and can go. hyprland.lua has no
# repo counterpart: the installer only ever appends a window-rule block to the
# user's own file, so that block is stripped and the file itself is kept.
for file in monitors.lua autostart.lua; do
  target="$CONFIG_DIR/hypr/$file"
  [[ -f $target ]] || continue
  [[ -n $hypr_bak && -f "$hypr_bak/$file" ]] && continue
  if [[ -f "$REPO_DIR/hypr/$file" ]] && cmp -s "$REPO_DIR/hypr/$file" "$target"; then
    rm -f "$target"
    printf 'Removed hypr/%s\n' "$file"
  fi
done

# The live-wallpaper hook is ours even when the snapshot predates it, so strip
# it from an autostart.lua that the user owned.
autostart="$CONFIG_DIR/hypr/autostart.lua"
if [[ -f $autostart ]]; then
  sed -i \
    -e '/o\.launch_on_start("toggle_live_wallpaper\.sh init")/d' \
    -e '/o\.launch_on_start("session_splash\.sh")/d' \
    -e '/o\.launch_on_start("vp_death_daemon\.sh")/d' \
    "$autostart" 2>/dev/null || true
fi

hyprland="$CONFIG_DIR/hypr/hyprland.lua"
if [[ -f $hyprland ]]; then
  # Remove the exact rules install.sh appends (plus the single leftover class
  # rule older versions failed to strip). Patterns are anchored so a user rule
  # for the same app, written differently, is preserved.
  sed -i \
    -e '/^-- Virtual Paradise Add-on Window Rules$/d' \
    -e '/^o\.window({ initial_title = "Btop Monitor"/d' \
    -e '/^o\.window({ title = "Btop Monitor"/d' \
    -e '/^o\.window({ initial_title = "Voxtype Config"/d' \
    -e '/^o\.window({ title = "Voxtype Config"/d' \
    -e '/^o\.window({ initial_title = "GNOME Network Displays"/d' \
    -e '/^o\.window({ title = "GNOME Network Displays"/d' \
    -e '/^o\.window({ class = "org\.gnome\.NetworkDisplays"/d' \
    -e '/^o\.window({ class = "org\.gnome\.Nautilus"/d' \
    "$hyprland"
fi

# The preview-share-picker stylesheet is ours.
rm -f "$CONFIG_DIR/hypr/hyprland-preview-share-picker.css"

# Before Omarchy moved to Lua, the theme shipped a hyprland.conf of its own.
# Hyprland ignores it while hyprland.lua exists, but it is dead weight that
# looks like a live config, so remove it when it is clearly ours.
legacy_hypr_conf="$CONFIG_DIR/hypr/hyprland.conf"
if [[ -f $legacy_hypr_conf ]] && grep -qF 'Virtual☆Paradise Hyprland Config' "$legacy_hypr_conf"; then
  if [[ -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
    rm -f "$legacy_hypr_conf"
    printf 'Removed the legacy hyprland.conf (Omarchy loads hyprland.lua).\n'
  else
    printf 'Keeping %s: it is the only Hyprland config on this machine.\n' "$legacy_hypr_conf"
  fi
fi

[[ -n $hypr_bak ]] && rm -rf "$hypr_bak"
rm -f "$hypr_state" 2>/dev/null || true

# btop theme is additive.
rm -f "$CONFIG_DIR/btop/themes/virtual-paradise.theme"

# fastfetch: drop the shipped logos and the generated config, restoring the
# user's own config when the installer had to move it aside.
if [[ -d "$REPO_DIR/fastfetch" ]]; then
  for ff in "$REPO_DIR"/fastfetch/*; do
    [[ -f $ff ]] || continue
    case "$(basename "$ff")" in
      logo*.txt) rm -f "$CONFIG_DIR/fastfetch/$(basename "$ff")" ;;
    esac
  done
fi
if [[ -f "$CONFIG_DIR/fastfetch/config.jsonc.paradise.bak" ]]; then
  cp "$CONFIG_DIR/fastfetch/config.jsonc.paradise.bak" "$CONFIG_DIR/fastfetch/config.jsonc"
  rm -f "$CONFIG_DIR/fastfetch/config.jsonc.paradise.bak"
  printf 'Restored fastfetch/config.jsonc\n'
else
  rm -f "$CONFIG_DIR/fastfetch/config.jsonc"
fi

# Our micro colourschemes are additive, so drop only the ones this repo ships.
if [[ -d "$REPO_DIR/micro/colorschemes" ]]; then
  for scheme in "$REPO_DIR"/micro/colorschemes/*; do
    [[ -f $scheme ]] || continue
    rm -f "$CONFIG_DIR/micro/colorschemes/$(basename "$scheme")"
  done
fi

if command -v omarchy &>/dev/null; then
  # Disable Virtual Paradise plugins
  RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.island-bar" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "mscurtescu.island-bar" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "crmne.hyprmoncfg" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.jeffcortez23.omarchy-projector-cast" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.woogy7.vitals" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.randazraik.xray" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.grichard99.omaproton-vpn" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "harshith.system-monitor" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.memory" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "jankeesvw.notification-center" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "onlyvishesh.power-manager" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "ssupt.audio-control" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "ssupt.bluetooth-audio" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.erikburdett.wavebar" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.tyrichards.workspaces-jap" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.adamcbrewer.voxtype-aura" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.kristoferlund.webcam" 2>/dev/null || true

  # Disable user custom widgets
  for u_widget in clock weather cputemp indicators active-window menu system-update network microphone; do
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.${u_widget}" 2>/dev/null || true
  done

  # Enable canonical Omarchy plugins
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.bar" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.monitor" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.memory" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.power" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.audio" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.bluetooth" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.workspaces" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.clock" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.weather" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.indicators" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.active-window" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.menu" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.system-update" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.network" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.microphone" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.agents" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.keyboard-layout" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.tray" 2>/dev/null || true

  RUN_AS_INSTALL_USER omarchy restart shell 2>/dev/null || true
fi

# Paradise Island Bar lives in Omarchy's bundled first-party plugin dir, so it
# is not covered by the ~/.config/omarchy/plugins sweep above. Remove it and
# let the shell fall back to the bundled bar before restarting again.
island_bar_dir="/usr/share/omarchy/shell/plugins/${CURRENT_USER}.island-bar"
if [[ -d "$island_bar_dir" ]]; then
  if run_privileged rm -rf "$island_bar_dir"; then
    if command -v omarchy &>/dev/null; then
      RUN_AS_INSTALL_USER omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
      RUN_AS_INSTALL_USER omarchy restart shell >/dev/null 2>&1 || true
    fi
  else
    printf 'Could not remove %s (needs sudo).\n' "$island_bar_dir"
    printf '  sudo rm -rf %s\n' "$island_bar_dir"
  fi
fi

# The stock system tray is deliberately not touched. The old drawer-reveal
# patch was disabled before it ever wrote a backup, so there is nothing to
# restore; install.sh no longer contains that code at all.

# SDDM: remove our own theme and restore the previous selection. The old
# installer patched /usr/share/sddm/themes/omarchy in place; repairing that here
# means even a machine that never re-runs install.sh gets a stock login screen.
if [[ -f "$REPO_DIR/lib/sddm.sh" ]]; then
  if run_privileged bash -c \
      '. "$1/lib/sddm.sh" && { sddm_theme_remove "/" && sddm_repair_legacy_theme "/"; }' _ "$REPO_DIR"; then
    printf 'Removed the Virtual Paradise SDDM theme.\n'
  else
    printf 'Could not remove the SDDM theme (needs sudo). If the login screen still shows Virtual Paradise, run:\n'
    printf '  sudo rm -rf /usr/share/sddm/themes/virtual-paradise\n'
    printf '  sudo rm -f /etc/sddm.conf.d/zz-virtual-paradise-theme.conf\n'
  fi
fi

# The autologin the installer may have turned off, so the login screen shows
# again.
autologin_conf="/etc/sddm.conf.d/autologin.conf"
if [[ -f "$autologin_conf.paradise.bak" ]]; then
  if run_privileged cp -a "$autologin_conf.paradise.bak" "$autologin_conf" 2>/dev/null; then
    run_privileged rm -f "$autologin_conf.paradise.bak" 2>/dev/null || true
    printf 'Restored the automatic login.\n'
  else
    printf 'Could not restore the automatic login (needs sudo).\n'
  fi
fi

# Plymouth: remove our own theme and restore the previous selection. The old
# installer replaced /usr/share/plymouth/themes/omarchy/omarchy.script and left
# ~330 generated PNGs in that package-owned directory; repairing that here
# means even a machine that never re-runs install.sh gets a stock boot splash.
if [[ -f "$REPO_DIR/lib/plymouth.sh" ]]; then
  if run_privileged bash -c \
      '. "$1/lib/plymouth.sh" && { plymouth_theme_remove "/" && plymouth_repair_legacy_theme "/"; }' _ "$REPO_DIR"; then
    printf 'Removed the Virtual Paradise Plymouth theme.\n'
    printf 'Rebuild the initramfs to drop the splash from the boot image: sudo mkinitcpio -P\n'
  else
    printf 'Could not remove the Plymouth theme (needs sudo). If the boot splash still shows Virtual Paradise, run:\n'
    printf '  sudo rm -rf /usr/share/plymouth/themes/virtual-paradise\n'
    printf '  sudo sed -i "s/^Theme=.*/Theme=omarchy/" /etc/plymouth/plymouthd.conf\n'
  fi
fi

# The Plymouth systemd drop-ins are ours. Remove them only when the file is
# byte-for-byte the one we shipped, so a local edit is never thrown away.
for plymouth_unit in plymouth-poweroff.service plymouth-reboot.service; do
  plymouth_dropin="/etc/systemd/system/$plymouth_unit.d/override.conf"
  [[ -f $plymouth_dropin ]] || continue
  if [[ -f "$REPO_DIR/plymouth/override.conf" ]] \
      && cmp -s "$REPO_DIR/plymouth/override.conf" "$plymouth_dropin"; then
    if run_privileged rm -f "$plymouth_dropin"; then
      run_privileged rmdir "/etc/systemd/system/$plymouth_unit.d" 2>/dev/null || true
      printf 'Removed the Plymouth systemd drop-in for %s.\n' "$plymouth_unit"
    else
      printf 'Could not remove %s (needs sudo).\n' "$plymouth_dropin"
    fi
  fi
done
run_privileged systemctl daemon-reload >/dev/null 2>&1 || true

# shell-default.json is the pristine Omarchy layout restored above and the only
# remaining copy of it. --keep-backups implies keeping that too, since without
# it a re-install has nothing to restore from.
if [[ $KEEP_BACKUPS -eq 0 ]]; then
  if [[ "$PURGE_DEFAULTS" -eq 1 ]]; then
    rm -f "$CONFIG_DIR/omarchy/shell-default.json" 2>/dev/null || true
  else
    printf 'Keeping shell-default.json (use --purge-defaults to remove it).\n'
  fi
fi

# Only the paths this script touched. A blanket chown over $CONFIG_DIR would
# also hand over unrelated files, including anything an Omarchy update or
# another tool installed as root.
if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  for owned_dir in "$BACKUP_DIR" "$CONFIG_DIR/omarchy" "$LOCAL_BIN" "$HOME/.local/state/virtual-paradise" "$HOME/.local/share/virtual-paradise"; do
    [[ -e "$owned_dir" ]] || continue
    chown -R "$CURRENT_USER:$CURRENT_USER" "$owned_dir" 2>/dev/null || true
  done
fi

printf 'Uninstalled Virtual☆Paradise. Backup snapshot: %s\n' "$BACKUP_DIR"
