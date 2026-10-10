#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="virtual-paradise"

if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  CURRENT_USER="$SUDO_USER"
  USER_HOME="$(getent passwd "$CURRENT_USER" | cut -d: -f6)"
  export HOME="$USER_HOME"
else
  CURRENT_USER="${USER:-$(id -un)}"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
BACKUP_DIR="$HOME/.local/state/virtual-paradise/uninstall-backup-$(date +%Y%m%d_%H%M%S)"

RUN_AS_INSTALL_USER() {
  if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    sudo -u "$CURRENT_USER" \
      HOME="$HOME" \
      XDG_CONFIG_HOME="$CONFIG_DIR" \
      XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$CURRENT_USER")}" \
      WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
      DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
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
    sudo "$@"
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
restore_or_remove "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell-default.json"
rm -f "$CONFIG_DIR/omarchy/shell-paradise.json" "$CONFIG_DIR/omarchy/extensions/paradise.json"
snapshot "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
rm -f "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"

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
      "$HOME/.local/state/virtual-paradise/plugin-versions.lock"
rm -rf "$HOME/.local/state/virtual-paradise/plugin-backups"
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
  Glitch.jpg Miku_missing.gif uninstall-virtual-paradise; do
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

# Files the installer edited in place, each with a .paradise.bak sibling.
for pair in \
  "$CONFIG_DIR/ghostty/config" \
  "$CONFIG_DIR/fcitx5/profile" \
  "$CONFIG_DIR/micro/settings.json"; do
  if [[ -f "$pair.paradise.bak" ]]; then
    cp "$pair.paradise.bak" "$pair"
    rm -f "$pair.paradise.bak"
    printf 'Restored %s\n' "${pair#"$HOME"/}"
  fi
done

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

# Restore the stock system tray if install.sh patched it for the drawer reveal.
tray_qml="/usr/share/omarchy/shell/plugins/bar/widgets/Tray.qml"
if [[ -f "$tray_qml.paradise.orig" ]]; then
  if run_privileged cp "$tray_qml.paradise.orig" "$tray_qml" 2>/dev/null; then
    run_privileged rm -f "$tray_qml.paradise.orig" 2>/dev/null || true
    printf 'Restored the stock system tray.\n'
  else
    printf 'Could not restore the stock system tray (needs sudo).\n'
  fi
fi

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
