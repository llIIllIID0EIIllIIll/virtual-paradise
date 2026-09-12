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
  printf 'Usage: %s [--keep-backups]\n' "$0"
  printf 'Remove Virtual Paradise files and restore backed-up Omarchy defaults.\n'
  exit 0
fi

if [[ "${1:-}" != "" && "${1:-}" != "--keep-backups" ]]; then
  printf 'Unknown option: %s\n' "$1" >&2
  exit 2
fi

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

# Stop theme processes
pkill -u "$CURRENT_USER" -f 'mpvpaper|virtual_matrix|momoisay|paradise_agent|rice-btop|rice-cava|rice-momoi|fastfetch-agent' 2>/dev/null || true

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

restore_or_remove "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell-default.json"
rm -f "$CONFIG_DIR/omarchy/shell-paradise.json" "$CONFIG_DIR/omarchy/extensions/paradise.json"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
rm -f "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"

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

if [[ -f "$HOME/.config/gtk-4.0/gtk.css.bak_default" ]]; then
  cp "$HOME/.config/gtk-4.0/gtk.css.bak_default" "$HOME/.config/gtk-4.0/gtk.css"
else
  rm -f "$HOME/.config/gtk-4.0/gtk.css"
fi
if [[ -f "$HOME/.config/gtk-3.0/gtk.css.bak_default" ]]; then
  cp "$HOME/.config/gtk-3.0/gtk.css.bak_default" "$HOME/.config/gtk-3.0/gtk.css"
else
  rm -f "$HOME/.config/gtk-3.0/gtk.css"
fi

if command -v omarchy &>/dev/null; then
  # Disable Virtual Paradise plugins
  RUN_AS_INSTALL_USER omarchy plugin disable "mscurtescu.island-bar" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "crmne.hyprmoncfg" 2>/dev/null || true
  RUN_AS_INSTALL_USER omarchy plugin disable "io.github.jeffcortez23.omarchy-projector-cast" 2>/dev/null || true
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

if [[ "${1:-}" != "--keep-backups" ]]; then
  rm -f "$CONFIG_DIR/omarchy/shell-default.json" 2>/dev/null || true
fi

if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  chown -R "$CURRENT_USER:$CURRENT_USER" "$BACKUP_DIR" "$CONFIG_DIR" "$LOCAL_BIN" "$HOME/.local" 2>/dev/null || true
fi

printf 'Uninstalled Virtual☆Paradise. Backup snapshot: %s\n' "$BACKUP_DIR"
