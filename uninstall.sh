#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="virtual-paradise"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
BACKUP_DIR="$HOME/.local/state/virtual-paradise/uninstall-backup-$(date +%Y%m%d_%H%M%S)"

if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  CURRENT_USER="$SUDO_USER"
  USER_HOME="$(getent passwd "$CURRENT_USER" | cut -d: -f6)"
  export HOME="$USER_HOME"
else
  CURRENT_USER="${USER:-$(id -un)}"
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: %s [--keep-backups]\\n' "$0"
  printf 'Remove Virtual Paradise files and restore backed-up Omarchy defaults.\\n'
  exit 0
fi

if [[ "${1:-}" != "" && "${1:-}" != "--keep-backups" ]]; then
  printf 'Unknown option: %s\\n' "$1" >&2
  exit 2
fi

mkdir -p "$BACKUP_DIR"
printf 'Removing Virtual☆Paradise for %s...\\n' "$CURRENT_USER"

restore_or_remove() {
  local current="$1"
  local backup="$2"
  if [[ -e "$backup" || -L "$backup" ]]; then
    rm -rf "$current"
    mkdir -p "$(dirname "$current")"
    cp -a "$backup" "$current"
  else
    printf 'Preserving %s because no installer backup was found.\\n' "$current"
  fi
}

pkill -u "$CURRENT_USER" -f 'mpvpaper|virtual_matrix|momoisay|paradise_agent|rice-btop|rice-cava|rice-momoi|fastfetch-agent' 2>/dev/null || true

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

for file in \
  paradise-agent offline-agent rice_layout.sh rice cast_screen.sh cast-screen \
  toggle_cooler_boost.sh toggle_live_wallpaper.sh virtual_matrix virtual_matrix.py \
  momoisay sync_cava_theme.py format-docx format-docx-vn.py vn-docx \
  hypr_window_error_shake.sh hypr_window_error_restore.sh logout_splash.qml; do
  rm -f "$LOCAL_BIN/$file"
done

for file in "$CONFIG_DIR/cava/config" "$CONFIG_DIR/cava/config_bar" "$CONFIG_DIR/fastfetch/virtual-paradise.jsonc"; do
  rm -f "$file"
done

if [[ -f "$HOME/.config/gtk-4.0/gtk.css.bak_default" ]]; then
  cp "$HOME/.config/gtk-4.0/gtk.css.bak_default" "$HOME/.config/gtk-4.0/gtk.css"
fi
if [[ -f "$HOME/.config/gtk-3.0/gtk.css.bak_default" ]]; then
  cp "$HOME/.config/gtk-3.0/gtk.css.bak_default" "$HOME/.config/gtk-3.0/gtk.css"
fi

if command -v omarchy &>/dev/null; then
  omarchy plugin disable "crmne.hyprmoncfg" 2>/dev/null || true
  omarchy plugin disable "jankeesvw.notification-center" 2>/dev/null || true
  omarchy plugin enable "${CURRENT_USER}.monitor" 2>/dev/null || true
  omarchy plugin enable "omarchy.monitor" 2>/dev/null || true
  omarchy restart shell 2>/dev/null || true
fi

if [[ "${1:-}" != "--keep-backups" ]]; then
  rm -f "$CONFIG_DIR/omarchy/shell-default.json"
fi

printf 'Uninstalled Virtual☆Paradise. Backup snapshot: %s\\n' "$BACKUP_DIR"
