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
ENABLE_BOOT=1
BOOT_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --hook)
      IS_HOOK=1
      ENABLE_BOOT=0
      ;;
    --no-boot)
      ENABLE_BOOT=0
      ;;
    --boot-only)
      BOOT_ONLY=1
      ;;
  esac
done

# Color helpers
C_CYAN="\033[38;2;0;245;212m"
C_GREEN="\033[38;2;0;255;136m"
C_PINK="\033[38;2;255;183;213m"
C_RED="\033[38;2;255;0;85m"
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"

TOTAL_STEPS="10"

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
  if command -v python3 &>/dev/null && [[ -f "$REPO_DIR/bin/paradise_agent.py" ]]; then
    python3 -c "import sys; sys.path.insert(0, '$REPO_DIR/bin'); import paradise_agent; print(paradise_agent.get_banner_art())" 2>/dev/null || true
  fi
  echo -e "${C_CYAN}===================================================================================================================${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}  🌸 Virtual☆Paradise${C_RESET} ${C_GREEN}— Cyberpunk Rice & Theme Installer${C_RESET}"
  echo -e "${C_DIM}  Target User: ${C_PINK}${CURRENT_USER}${C_RESET} ${C_DIM}| Platform: Omarchy / Hyprland${C_RESET}"
  echo -e "${C_CYAN}===================================================================================================================${C_RESET}"
fi

