#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Full-Topping Rice & Universal Theme Automated Installer
# ==============================================================================
#  GitHub: https://github.com/llIIllIID0EIIllIIll/virtual-paradise
#  Compatible with: Omarchy Linux 4.0+ (Arch Linux + Hyprland)
# ==============================================================================

set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="virtual-paradise"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CURRENT_USER="${USER:-$(id -un)}"
IS_HOOK=0

if [[ "$1" == "--hook" ]]; then
  IS_HOOK=1
fi

# Color helpers
C_CYAN="\033[38;2;0;245;212m"
C_GREEN="\033[38;2;0;255;136m"
C_PINK="\033[38;2;255;183;213m"
C_RED="\033[38;2;255;0;85m"
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"

log_step() {
  local num="$1"
  local total="$2"
  local msg="$3"
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "${C_CYAN}[${num}/${total}]${C_RESET} ${C_BOLD}${msg}${C_RESET}"
  fi
}

log_sub() {
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "  ${C_GREEN}➔${C_RESET} ${C_DIM}$*${C_RESET}"
  fi
}

log_warn() {
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "  ${C_PINK}⚠${C_RESET} $*"
  fi
}

log_info() {
  if [[ $IS_HOOK -eq 0 ]]; then
    echo -e "$*"
  fi
}

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
if [[ $IS_HOOK -eq 0 ]]; then
  echo -e "${C_CYAN}===================================================================${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}  🌸 Virtual☆Paradise${C_RESET} ${C_GREEN}— Cyberpunk Rice & Theme Installer${C_RESET}"
  echo -e "${C_DIM}  Target User: ${C_PINK}${CURRENT_USER}${C_RESET} ${C_DIM}| Platform: Omarchy / Hyprland${C_RESET}"
  echo -e "${C_CYAN}===================================================================${C_RESET}"
fi

# ------------------------------------------------------------------------------
# 1. Check & Install Missing System Dependencies
# ------------------------------------------------------------------------------
log_step "1" "9" "Checking and installing required system packages..."

CHECK_AND_INSTALL_PACKAGES() {
  local REQUIRED_PKGS=(
    "cava"
    "btop"
    "fastfetch"
    "micro"
    "ripgrep"
    "fd"
    "mpv"
    "qt6-multimedia"
    "qt6-multimedia-ffmpeg"
    "libnotify"
    "rsync"
    "wl-clipboard"
    "ncurses"
  )
  local AUR_PKGS=(
    "mpvpaper"
  )

  local TO_INSTALL=()
  for pkg in "${REQUIRED_PKGS[@]}"; do
    if command -v pacman &>/dev/null; then
      if ! pacman -Qi "$pkg" &>/dev/null; then
        TO_INSTALL+=("$pkg")
      fi
    fi
  done

  for pkg in "${AUR_PKGS[@]}"; do
    if ! command -v "$pkg" &>/dev/null; then
      if command -v pacman &>/dev/null && ! pacman -Qi "$pkg" &>/dev/null; then
        TO_INSTALL+=("$pkg")
      fi
    fi
  done

  if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
    log_sub "Installing missing dependencies: ${TO_INSTALL[*]}"
    if command -v yay &>/dev/null; then
      yay -S --needed --noconfirm "${TO_INSTALL[@]}" 2>/dev/null || true
    elif command -v paru &>/dev/null; then
      paru -S --needed --noconfirm "${TO_INSTALL[@]}" 2>/dev/null || true
    elif command -v sudo &>/dev/null && command -v pacman &>/dev/null; then
      sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}" 2>/dev/null || true
    else
      log_warn "Please install missing packages manually: ${TO_INSTALL[*]}"
    fi
  else
    log_sub "All required packages are satisfied"
  fi
}

if [[ $IS_HOOK -eq 0 ]]; then
  CHECK_AND_INSTALL_PACKAGES
fi

