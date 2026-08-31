#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Full-Topping Rice & Universal Theme Automated Installer
# ==============================================================================
#  GitHub: https://github.com/llIIllIID0EIIllIIll/virtual-paradise
#  Compatible with: Omarchy Linux 4.0+ (Arch Linux + Hyprland)
# ==============================================================================

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="virtual-paradise"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CURRENT_USER="${USER:-$(id -un)}"
IS_HOOK=0

if [[ "$1" == "--hook" ]]; then
  IS_HOOK=1
fi

log() {
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "$@"
  fi
}

log "\e[36m=================================================================\e[0m"
log "\e[1;36m  🌸 Installing Virtual☆Paradise Rice for user '$CURRENT_USER' 🌸\e[0m"
log "\e[36m=================================================================\e[0m"

# 1. Prepare Target Directories
log "\e[32m[1/7] Creating configuration directories...\e[0m"
mkdir -p "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
mkdir -p "$CONFIG_DIR/omarchy/plugins"
mkdir -p "$CONFIG_DIR/omarchy/hooks/theme-set.d"
mkdir -p "$CONFIG_DIR/hypr"
mkdir -p "$CONFIG_DIR/cava"
mkdir -p "$LOCAL_BIN"

# 2. Install Custom Omarchy Bar Plugins with dynamic user detection
log "\e[32m[2/7] Installing custom status bar plugins for user '$CURRENT_USER'...\e[0m"
if [ -d "$REPO_DIR/plugins" ]; then
  for pdir in "$REPO_DIR"/plugins/*; do
    if [ -d "$pdir" ]; then
      base=$(basename "$pdir")
      plugin_suffix="${base#*.}"
      target_plugin_id="${CURRENT_USER}.${plugin_suffix}"
      target_dir="$CONFIG_DIR/omarchy/plugins/$target_plugin_id"
      
      mkdir -p "$target_dir"
      cp -r "$pdir"/* "$target_dir/"
      
      # Dynamically update moduleName, id, and IPC targets to match active username
      find "$target_dir" -type f \( -name "*.json" -o -name "*.qml" -o -name "*.js" \) -exec sed -i \
        -e "s/\"id\": \"[^\"]*\.${plugin_suffix}\"/\"id\": \"${target_plugin_id}\"/g" \
        -e "s/moduleName: \"[^\"]*\.${plugin_suffix}\"/moduleName: \"${target_plugin_id}\"/g" \
        -e "s/\"doe\./\"${CURRENT_USER}\./g" \
        -e "s/moduleName: \"doe\./moduleName: \"${CURRENT_USER}\./g" \
        -e "s/target: \"doe\./target: \"${CURRENT_USER}\./g" \
        -e "s/ipcTarget: \"doe\./ipcTarget: \"${CURRENT_USER}\./g" \
        -e "s/firstPartyServiceFor(\"doe\./firstPartyServiceFor(\"${CURRENT_USER}\./g" {} +
    fi
  done
fi

# 3. Install Status Bar Layout (shell.json) with dynamic user detection
log "\e[32m[3/7] Installing Omarchy status bar layout for user '$CURRENT_USER'...\e[0m"
if [ -f "$CONFIG_DIR/omarchy/shell.json" ] && [ ! -f "$CONFIG_DIR/omarchy/shell.json.bak" ]; then
  cp "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json.bak.$BACKUP_TIMESTAMP"
fi
if [ -f "$REPO_DIR/shell/shell.json" ]; then
  sed -e "s/\"doe\./\"${CURRENT_USER}\./g" \
      -e "s/\"centerAnchor\": \"doe\./\"centerAnchor\": \"${CURRENT_USER}\./g" \
      "$REPO_DIR/shell/shell.json" > "$CONFIG_DIR/omarchy/shell.json"
fi

# 4. Install Hyprland Configuration
log "\e[32m[4/7] Installing Hyprland look'n'feel, bindings, monitors & input configs...\e[0m"
if [ -d "$REPO_DIR/hypr" ]; then
  for file in "$REPO_DIR"/hypr/*.lua; do
    if [ -f "$file" ]; then
      base=$(basename "$file")
      if [ -f "$CONFIG_DIR/hypr/$base" ] && [ ! -f "$CONFIG_DIR/hypr/$base.bak" ]; then
        cp "$CONFIG_DIR/hypr/$base" "$CONFIG_DIR/hypr/$base.bak.$BACKUP_TIMESTAMP"
      fi
      cp "$file" "$CONFIG_DIR/hypr/$base"
    fi
  done
fi

# 5. Install Helper Scripts & Tools
log "\e[32m[5/7] Installing helper scripts to $LOCAL_BIN...\e[0m"
if [ -d "$REPO_DIR/bin" ]; then
  cp -r "$REPO_DIR"/bin/* "$LOCAL_BIN/"
  chmod +x "$LOCAL_BIN"/* 2>/dev/null || true
fi

# Install Cava audio visualizer profile
if [ -f "$REPO_DIR/cava/config_bar" ]; then
  cp "$REPO_DIR/cava/config_bar" "$CONFIG_DIR/cava/config_bar"
fi
if [ -f "$REPO_DIR/cava/config" ]; then
  cp "$REPO_DIR/cava/config" "$CONFIG_DIR/cava/config"
fi

# 6. Install Theme Assets into ~/.config/omarchy/themes/virtual-paradise (if repo is external)
log "\e[32m[6/7] Installing theme assets & backgrounds...\e[0m"
if [[ "$REPO_DIR" != "$CONFIG_DIR/omarchy/themes/$THEME_NAME" ]]; then
  cp -r "$REPO_DIR"/* "$CONFIG_DIR/omarchy/themes/$THEME_NAME/" 2>/dev/null || true
fi

# Install post-theme-set hook to maintain synchronization
cat << 'EOF' > "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
#!/bin/bash
THEME_NAME="$1"
if [[ "$THEME_NAME" == "virtual-paradise" ]]; then
  if [[ -f "$HOME/.config/omarchy/themes/virtual-paradise/install.sh" ]]; then
    bash "$HOME/.config/omarchy/themes/virtual-paradise/install.sh" --hook >/dev/null 2>&1 &
  fi
fi
EOF
chmod +x "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"

# 7. Configure ~/.bashrc for Universal Error Warning Border Hook
log "\e[32m[7/7] Configuring shell environment & dynamic error hooks...\e[0m"
if [ -f "$HOME/.bashrc" ]; then
  if ! grep -q "PATH=\"\$HOME/.local/bin:\$PATH\"" "$HOME/.bashrc" && ! grep -q "PATH=\"/home/.*/.local/bin:\$PATH\"" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi

  if ! grep -q "__omarchy_error_border_hook" "$HOME/.bashrc"; then
    cat << 'EOF' >> "$HOME/.bashrc"