# ------------------------------------------------------------------------------
# Boot & Shutdown Animations Setup Function (Shared by full and --boot-only mode)
# ------------------------------------------------------------------------------
INSTALL_BOOT_ANIMATIONS() {
  log_step "9" "$TOTAL_STEPS" "Configuring Plymouth Boot Animation, SDDM Display Manager & UKI Kernel..."

  local can_sudo=0
  local SUDO_CMD=""

  if (( EUID == 0 )); then
    can_sudo=1
    SUDO_CMD=""
  elif command -v sudo &>/dev/null && sudo -v 2>/dev/null; then
    can_sudo=1
    SUDO_CMD="sudo"
  elif command -v sudo &>/dev/null; then
    log_info "  ${C_PINK}🔑 Requesting sudo permission for system-wide Plymouth and SDDM setup...${C_RESET}"
    if sudo -v; then
      can_sudo=1
      SUDO_CMD="sudo"
    fi
  fi

  if [[ $can_sudo -eq 1 ]]; then
    # 1. SDDM Setup
    local sddm_theme_dir="/usr/share/sddm/themes/omarchy"
    if [[ -d "$sddm_theme_dir" ]]; then
      if [[ -f "$REPO_DIR/sddm/Main.qml" ]]; then
        $SUDO_CMD cp "$REPO_DIR/sddm/Main.qml" "$sddm_theme_dir/Main.qml"
      fi
      if [[ -f "$REPO_DIR/backgrounds/Miku_animated_full.gif" ]]; then
        $SUDO_CMD cp "$REPO_DIR/backgrounds/Miku_animated_full.gif" "$sddm_theme_dir/Miku_animated_full.gif"
      fi
      log_sub "Configured SDDM login theme with animated Miku_animated_full.gif"
    fi

    # 2. Plymouth Theme Setup
    local plymouth_theme_dir="/usr/share/plymouth/themes/omarchy"
    if [[ -d "$plymouth_theme_dir" ]]; then
      if [[ -f "$REPO_DIR/plymouth/omarchy.script" ]]; then
        $SUDO_CMD cp "$REPO_DIR/plymouth/omarchy.script" "$plymouth_theme_dir/omarchy.script"
      fi

      # Extract intro frames (259 frames) if missing
      if [[ ! -f "$plymouth_theme_dir/intro-259.png" ]] && [[ -f "$REPO_DIR/backgrounds/Miku_animated_full.gif" ]]; then
        log_sub "Extracting 259 frames from Miku_animated_full.gif for Plymouth..."
        $SUDO_CMD ffmpeg -y -loglevel error -i "$REPO_DIR/backgrounds/Miku_animated_full.gif" -vf "scale=1920:1080" "$plymouth_theme_dir/intro-%d.png"
      fi

      # Extract outro frames (72 frames) if missing
      if [[ ! -f "$plymouth_theme_dir/outro-72.png" ]] && [[ -f "$REPO_DIR/backgrounds/Miku_missing.gif" ]]; then
        log_sub "Extracting 72 frames from Miku_missing.gif for Plymouth..."
        $SUDO_CMD ffmpeg -y -loglevel error -i "$REPO_DIR/backgrounds/Miku_missing.gif" -vf "scale=1920:1080" "$plymouth_theme_dir/outro-%d.png"
      fi

      # Fallback single frame images
      if [[ -f "$plymouth_theme_dir/intro-1.png" ]]; then
        $SUDO_CMD cp "$plymouth_theme_dir/intro-1.png" "$plymouth_theme_dir/background.png" 2>/dev/null || true
      fi
      if [[ -f "$plymouth_theme_dir/outro-1.png" ]]; then
        $SUDO_CMD cp "$plymouth_theme_dir/outro-1.png" "$plymouth_theme_dir/background-shutdown.png" 2>/dev/null || true
      fi

      # Systemd overrides for instant Plymouth handover (no SDDM delay)
      $SUDO_CMD mkdir -p /etc/systemd/system/plymouth-poweroff.service.d /etc/systemd/system/plymouth-reboot.service.d
      if [[ -f "$REPO_DIR/plymouth/override.conf" ]]; then
        $SUDO_CMD cp "$REPO_DIR/plymouth/override.conf" "/etc/systemd/system/plymouth-poweroff.service.d/override.conf"
        $SUDO_CMD cp "$REPO_DIR/plymouth/override.conf" "/etc/systemd/system/plymouth-reboot.service.d/override.conf"
        $SUDO_CMD systemctl daemon-reload
      fi

      $SUDO_CMD plymouth-set-default-theme omarchy 2>/dev/null || true
      log_sub "Configured Plymouth theme with instant lazy-loading animation engine"

      # Rebuild UKI / initramfs
      if command -v limine-mkinitcpio &>/dev/null; then
        log_sub "Rebuilding UKI image with limine-mkinitcpio..."
        $SUDO_CMD limine-mkinitcpio >/dev/null 2>&1 || log_warn "limine-mkinitcpio failed; check boot partition."
      elif command -v mkinitcpio &>/dev/null; then
        log_sub "Rebuilding initramfs with mkinitcpio -P..."
        $SUDO_CMD mkinitcpio -P >/dev/null 2>&1 || log_warn "mkinitcpio failed."
      fi
    fi
  else
    log_warn "Sudo privileges not available. Skipping system-wide Plymouth/SDDM setup."
    log_warn "Run 'sudo ./install.sh --boot-only' to enable boot & shutdown animations."
  fi
}

if [[ $BOOT_ONLY -eq 1 ]]; then
  INSTALL_BOOT_ANIMATIONS
  echo -e "\n${C_BOLD}${C_GREEN}✨ Boot and shutdown animations updated successfully!${C_RESET}\n"
  exit 0
fi

# ------------------------------------------------------------------------------
# 1. Check & Install Missing System Dependencies
# ------------------------------------------------------------------------------
log_step "1" "$TOTAL_STEPS" "Checking and installing required system packages..."