# ------------------------------------------------------------------------------
# 2. Prepare Target Directories
# ------------------------------------------------------------------------------
log_step "2" "9" "Creating configuration and runtime directories..."
mkdir -p "$CONFIG_DIR/omarchy/themes/$THEME_NAME/backgrounds"
mkdir -p "$CONFIG_DIR/omarchy/plugins"
mkdir -p "$CONFIG_DIR/omarchy/hooks/theme-set.d"
mkdir -p "$CONFIG_DIR/omarchy/extensions"
mkdir -p "$CONFIG_DIR/hypr"
mkdir -p "$CONFIG_DIR/cava"
mkdir -p "$CONFIG_DIR/btop/themes"
mkdir -p "$CONFIG_DIR/fastfetch"
mkdir -p "$LOCAL_BIN"
log_sub "Directories verified under $CONFIG_DIR and $LOCAL_BIN"

# ------------------------------------------------------------------------------
# 3. Install Custom Omarchy Bar Plugins with dynamic user detection
# ------------------------------------------------------------------------------
log_step "3" "9" "Installing custom Quickshell plugins for user '$CURRENT_USER'..."
if [[ -d "$REPO_DIR/plugins" ]]; then
  for pdir in "$REPO_DIR"/plugins/*; do
    if [[ -d "$pdir" ]]; then
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
  log_sub "Synchronized and calibrated $(ls -d "$REPO_DIR"/plugins/* | wc -l) plugins"
fi

# ------------------------------------------------------------------------------
# 4. Install Status Bar Layout (shell.json) & Menu Extensions
# ------------------------------------------------------------------------------
log_step "4" "9" "Installing status bar layout (transparency off) & menu extensions..."
if [[ -f "$CONFIG_DIR/omarchy/shell.json" ]] && [[ ! -f "$CONFIG_DIR/omarchy/shell.json.bak" ]]; then
  cp "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json.bak.$BACKUP_TIMESTAMP"
fi
if [[ -f "$REPO_DIR/shell/shell.json" ]]; then
  sed -e "s/\"doe\./\"${CURRENT_USER}\./g" \
      -e "s/\"centerAnchor\": \"doe\./\"centerAnchor\": \"${CURRENT_USER}\./g" \
      "$REPO_DIR/shell/shell.json" > "$CONFIG_DIR/omarchy/shell.json"
  log_sub "Updated ~/.config/omarchy/shell.json with transparency off"
fi

# Install Virtual☆Paradise Quick Actions into omarchy-menu.jsonc
cat << 'EOF' > "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc"
{
  // Virtual☆Paradise Quick Actions Menu
  "paradise": {
    "icon": "★",
    "label": "Virtual☆Paradise"
  },
  "paradise.rice": {
    "icon": "󰨞",
    "label": "Rice Layout (5-Terminals)",
    "description": "Fastfetch, btop, momoisay, cava, unimatrix",
    "action": "bash -c ~/.local/bin/rice_layout.sh"
  },
  "paradise.matrix": {
    "icon": "󰘧",
    "label": "Tri-Color Gradient Matrix",
    "description": "Miku Cyan -> Hacker Green -> Sakura Pink",
    "action": "ghostty -e ~/.local/bin/virtual_matrix"
  },
  "paradise.wallpaper": {
    "icon": "",
    "label": "Next Theme Wallpaper",
    "description": "Cycle through wallpapers",
    "action": "omarchy theme bg next"
  },
  "paradise.livewallpaper": {
    "icon": "󰸌",
    "label": "Toggle Live Video Wallpaper",
    "description": "Play/pause Miku 1080p live wallpaper",
    "action": "bash -c ~/.local/bin/toggle_live_wallpaper.sh"
  },
  "paradise.cooler": {
    "icon": "󰈐",
    "label": "Toggle Cooler Boost",
    "description": "Turn fan cooling on/off",
    "action": "bash -c ~/.local/bin/toggle_cooler_boost.sh"
  }
}
EOF
log_sub "Installed Quick Actions menu extensions"

# ------------------------------------------------------------------------------
# 5. Install Hyprland Look'n'Feel & Keybindings
# ------------------------------------------------------------------------------
log_step "5" "9" "Installing Hyprland look'n'feel, bindings, input & autostart configs..."
if [[ -d "$REPO_DIR/hypr" ]]; then
  for file in "$REPO_DIR"/hypr/*.lua; do
    if [[ -f "$file" ]]; then
      base=$(basename "$file")
      if [[ -f "$CONFIG_DIR/hypr/$base" ]] && [[ ! -f "$CONFIG_DIR/hypr/$base.bak" ]]; then
        cp "$CONFIG_DIR/hypr/$base" "$CONFIG_DIR/hypr/$base.bak.$BACKUP_TIMESTAMP"
      fi
      cp "$file" "$CONFIG_DIR/hypr/$base"
    fi
  done
  log_sub "Installed Hyprland Lua configurations"
fi

if [[ -f "$REPO_DIR/hyprland.conf" ]]; then
  cp "$REPO_DIR/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 6. Install Helper Scripts & Binaries
# ------------------------------------------------------------------------------
log_step "6" "9" "Installing binaries & CLI helper tools to $LOCAL_BIN..."
if [[ -d "$REPO_DIR/bin" ]]; then
  cp -r "$REPO_DIR"/bin/* "$LOCAL_BIN/"
  chmod +x "$LOCAL_BIN"/* 2>/dev/null || true
  log_sub "Installed helper tools (rice_layout, momoisay, toggle_live_wallpaper, etc.)"
fi

# ------------------------------------------------------------------------------
# 7. Install Component Themes (Btop, Cava, Fastfetch, Micro)
# ------------------------------------------------------------------------------
log_step "7" "9" "Installing Cava, Btop, Fastfetch & Micro editor theme profiles..."

# Cava
if [[ -f "$REPO_DIR/cava/config_bar" ]]; then
  cp "$REPO_DIR/cava/config_bar" "$CONFIG_DIR/cava/config_bar"
elif [[ -f "$REPO_DIR/cava_theme" ]]; then
  cp "$REPO_DIR/cava_theme" "$CONFIG_DIR/cava/config_bar"
fi
if [[ -f "$REPO_DIR/cava/config" ]]; then
  cp "$REPO_DIR/cava/config" "$CONFIG_DIR/cava/config"
fi

# Btop
if [[ -f "$REPO_DIR/btop.theme" ]]; then
  cp "$REPO_DIR/btop.theme" "$CONFIG_DIR/btop/themes/virtual-paradise.theme"
fi

# Fastfetch
if [[ -d "$REPO_DIR/fastfetch" ]]; then
  cp -r "$REPO_DIR/fastfetch"/* "$CONFIG_DIR/fastfetch/"
fi

# Micro Editor Rice
if [[ -d "$REPO_DIR/micro" ]]; then
  mkdir -p "$CONFIG_DIR/micro/colorschemes"
  if [[ -f "$REPO_DIR/micro/settings.json" ]]; then
    cp "$REPO_DIR/micro/settings.json" "$CONFIG_DIR/micro/settings.json"
  fi
  if [[ -d "$REPO_DIR/micro/colorschemes" ]]; then
    cp -r "$REPO_DIR/micro/colorschemes"/* "$CONFIG_DIR/micro/colorschemes/"
  fi
fi
log_sub "Component themes installed (Cava, Btop, Fastfetch, Micro)"

# ------------------------------------------------------------------------------
# 8. Install Theme Assets & Backgrounds
# ------------------------------------------------------------------------------
log_step "8" "9" "Installing theme assets, live wallpapers & hooks..."
if [[ "$REPO_DIR" != "$CONFIG_DIR/omarchy/themes/$THEME_NAME" ]]; then
  rsync -a --delete \
    --exclude='.git' \
    --exclude='preview_frame.jpg' \
    --exclude='preview_rotated.jpg' \
    "$REPO_DIR"/ "$CONFIG_DIR/omarchy/themes/$THEME_NAME/" 2>/dev/null || true
fi

# Post-theme-set hook
cat << 'EOF' > "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
#!/bin/bash
THEME_NAME="$1"
if [[ "$THEME_NAME" == "virtual-paradise" ]]; then
  if [[ -f "$HOME/.config/omarchy/themes/virtual-paradise/install.sh" ]]; then
    bash "$HOME/.config/omarchy/themes/virtual-paradise/install.sh" --hook >/dev/null 2>&1 &
  fi
  if [[ -x "$HOME/.local/bin/toggle_live_wallpaper.sh" ]]; then
    (sleep 0.3; "$HOME/.local/bin/toggle_live_wallpaper.sh" init >/dev/null 2>&1 &)
  fi
fi
EOF
chmod +x "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
log_sub "Theme assets & automatic synchronization hooks ready"

# ------------------------------------------------------------------------------
# 9. Configure Shell Environment (Zsh & Bash) & Error Hooks
# ------------------------------------------------------------------------------
log_step "9" "9" "Configuring shell environment, aliases (ff, ffa) & error shake hooks..."

configure_shell_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  # Ensure $LOCAL_BIN is in PATH
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$file" && ! grep -q 'PATH=.*/\.local/bin' "$file"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$file"
  fi

  # Add fastfetch aliases
  if ! grep -q "alias ff=" "$file"; then
    echo "alias ff='fastfetch'" >> "$file"
  fi
  if ! grep -q "alias ffa=" "$file"; then
    echo "alias ffa='fastfetch --logo ~/.config/fastfetch/logo_anime.txt'" >> "$file"
  fi

  # Add cyberpunk error border hook
  if ! grep -q "__omarchy_error_border_hook" "$file"; then
    cat << 'EOF' >> "$file"

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
}