# ==============================================================================
#  CYBERPUNK WINDOW ERROR SHAKE & BLAZING NEON RED GLOW HOOK
# ==============================================================================
__omarchy_last_err_state=0

__omarchy_error_border_hook() {
  local exit_code=$?
  if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    if [[ $exit_code -ne 0 && $__omarchy_last_err_state -eq 0 ]]; then
      __omarchy_last_err_state=1
      (~/.local/bin/hypr_window_error_shake.sh &>/dev/null &)
    elif [[ $exit_code -eq 0 && $__omarchy_last_err_state -ne 0 ]]; then
      __omarchy_last_err_state=0
      (~/.local/bin/hypr_window_error_restore.sh &>/dev/null &)
    fi
  fi
  return $exit_code
}

if [[ "$PROMPT_COMMAND" != *"__omarchy_error_border_hook"* ]]; then
  PROMPT_COMMAND="__omarchy_error_border_hook${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
EOF
  fi
fi

# 8. Apply Theme & Reload Everything
log "\e[1;35mApplying Virtual☆Paradise theme...\e[0m"
if command -v omarchy &>/dev/null; then
  omarchy theme set "$THEME_NAME" 2>/dev/null || true
  omarchy restart shell 2>/dev/null || true
fi

if command -v hyprctl &>/dev/null; then
  hyprctl reload 2>/dev/null || true
fi

log "\e[1;32m"
log "✨ Virtual☆Paradise Theme & Rice successfully installed for '$CURRENT_USER'!"
log "✨ Everything is active and ready to enjoy."
log "\e[0m"
