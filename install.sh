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

echo -e "\e[36m=================================================================\e[0m"
echo -e "\e[1;36m  🌸 Installing Virtual☆Paradise Rice & Universal Theme for Omarchy 🌸\e[0m"
echo -e "\e[36m=================================================================\e[0m"

# 1. Prepare Target Directories
echo -e "\e[32m[1/7] Creating configuration directories...\e[0m"
mkdir -p "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
mkdir -p "$CONFIG_DIR/omarchy/plugins"
mkdir -p "$CONFIG_DIR/hypr"
mkdir -p "$CONFIG_DIR/cava"
mkdir -p "$LOCAL_BIN"

# 2. Install Theme Assets
echo -e "\e[32m[2/7] Installing theme assets & backgrounds...\e[0m"
cp -r "$REPO_DIR"/* "$CONFIG_DIR/omarchy/themes/$THEME_NAME/" 2>/dev/null || true
# Clean up git artifacts in theme folder
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME/.git"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME/plugins"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME/hypr"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME/shell"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME/bin"
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME/cava"
rm -f "$CONFIG_DIR/omarchy/themes/$THEME_NAME/install.sh"

# 3. Install Custom Omarchy Bar Plugins
echo -e "\e[32m[3/7] Installing custom status bar plugins & dock...\e[0m"
if [ -d "$REPO_DIR/plugins" ]; then
  cp -r "$REPO_DIR"/plugins/* "$CONFIG_DIR/omarchy/plugins/"
fi

# 4. Install Status Bar Layout (shell.json)
echo -e "\e[32m[4/7] Installing Omarchy status bar layout...\e[0m"
if [ -f "$CONFIG_DIR/omarchy/shell.json" ]; then
  cp "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json.bak.$BACKUP_TIMESTAMP"
fi
if [ -f "$REPO_DIR/shell/shell.json" ]; then
  cp "$REPO_DIR/shell/shell.json" "$CONFIG_DIR/omarchy/shell.json"
fi

# 5. Install Hyprland Configuration
echo -e "\e[32m[5/7] Installing Hyprland look'n'feel, bindings, monitors & input configs...\e[0m"
if [ -d "$REPO_DIR/hypr" ]; then
  for file in "$REPO_DIR"/hypr/*.lua; do
    if [ -f "$file" ]; then
      base=$(basename "$file")
      if [ -f "$CONFIG_DIR/hypr/$base" ]; then
        cp "$CONFIG_DIR/hypr/$base" "$CONFIG_DIR/hypr/$base.bak.$BACKUP_TIMESTAMP"
      fi
      cp "$file" "$CONFIG_DIR/hypr/$base"
    fi
  done
fi

# 6. Install Helper Scripts & Tools
echo -e "\e[32m[6/7] Installing helper scripts to $LOCAL_BIN...\e[0m"
if [ -d "$REPO_DIR/bin" ]; then
  cp -r "$REPO_DIR"/bin/* "$LOCAL_BIN/"
  chmod +x "$LOCAL_BIN"/* 2>/dev/null || true
fi

# Install Cava audio visualizer profile
if [ -f "$REPO_DIR/cava/config_bar" ]; then
  cp "$REPO_DIR/cava/config_bar" "$CONFIG_DIR/cava/config_bar"
fi

# 7. Configure ~/.bashrc for Universal Error Warning Border Hook
echo -e "\e[32m[7/7] Configuring shell environment & dynamic error hooks...\e[0m"
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
echo -e "\e[1;35mApplying Virtual☆Paradise theme...\e[0m"
if command -v omarchy &>/dev/null; then
  omarchy theme set "$THEME_NAME" 2>/dev/null || true
  omarchy restart shell 2>/dev/null || true
fi

if command -v hyprctl &>/dev/null; then
  hyprctl reload 2>/dev/null || true
fi

echo -e "\e[1;32m"
echo "✨ Virtual☆Paradise Theme & Rice successfully installed!"
echo "✨ Everything is active and ready to enjoy."
echo -e "\e[0m"