configure_shell_file "$HOME/.bashrc"
configure_shell_file "$HOME/.zshrc"

if command -v zsh &>/dev/null && [[ -f "$HOME/.zshrc" ]]; then
  zsh -c "zcompile ~/.zshrc" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# Activation & Live Reload
# ------------------------------------------------------------------------------
if [[ $IS_HOOK -eq 0 ]]; then
  log_info "\n${C_BOLD}${C_PINK}Applying Virtual☆Paradise theme & reloading compositor...${C_RESET}"
  
  # Invalidate theme switcher preview cache
  rm -rf "$CACHE_DIR/omarchy/theme-selector" 2>/dev/null || true

  if command -v omarchy &>/dev/null; then
    omarchy theme set "$THEME_NAME" 2>/dev/null || true
    omarchy restart shell 2>/dev/null || true
  fi

  if command -v hyprctl &>/dev/null; then
    hyprctl reload 2>/dev/null || true
  fi

  # Auto-trigger SUPER + ALT + UP: Initialize and launch live video wallpaper immediately
  if [[ -x "$LOCAL_BIN/toggle_live_wallpaper.sh" ]]; then
    log_sub "Triggering SUPER + ALT + UP: Initializing Live Video Wallpaper..."
    (sleep 0.4; "$LOCAL_BIN/toggle_live_wallpaper.sh" init >/dev/null 2>&1 &)
  fi

  echo -e "\n${C_BOLD}${C_GREEN}✨ Virtual☆Paradise Theme & Rice successfully installed for '${CURRENT_USER}'!${C_RESET}"
  echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────${C_RESET}"
  echo -e " ${C_BOLD}Useful shortcuts:${C_RESET}"
  echo -e "   ${C_GREEN}SUPER + Q${C_RESET}             ➔ Launch 5-terminal Rice layout"
  echo -e "   ${C_GREEN}SUPER + ALT + UP${C_RESET}      ➔ Toggle Live Video / Static Wallpaper"
  echo -e "   ${C_GREEN}SUPER + ALT + RIGHT${C_RESET}   ➔ Next Live Wallpaper (Portal Transition)"
  echo -e "   ${C_GREEN}SUPER + ALT + LEFT${C_RESET}    ➔ Prev Live Wallpaper (Portal Transition)"
  echo -e "   ${C_GREEN}SUPER + N${C_RESET}             ➔ Cycle next wallpaper"
  echo -e "   ${C_GREEN}SUPER + C${C_RESET}             ➔ Toggle Cooler Boost fan cooling"
  echo -e "   ${C_GREEN}ffa${C_RESET}                   ➔ Launch Fastfetch with high-res Anime Braille logo"
  echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────${C_RESET}\n"
fi