CHECK_AND_INSTALL_PACKAGES() {
  local REQUIRED_PKGS=(
    "cava"
    "btop"
    "fastfetch"
    "micro"
    "fortune-mod"
    "cowsay"
    "ripgrep"
    "fd"
    "mpv"
    "qt6-multimedia"
    "qt6-multimedia-ffmpeg"
    "libnotify"
    "rsync"
    "wl-clipboard"
    "ncurses"
    "ffmpeg"
    "tela-circle-icon-theme-all"
    "ollama"
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
log_step "2" "$TOTAL_STEPS" "Creating configuration and runtime directories..."
mkdir -p "$CONFIG_DIR/omarchy/themes/$THEME_NAME/backgrounds"
mkdir -p "$CONFIG_DIR/omarchy/plugins"
mkdir -p "$CONFIG_DIR/omarchy/hooks/theme-set.d"
mkdir -p "$CONFIG_DIR/omarchy/extensions"
mkdir -p "$CONFIG_DIR/hypr"
mkdir -p "$CONFIG_DIR/cava"
mkdir -p "$CONFIG_DIR/btop/themes"
mkdir -p "$CONFIG_DIR/fastfetch"
mkdir -p "$CONFIG_DIR/micro/colorschemes"
mkdir -p "$LOCAL_BIN"
mkdir -p "$HOME/.local/state/virtual-paradise"
log_sub "Directories verified under $CONFIG_DIR and $LOCAL_BIN"

# ------------------------------------------------------------------------------
# 3. Install Custom Omarchy Bar Plugins with dynamic user detection
# ------------------------------------------------------------------------------
log_step "3" "$TOTAL_STEPS" "Installing custom Quickshell plugins for user '$CURRENT_USER'..."
if [[ -d "$REPO_DIR/plugins" ]]; then
  for pdir in "$REPO_DIR"/plugins/*; do
    if [[ -d "$pdir" ]]; then
      plugin_name=$(basename "$pdir")
      target_plugin_id="${CURRENT_USER}.${plugin_name}"
      target_dir="$CONFIG_DIR/omarchy/plugins/$target_plugin_id"
      
      mkdir -p "$target_dir"
      cp -r "$pdir"/* "$target_dir/"
      
      # Dynamically update __USER__. to active username (${CURRENT_USER}.)
      find "$target_dir" -type f \( -name "*.json" -o -name "*.qml" -o -name "*.js" \) -exec sed -i \
        -e "s/__USER__\./${CURRENT_USER}./g" \
        -e "s/\"id\": \"[^\"]*\.${plugin_name}\"/\"id\": \"${target_plugin_id}\"/g" \
        -e "s/moduleName: \"[^\"]*\.${plugin_name}\"/moduleName: \"${target_plugin_id}\"/g" {} +
    fi
  done
  log_sub "Synchronized and calibrated $(ls -d "$REPO_DIR"/plugins/* | wc -l) plugins for '${CURRENT_USER}'"
fi

# ------------------------------------------------------------------------------
# 4. Install Status Bar Layout (shell.json) & Menu Extensions
# ------------------------------------------------------------------------------
log_step "4" "$TOTAL_STEPS" "Installing status bar layout & menu extensions..."

# Preserve canonical default Omarchy shell layout as shell-default.json
if [[ -f "/usr/share/omarchy/config/omarchy/shell.json" && ! -f "$CONFIG_DIR/omarchy/shell-default.json" ]]; then
  cp "/usr/share/omarchy/config/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell-default.json"
fi

if [[ -f "$REPO_DIR/shell/shell.json" ]]; then
  # Save Virtual Paradise bar layout as shell-paradise.json
  sed "s/__USER__/${CURRENT_USER}/g" "$REPO_DIR/shell/shell.json" > "$CONFIG_DIR/omarchy/shell-paradise.json"
  cp "$CONFIG_DIR/omarchy/shell-paradise.json" "$CONFIG_DIR/omarchy/shell.json"
  log_sub "Synchronized ~/.config/omarchy/shell-paradise.json with calibrated user IDs"
fi

cat << 'EOF' > "$CONFIG_DIR/omarchy/extensions/paradise.json"
{
  "paradise.rice": {
    "icon": "󰄛",
    "label": "5-Terminal Rice Layout",
    "description": "Launch Cava, Btop, Matrix & Saiba Momoi ASCII",
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
    "description": "Play/pause live wallpaper (SUPER + ALT + UP)",
    "action": "bash -c ~/.local/bin/toggle_live_wallpaper.sh"
  },
  "paradise.cooler": {
    "icon": "󰈐",
    "label": "Toggle Cooler Boost",
    "description": "Turn fan cooling on/off",
    "action": "bash -c ~/.local/bin/toggle_cooler_boost.sh"
  },
  "paradise.agent": {
    "icon": "󰚩",
    "label": "Paradise Local Agent",
    "description": "Autonomous offline local AI pair-programmer (Qwen 2.5 Coder)",
    "action": "ghostty -e ~/.local/bin/paradise-agent"
  }
}
EOF
log_sub "Installed Quick Actions menu extensions"

# ------------------------------------------------------------------------------
# 5. Configure Hyprland Add-on Rules & Keybindings (Non-destructive)
# ------------------------------------------------------------------------------
log_step "5" "$TOTAL_STEPS" "Configuring Hyprland add-on rules, shortcuts & overlays..."

# 5.1 Initialize user hardware configs ONLY if missing (never overwrite existing user hardware settings)
if [[ ! -f "$CONFIG_DIR/hypr/monitors.lua" && -f "$REPO_DIR/hypr/monitors.lua" ]]; then
  cp "$REPO_DIR/hypr/monitors.lua" "$CONFIG_DIR/hypr/monitors.lua"
  log_sub "Initialized default display configuration"
fi
if [[ ! -f "$CONFIG_DIR/hypr/input.lua" && -f "$REPO_DIR/hypr/input.lua" ]]; then
  cp "$REPO_DIR/hypr/input.lua" "$CONFIG_DIR/hypr/input.lua"
  log_sub "Initialized default input configuration"
fi

# 5.2 Autostart: ensure live wallpaper hook is present without clobbering existing autostart
if [[ -f "$CONFIG_DIR/hypr/autostart.lua" ]]; then
  if ! grep -q "toggle_live_wallpaper.sh" "$CONFIG_DIR/hypr/autostart.lua"; then
    echo 'o.launch_on_start("~/.local/bin/toggle_live_wallpaper.sh init")' >> "$CONFIG_DIR/hypr/autostart.lua"
    log_sub "Hooked live wallpaper to ~/.config/hypr/autostart.lua"
  fi
elif [[ -f "$REPO_DIR/hypr/autostart.lua" ]]; then
  cp "$REPO_DIR/hypr/autostart.lua" "$CONFIG_DIR/hypr/autostart.lua"
fi

# 5.3 Keybindings: append Virtual Paradise shortcuts cleanly if missing
if [[ -f "$CONFIG_DIR/hypr/bindings.lua" ]]; then
  if ! grep -q "toggle_live_wallpaper" "$CONFIG_DIR/hypr/bindings.lua"; then
    cat << 'EOF' >> "$CONFIG_DIR/hypr/bindings.lua"

-- ==============================================================================
--  Virtual☆Paradise Add-on Shortcuts
-- ==============================================================================
o.bind("SUPER + Q", "Rice Layout", "~/.local/bin/rice_layout.sh")
o.bind("SUPER + ALT + UP", "Toggle Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh")
o.bind("SUPER + ALT + RIGHT", "Next Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh next")
o.bind("SUPER + ALT + LEFT", "Prev Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh prev")
o.bind("SUPER + C", "Cooler Boost", "~/.local/bin/toggle_cooler_boost.sh")
o.bind("SUPER + \\", "Cyber Matrix Rain", "ghostty -e ~/.local/bin/virtual_matrix")
EOF
    log_sub "Appended Virtual Paradise shortcuts to ~/.config/hypr/bindings.lua"
  fi
elif [[ -f "$REPO_DIR/hypr/bindings.lua" ]]; then
  cp "$REPO_DIR/hypr/bindings.lua" "$CONFIG_DIR/hypr/bindings.lua"
fi

# 5.4 Look'n'feel & Window Rules (non-destructive)
if [[ ! -f "$CONFIG_DIR/hypr/looknfeel.lua" && -f "$REPO_DIR/hypr/looknfeel.lua" ]]; then
  cp "$REPO_DIR/hypr/looknfeel.lua" "$CONFIG_DIR/hypr/looknfeel.lua"
fi

if [[ -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
  if ! grep -q "Btop Monitor" "$CONFIG_DIR/hypr/hyprland.lua"; then
    cat << 'EOF' >> "$CONFIG_DIR/hypr/hyprland.lua"

-- Virtual Paradise Add-on Window Rules
o.window({ initial_title = "Btop Monitor" }, { float = true, size = { 1050, 650 }, center = true })
o.window({ title = "Btop Monitor" }, { float = true, size = { 1050, 650 }, center = true })
o.window({ initial_title = "Voxtype Config" }, { float = true, size = { 880, 580 }, center = true })
o.window({ title = "Voxtype Config" }, { float = true, size = { 880, 580 }, center = true })
EOF
  fi
fi

if [[ -f "$REPO_DIR/hypr/hyprland.conf" && ! -f "$CONFIG_DIR/hypr/hyprland.conf" ]]; then
  cp "$REPO_DIR/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf" 2>/dev/null || true
fi
if [[ -f "$REPO_DIR/hypr/hyprlock.conf" ]]; then
  cp "$REPO_DIR/hypr/hyprlock.conf" "$CONFIG_DIR/hypr/hyprlock.conf" 2>/dev/null || true
fi
if [[ -f "$REPO_DIR/hypr/hyprland-preview-share-picker.css" ]]; then
  cp "$REPO_DIR/hypr/hyprland-preview-share-picker.css" "$CONFIG_DIR/hypr/hyprland-preview-share-picker.css" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 6. Install Helper Scripts & Binaries
# ------------------------------------------------------------------------------
log_step "6" "$TOTAL_STEPS" "Installing binaries & CLI helper tools to $LOCAL_BIN..."
# Ensure Omarchy default agent is never shadowed
rm -f "$LOCAL_BIN/omarchy-agent" 2>/dev/null || true

if [[ -d "$REPO_DIR/bin" ]]; then
  cp -r "$REPO_DIR"/bin/* "$LOCAL_BIN/"
  chmod +x "$LOCAL_BIN"/* 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_agent.py" "$LOCAL_BIN/paradise-agent" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_agent.py" "$LOCAL_BIN/offline-agent" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_agent.py" "$LOCAL_BIN/agy-offline" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_agent.py" "$LOCAL_BIN/agy-local" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/virtual_matrix.py" "$LOCAL_BIN/virtual_matrix" 2>/dev/null || true
  chmod +x "$LOCAL_BIN/sync_cava_theme.py" "$LOCAL_BIN/virtual_matrix.py" 2>/dev/null || true
  log_sub "Installed helper tools (rice_layout, momoisay, toggle_live_wallpaper, logout_splash, paradise-agent, etc.)"
fi

# ------------------------------------------------------------------------------
# 7. Install Component Themes (Btop, Cava, Fastfetch, Micro)
# ------------------------------------------------------------------------------
log_step "7" "$TOTAL_STEPS" "Installing Cava, Btop, Fastfetch & Micro editor theme profiles..."

# Cava
if [[ -f "$REPO_DIR/cava/config_bar" ]]; then
  cp "$REPO_DIR/cava/config_bar" "$CONFIG_DIR/cava/config_bar"
fi
if [[ -f "$REPO_DIR/cava/config" ]]; then
  cp "$REPO_DIR/cava/config" "$CONFIG_DIR/cava/config"
fi

# Btop
if [[ -f "$REPO_DIR/theme/btop.theme" ]]; then
  cp "$REPO_DIR/theme/btop.theme" "$CONFIG_DIR/btop/themes/virtual-paradise.theme"
fi

# Fastfetch
if [[ -d "$REPO_DIR/fastfetch" ]]; then
  cp -r "$REPO_DIR/fastfetch"/* "$CONFIG_DIR/fastfetch/"
fi

# Micro Editor Rice
if [[ -d "$REPO_DIR/micro" ]]; then
  if [[ -f "$REPO_DIR/micro/settings.json" ]]; then
    cp "$REPO_DIR/micro/settings.json" "$CONFIG_DIR/micro/settings.json"
  fi
  if [[ -d "$REPO_DIR/micro/colorschemes" ]]; then
    cp -r "$REPO_DIR/micro/colorschemes"/* "$CONFIG_DIR/micro/colorschemes/"
  fi
fi

# GTK4 & GTK3 Styling (Nautilus & Libadwaita) and Minimal Cybertech Icons
if [[ -f "$REPO_DIR/config/gtk.css" ]]; then
  mkdir -p "$CONFIG_DIR/gtk-4.0" "$CONFIG_DIR/gtk-3.0"
  cp "$REPO_DIR/config/gtk.css" "$CONFIG_DIR/gtk-4.0/gtk.css"
  cp "$REPO_DIR/config/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css"
fi
if command -v gsettings &>/dev/null; then
  gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-dracula-dark" 2>/dev/null || true
fi
log_sub "Component themes installed (Cava, Btop, Fastfetch, Micro, GTK/Nautilus & Tela-Circle Icons)"

# ------------------------------------------------------------------------------
# 8. Install Theme Assets & Backgrounds
# ------------------------------------------------------------------------------
log_step "8" "$TOTAL_STEPS" "Installing theme assets, live wallpapers & hooks..."
if [[ "$REPO_DIR" != "$CONFIG_DIR/omarchy/themes/$THEME_NAME" ]]; then
  rsync -a --delete \
    --exclude='.git' \
    --exclude='preview_frame.jpg' \
    --exclude='preview_rotated.jpg' \
    "$REPO_DIR"/ "$CONFIG_DIR/omarchy/themes/$THEME_NAME/" 2>/dev/null || true
fi

# Flatten theme/ color/appearance files into theme root (Omarchy reads them directly)
THEME_DEST="$CONFIG_DIR/omarchy/themes/$THEME_NAME"
if [[ -d "$THEME_DEST/theme" ]]; then
  cp -r "$THEME_DEST/theme"/. "$THEME_DEST/" 2>/dev/null || true
  log_sub "Flattened theme/ color files to Omarchy theme root"
fi
# Flatten terminal configs into theme root (Omarchy re-templates them from colors.toml)
if [[ -d "$THEME_DEST/config/terminal" ]]; then
  cp -r "$THEME_DEST/config/terminal"/. "$THEME_DEST/" 2>/dev/null || true
  log_sub "Flattened config/terminal/ files to Omarchy theme root"
fi
# Flatten editor configs into theme root
if [[ -d "$THEME_DEST/config/editor" ]]; then
  cp -r "$THEME_DEST/config/editor"/. "$THEME_DEST/" 2>/dev/null || true
  log_sub "Flattened config/editor/ files to Omarchy theme root"
fi
# Flatten hyprland configs from hypr/ into theme root (Omarchy expects hyprland.lua at root)
for f in hyprland.lua hyprland-preview-share-picker.css hyprlock.conf; do
  if [[ -f "$THEME_DEST/hypr/$f" ]]; then
    cp "$THEME_DEST/hypr/$f" "$THEME_DEST/$f" 2>/dev/null || true
  fi
done
log_sub "Flattened hypr/ Omarchy-required files to theme root"

# Post-theme-set hook
cat << 'EOF' > "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
#!/bin/bash
THEME_NAME="$1"

# Sync Cava visualizer colors to the newly selected theme
if [[ -x "$HOME/.local/bin/sync_cava_theme.py" ]]; then
  python3 "$HOME/.local/bin/sync_cava_theme.py" "$THEME_NAME" >/dev/null 2>&1 &
fi

if [[ "$THEME_NAME" == "virtual-paradise" ]]; then
  # 1. Restore Virtual Paradise custom bar layout (with live indicators & Miku lock)
  if [[ -f "$HOME/.config/omarchy/shell-paradise.json" ]]; then
    cp "$HOME/.config/omarchy/shell-paradise.json" "$HOME/.config/omarchy/shell.json"
    omarchy restart shell >/dev/null 2>&1 &
  fi

  # 2. Activate Virtual Paradise Fastfetch config
  if [[ -f "$HOME/.config/fastfetch/virtual-paradise.jsonc" ]]; then
    cp "$HOME/.config/fastfetch/virtual-paradise.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  fi

  # 3. Re-trigger hook if installer is present
  if [[ -f "$HOME/.config/omarchy/themes/virtual-paradise/install.sh" ]]; then
    bash "$HOME/.config/omarchy/themes/virtual-paradise/install.sh" --hook >/dev/null 2>&1 &
  fi

  # 4. Start live video wallpaper
  if [[ -x "$HOME/.local/bin/toggle_live_wallpaper.sh" ]]; then
    (sleep 0.3; "$HOME/.local/bin/toggle_live_wallpaper.sh" init >/dev/null 2>&1 &)
  fi
else
  # 1. Cleanly stop live video wallpaper so new theme background displays properly
  pkill -f mpvpaper 2>/dev/null || true

  # 2. RESTORE CANONICAL DEFAULT OMARCHY BAR LAYOUT (pure stock plugins & active theme styling)
  if [[ -f "$HOME/.config/omarchy/shell-default.json" ]]; then
    cp "$HOME/.config/omarchy/shell-default.json" "$HOME/.config/omarchy/shell.json"
    omarchy restart shell >/dev/null 2>&1 &
  fi

  # 3. Restore default Omarchy Fastfetch (Arch/Omarchy logo with native terminal colors)
  rm -f "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null || true
fi

# Reload compositor to apply the new active border and theme rules
hyprctl reload >/dev/null 2>&1 &
EOF
chmod +x "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
log_sub "Theme assets & automatic synchronization hooks ready"

# ------------------------------------------------------------------------------
# 9. Install Boot & Shutdown Animations (Plymouth, SDDM & UKI)
# ------------------------------------------------------------------------------
if [[ $ENABLE_BOOT -eq 1 ]]; then
  INSTALL_BOOT_ANIMATIONS
else
  log_step "9" "$TOTAL_STEPS" "Boot & shutdown animation setup skipped (--no-boot)"
fi

# ------------------------------------------------------------------------------
# 10. Configure Shell Environment (Zsh & Bash) & Error Hooks
# ------------------------------------------------------------------------------
log_step "10" "$TOTAL_STEPS" "Configuring shell environment, Search☆Hub, aliases & error shake hooks..."

# Synchronize curated zshrc non-destructively
if [[ -f "$REPO_DIR/shell/zshrc" ]]; then
  if [[ ! -f "$HOME/.zshrc" ]]; then
    cp "$REPO_DIR/shell/zshrc" "$HOME/.zshrc"
    log_sub "Initialized ~/.zshrc with Virtual☆Paradise shell configuration"
  else
    if ! grep -q "paradise-agent" "$HOME/.zshrc"; then
      cat << 'EOF' >> "$HOME/.zshrc"

# ==============================================================================
#  Virtual☆Paradise Add-on Aliases & Integration
# ==============================================================================
alias pa="paradise-agent"
alias agy="paradise-agent"
alias offline-agent="paradise-agent"
alias rice="$HOME/.local/bin/rice_layout.sh"
alias matrix="$HOME/.local/bin/virtual_matrix.py"
alias boost="$HOME/.local/bin/toggle_cooler_boost.sh"
EOF
      log_sub "Appended Virtual Paradise aliases to existing ~/.zshrc"
    fi
  fi
fi

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
    elif [[ $exit_code -ne 0 && $__omarchy_last_err_state -ne 0 ]]; then
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
  log_sub "Compiled ~/.zshrc bytecode cache (~/.zshrc.zwc)"
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
  echo -e "   ${C_GREEN}SUPER + ALT + RIGHT${C_RESET}   ➔ Next Live Wallpaper (Cyberpunk Glitch Transition)"
  echo -e "   ${C_GREEN}SUPER + ALT + LEFT${C_RESET}    ➔ Prev Live Wallpaper (Cyberpunk Glitch Transition)"
  echo -e "   ${C_GREEN}SUPER + N${C_RESET}             ➔ Cycle next wallpaper"
  echo -e "   ${C_GREEN}SUPER + C${C_RESET}             ➔ Toggle Cooler Boost fan cooling"
  echo -e "   ${C_GREEN}ffa${C_RESET}                   ➔ Launch Fastfetch with high-res Anime Braille logo"
  echo -e "   ${C_GREEN}f${C_RESET}                     ➔ Search☆Hub (Explorer, History, Process)"
  echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────${C_RESET}\n"
fi
