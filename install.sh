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

# Detect real user & home directory even when executed via sudo
if (( EUID == 0 )); then
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    CURRENT_USER="$SUDO_USER"
    USER_HOME="$(getent passwd "$CURRENT_USER" | cut -d: -f6)"
    export HOME="$USER_HOME"
  else
    CURRENT_USER="${USER:-$(id -un)}"
  fi
  SUDO_CMD=""
else
  CURRENT_USER="${USER:-$(id -un)}"
  SUDO_CMD="sudo"
  if [[ $IS_HOOK -eq 0 ]] && command -v sudo &>/dev/null; then
    if ! sudo -n true 2>/dev/null; then
      echo -e "\033[38;2;0;245;212m🔑 Virtual☆Paradise requires sudo privileges for hardware drivers & boot setup.\033[0m"
      echo -e "\033[2m   Please enter your sudo password:\033[0m"
      sudo -v || { echo -e "\033[38;2;255;0;85m❌ Sudo authentication failed. Aborting.\033[0m"; exit 1; }
    fi
    # Keep sudo timestamp alive in background until install completes
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null & )
    SUDO_KEEP_ALIVE_PID=$!
  fi
fi

cleanup_install() {
  local ec=$?
  if [[ -n "${SUDO_KEEP_ALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null || true
  fi
  if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    chown -R "$CURRENT_USER:$CURRENT_USER" "$CONFIG_DIR" "$LOCAL_BIN" "$CACHE_DIR" "$HOME/.local" "$HOME/.zshrc"* "$HOME/.oh-my-zsh" 2>/dev/null || true
  fi
  exit $ec
}
trap cleanup_install EXIT INT TERM

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"


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
  if (( EUID == 0 )) || ( command -v sudo &>/dev/null && sudo -n true 2>/dev/null ); then
    can_sudo=1
  elif command -v sudo &>/dev/null; then
    log_info "  ${C_PINK}🔑 Requesting sudo permission for system-wide Plymouth and SDDM setup...${C_RESET}"
    if sudo -v; then
      can_sudo=1
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
# 1. Hardware Detection & Dependency Installation
# ------------------------------------------------------------------------------
log_step "1" "$TOTAL_STEPS" "Detecting hardware & installing required system packages..."

detect_hardware_vendor() {
  local raw_vendor=""
  if [[ -r /sys/devices/virtual/dmi/id/sys_vendor ]]; then
    raw_vendor=$(< /sys/devices/virtual/dmi/id/sys_vendor)
  elif [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    raw_vendor=$(< /sys/class/dmi/id/sys_vendor)
  elif command -v hostnamectl >/dev/null 2>&1; then
    raw_vendor=$(hostnamectl 2>/dev/null | awk -F": " '/Hardware Vendor/ {print $2}')
  fi

  case "${raw_vendor,,}" in
    *micro-star*|*msi*)
      echo "MSI" ;;
    *asustek*|*asus*)
      echo "ASUS" ;;
    *lenovo*)
      echo "Lenovo" ;;
    *alienware*)
      echo "Alienware" ;;
    *dell*)
      echo "Dell" ;;
    *hp*|*hewlett-packard*)
      echo "HP" ;;
    *acer*)
      echo "Acer" ;;
    *gigabyte*)
      echo "Gigabyte" ;;
    *razer*)
      echo "Razer" ;;
    *apple*)
      echo "Apple" ;;
    *framework*)
      echo "Framework" ;;
    *)
      if [[ -n "$raw_vendor" ]]; then
        local clean
        clean=$(echo "$raw_vendor" | sed -E "s/,? (Inc\.|Co\.,? Ltd\.|Corporation|Technology).*//gi" | awk '{print $1}')
        echo "${clean:-Generic}"
      else
        echo "Generic"
      fi
      ;;
  esac
}

detect_product_name() {
  if [[ -r /sys/class/dmi/id/product_name ]]; then
    cat /sys/class/dmi/id/product_name
  elif [[ -r /sys/devices/virtual/dmi/id/product_name ]]; then
    cat /sys/devices/virtual/dmi/id/product_name
  fi
}

detect_chassis_type() {
  if [[ -r /sys/class/dmi/id/chassis_type ]]; then
    local c
    c=$(< /sys/class/dmi/id/chassis_type)
    case "$c" in
      8|9|10|11|14|30|31|32) echo "laptop" ;;
      *) echo "desktop" ;;
    esac
  else
    echo "laptop"
  fi
}

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
    "fcitx5"
    "fcitx5-gtk"
    "fcitx5-qt"
    "fcitx5-configtool"
    "fcitx5-unikey"
    "v4l-utils"
    "gst-plugins-good"
    "gst-plugins-bad"
    "gst-plugins-ugly"
    "gst-rtsp-server"
    "protobuf-c"
    "dnsmasq"
    "python-rich"
    "python-docx"
    "python-prompt_toolkit"
    "fzf"
    "bat"
    "eza"
    "zoxide"
    "yazi"
    "duf"
    "dust"
    "gping"
    "lm_sensors"
    "zsh"
    "zsh-completions"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "jq"
    "socat"
    "git"
    "psmisc"
    "ghostty"
    "nautilus"
    "github-copilot-cli"
    "visual-studio-code-bin"
  )
  local AUR_PKGS=(
    "mpvpaper"
    "gnome-network-displays"
    "hyprmoncfg"
  )

  local HW_VENDOR=$(detect_hardware_vendor)
  local HW_PRODUCT=$(detect_product_name)
  local HW_CHASSIS=$(detect_chassis_type)

  log_sub "Detected Hardware: ${HW_VENDOR} ${HW_PRODUCT} (${HW_CHASSIS})"

  case "${HW_VENDOR,,}" in
    *acer*)
      if [[ -d "/sys/module/acer_nitro_ec" ]] || pacman -Qs acer-nitro-ec &>/dev/null; then
        log_sub "Acer Nitro EC fan driver is active"
      elif command -v nbfc &>/dev/null || pacman -Qs nbfc &>/dev/null; then
        log_sub "NoteBook FanControl is active"
      else
        log_sub "Acer hardware detected: checking fan control packages..."
        if pacman -Qs linux-headers &>/dev/null; then
          AUR_PKGS+=("acer-nitro-ec-dkms")
        else
          AUR_PKGS+=("nbfc-linux")
        fi
      fi
      ;;
    *micro-star*|*msi*)
      if command -v isw &>/dev/null || pacman -Qs isw &>/dev/null; then
        log_sub "MSI ISW fan control tool is active"
      else
        log_sub "MSI hardware detected: adding ISW fan control tool..."
        AUR_PKGS+=("isw")
      fi
      ;;
    *asustek*|*asus*)
      if command -v asusctl &>/dev/null || pacman -Qs asusctl &>/dev/null; then
        log_sub "ASUS asusctl tool is active"
      else
        log_sub "ASUS ROG/TUF hardware detected: adding asusctl..."
        REQUIRED_PKGS+=("asusctl")
      fi
      ;;
    *lenovo*|*dell*|*alienware*|*hp*|*gigabyte*|*razer*)
      if command -v nbfc &>/dev/null || pacman -Qs nbfc &>/dev/null; then
        log_sub "NoteBook FanControl is active"
      else
        log_sub "${HW_VENDOR} laptop detected: adding universal fan control (nbfc-linux)..."
        AUR_PKGS+=("nbfc-linux")
      fi
      ;;
    *)
      if [[ "$HW_CHASSIS" == "laptop" ]]; then
        if command -v nbfc &>/dev/null || pacman -Qs nbfc &>/dev/null; then
          log_sub "NoteBook FanControl is active"
        else
          log_sub "Laptop detected: adding universal fan control (nbfc-linux)..."
          AUR_PKGS+=("nbfc-linux")
        fi
      fi
      ;;
  esac

  local OFFICIAL_TO_INSTALL=()
  for pkg in "${REQUIRED_PKGS[@]}"; do
    if command -v pacman &>/dev/null; then
      if ! pacman -Qi "$pkg" &>/dev/null; then
        OFFICIAL_TO_INSTALL+=("$pkg")
      fi
    fi
  done

  local AUR_TO_INSTALL=()
  for pkg in "${AUR_PKGS[@]}"; do
    local already_installed=0
    if pacman -Qs "^${pkg}$" &>/dev/null || pacman -Qi "$pkg" &>/dev/null; then
      already_installed=1
    elif [[ "$pkg" == "nbfc-linux" ]] && command -v nbfc &>/dev/null; then
      already_installed=1
    elif [[ "$pkg" == "gnome-network-displays" ]] && command -v gnome-network-displays &>/dev/null; then
      already_installed=1
    elif [[ "$pkg" == "mpvpaper" ]] && command -v mpvpaper &>/dev/null; then
      already_installed=1
    elif [[ "$pkg" == "isw" ]] && command -v isw &>/dev/null; then
      already_installed=1
    elif [[ "$pkg" == "hyprmoncfg" ]] && command -v hyprmoncfg &>/dev/null; then
      already_installed=1
    fi

    if [[ $already_installed -eq 0 ]]; then
      AUR_TO_INSTALL+=("$pkg")
    fi
  done

  if [[ ${#OFFICIAL_TO_INSTALL[@]} -gt 0 ]]; then
    log_sub "Installing official packages: ${OFFICIAL_TO_INSTALL[*]}"
    if command -v pacman &>/dev/null; then
      $SUDO_CMD pacman -S --needed --noconfirm "${OFFICIAL_TO_INSTALL[@]}" || true
    fi
  fi

  if [[ ${#AUR_TO_INSTALL[@]} -gt 0 ]]; then
    log_sub "Installing AUR packages: ${AUR_TO_INSTALL[*]}"
    if command -v yay &>/dev/null; then
      if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        sudo -u "$CURRENT_USER" yay -S --needed --noconfirm "${AUR_TO_INSTALL[@]}" || true
      else
        yay -S --needed --noconfirm "${AUR_TO_INSTALL[@]}" || true
      fi
    elif command -v paru &>/dev/null; then
      if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        sudo -u "$CURRENT_USER" paru -S --needed --noconfirm "${AUR_TO_INSTALL[@]}" || true
      else
        paru -S --needed --noconfirm "${AUR_TO_INSTALL[@]}" || true
      fi
    else
      log_warn "AUR helper (yay/paru) not found. Please install manually: ${AUR_TO_INSTALL[*]}"
    fi
  fi

  if [[ ${#OFFICIAL_TO_INSTALL[@]} -eq 0 && ${#AUR_TO_INSTALL[@]} -eq 0 ]]; then
    log_sub "All required packages are satisfied"
  fi
}

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

CONFIGURE_DEFAULT_APPS() {
  log_sub "Configuring Omarchy defaults: Ghostty, Nautilus, VS Code & GitHub Copilot..."

  if command -v omarchy &>/dev/null; then
    if command -v ghostty &>/dev/null; then
      RUN_AS_INSTALL_USER omarchy default terminal ghostty 2>/dev/null || \
        log_warn "Could not set Ghostty as the Omarchy default terminal."
    fi
    if command -v copilot &>/dev/null || pacman -Qi github-copilot-cli &>/dev/null; then
      RUN_AS_INSTALL_USER omarchy default agent copilot 2>/dev/null || \
        log_warn "Could not set GitHub Copilot as the Omarchy default agent."
    fi
  fi

  if command -v xdg-mime &>/dev/null && command -v nautilus &>/dev/null; then
    RUN_AS_INSTALL_USER xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || \
      log_warn "Could not set Nautilus as the default file manager."
  fi

  if command -v xdg-mime &>/dev/null && command -v code &>/dev/null; then
    for mime_type in text/plain text/markdown application/json application/x-shellscript; do
      RUN_AS_INSTALL_USER xdg-mime default code.desktop "$mime_type" 2>/dev/null || true
    done
  fi

  if command -v code &>/dev/null; then
    log_sub "VS Code is available as the default editor (code --wait)"
  fi
}

CONFIGURE_GPU_ACCELERATION() {
  if ! command -v nvidia-smi &>/dev/null; then
    log_sub "NVIDIA GPU utilities not detected; leaving GPU configuration unchanged"
    return 0
  fi

  log_sub "Optimizing NVIDIA GPU persistence and compute startup..."
  if (( EUID == 0 )); then
    systemctl enable --now nvidia-persistenced.service 2>/dev/null || \
      log_warn "Could not enable nvidia-persistenced.service."
    nvidia-smi -pm 1 >/dev/null 2>&1 || \
      log_warn "Could not enable NVIDIA persistence mode."
  else
    $SUDO_CMD systemctl enable --now nvidia-persistenced.service 2>/dev/null || \
      log_warn "Could not enable nvidia-persistenced.service."
    $SUDO_CMD nvidia-smi -pm 1 >/dev/null 2>&1 || \
      log_warn "Could not enable NVIDIA persistence mode."
  fi
}

CONFIGURE_HARDWARE_DRIVERS() {
  local HW_VENDOR=$(detect_hardware_vendor)
  local HW_PRODUCT=$(detect_product_name)

  case "${HW_VENDOR,,}" in
    *acer*)
      if [[ -d "/sys/module/acer_nitro_ec" ]] || pacman -Qs acer-nitro-ec &>/dev/null; then
        if [[ ! -d "/sys/module/acer_nitro_ec" ]]; then
          $SUDO_CMD modprobe acer-nitro-ec 2>/dev/null || true
        fi
        log_sub "Configuring Acer Nitro EC fan driver & udev permissions..."
        $SUDO_CMD bash -c 'cat << "EOF" > /etc/udev/rules.d/99-acer-nitro-fan.rules
ACTION=="add|change", SUBSYSTEM=="hwmon", ATTR{name}=="acer_nitro_ec|acer-nitro-ec|acer[-_]nitro[-_]ec", RUN+="/usr/bin/chmod 0666 /sys%p/pwm1_enable /sys%p/pwm2_enable /sys%p/pwm1 /sys%p/pwm2"
ACTION=="add|change", SUBSYSTEM=="hwmon", KERNEL=="hwmon*", DEVPATH=="*/acer-nitro-ec/hwmon/*", RUN+="/usr/bin/chmod 0666 /sys%p/pwm1_enable /sys%p/pwm2_enable /sys%p/pwm1 /sys%p/pwm2"
EOF'
        $SUDO_CMD udevadm control --reload-rules 2>/dev/null || true
        $SUDO_CMD udevadm trigger --subsystem-match=hwmon 2>/dev/null || true

        # Immediately apply 0666 permissions to any active hwmon fan nodes
        for h in /sys/class/hwmon/hwmon*; do
          if [[ -r "$h/name" ]]; then
            local n
            n=$(< "$h/name")
            if [[ "$n" == "acer_nitro_ec" || "$n" == "acer-nitro-ec" ]]; then
              $SUDO_CMD chmod 0666 "$h"/pwm* 2>/dev/null || true
              log_sub "Granted direct user control to fan sysfs at $h"
            fi
          fi
        done
      fi

      if command -v nbfc &>/dev/null; then
        log_sub "Activating NoteBook FanControl service for Acer..."
        $SUDO_CMD systemctl enable --now nbfc_service 2>/dev/null || true
        if [[ "$HW_PRODUCT" =~ AN515-54 ]]; then
          nbfc config -a "Acer Nitro AN515-54" 2>/dev/null || nbfc config -a "Acer Nitro AN515-51" 2>/dev/null || true
        elif [[ "$HW_PRODUCT" =~ AN515-51 ]]; then
          nbfc config -a "Acer Nitro AN515-51" 2>/dev/null || true
        else
          nbfc config --recommend --apply 2>/dev/null || true
        fi
        nbfc start 2>/dev/null || true
      fi
      ;;
    *asustek*|*asus*)
      if command -v asusctl &>/dev/null; then
        log_sub "Activating asusd service for ASUS..."
        $SUDO_CMD systemctl enable --now asusd.service 2>/dev/null || true
      fi
      ;;
    *)
      if command -v nbfc &>/dev/null; then
        log_sub "Activating NoteBook FanControl service for ${HW_VENDOR}..."
        $SUDO_CMD systemctl enable --now nbfc_service 2>/dev/null || true
        nbfc config --recommend --apply 2>/dev/null || true
        nbfc start 2>/dev/null || true
      fi
      ;;
  esac
}

CONFIGURE_AI_AGENT_ENGINE() {
  if command -v ollama &>/dev/null; then
    log_sub "Configuring Ollama AI service for Paradise Agent..."
    if [[ -n "$SUDO_CMD" ]] && command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
      sudo systemctl enable --now ollama.service 2>/dev/null || true
    elif (( EUID == 0 )); then
      systemctl enable --now ollama.service 2>/dev/null || true
    elif command -v systemctl &>/dev/null; then
      systemctl --user enable --now ollama.service 2>/dev/null || true
    fi

    local ollama_ready=0
    for ((i=0; i<6; i++)); do
      if ollama list >/dev/null 2>&1; then
        ollama_ready=1
        break
      fi
      sleep 0.5
    done

    if [[ $ollama_ready -eq 1 ]]; then
      if ! ollama list 2>/dev/null | grep -qi "qwen2.5-coder"; then
        log_sub "Pulling lightweight local model (qwen2.5-coder:1.5b) in background..."
        (ollama pull qwen2.5-coder:1.5b >/dev/null 2>&1 &)
      else
        log_sub "Local Qwen 2.5 Coder model is ready"
      fi
    fi
  fi
}

if [[ $IS_HOOK -eq 0 ]]; then
  CHECK_AND_INSTALL_PACKAGES
  CONFIGURE_DEFAULT_APPS
  CONFIGURE_GPU_ACCELERATION
  CONFIGURE_HARDWARE_DRIVERS
  CONFIGURE_AI_AGENT_ENGINE
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
# 3. Install & Enable Custom Omarchy Bar Plugins
# ------------------------------------------------------------------------------
INSTALL_AND_ENABLE_PLUGINS() {
  log_step "3" "$TOTAL_STEPS" "Installing and enabling custom Quickshell plugins for user '$CURRENT_USER'..."
  if [[ -d "$REPO_DIR/plugins" ]]; then
    local count=0
    for pdir in "$REPO_DIR"/plugins/*; do
      if [[ -d "$pdir" ]]; then
        local plugin_name=$(basename "$pdir")
        local target_plugin_id="${CURRENT_USER}.${plugin_name}"
        local target_dir="$CONFIG_DIR/omarchy/plugins/$target_plugin_id"
        
        mkdir -p "$target_dir"
        cp -r "$pdir"/* "$target_dir/"
        
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
      omarchy-shell shell rescanPlugins 2>/dev/null || true
    fi

    # Explicitly activate and register each plugin in Omarchy
    if command -v omarchy &>/dev/null; then
      local enabled_count=0
      for pdir in "$REPO_DIR"/plugins/*; do
        if [[ -d "$pdir" ]]; then
          local pname=$(basename "$pdir")
          local pid="${CURRENT_USER}.${pname}"
          omarchy plugin enable "$pid" 2>/dev/null || true
          enabled_count=$((enabled_count + 1))
        fi
      done
      log_sub "Enabled all ${enabled_count} Virtual Paradise plugins in Omarchy shell"

      # Install & enable external Omarchy webcam plugin
      if [[ ! -d "$CONFIG_DIR/omarchy/plugins/io.github.kristoferlund.webcam" ]] && ! omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.kristoferlund.webcam")' >/dev/null; then
        log_sub "Adding external Omarchy webcam plugin from git..."
        omarchy plugin add https://github.com/kristoferlund/omarchy-webcam.git --enable --yes 2>/dev/null || true
      else
        omarchy plugin enable "io.github.kristoferlund.webcam" 2>/dev/null || true
      fi

      # Install the notification center once, then ensure it stays enabled on
      # subsequent theme installations.
      if ! omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "jankeesvw.notification-center")' >/dev/null; then
        log_sub "Adding external Omarchy notification center plugin from git..."
        omarchy plugin add https://github.com/jankeesvw/omarchy-notification-center.git --enable --yes 2>/dev/null || true
      else
        omarchy plugin enable "jankeesvw.notification-center" 2>/dev/null || true
      fi

      # hyprmoncfg replaces the cloned Display & Scaling widget in this
      # theme. Keep the old widget disabled to avoid duplicate controls.
      if ! omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "crmne.hyprmoncfg")' >/dev/null; then
        log_sub "Adding external Omarchy monitor manager plugin from git..."
        omarchy plugin add https://github.com/crmne/omarchy-hyprmoncfg.git --enable --yes 2>/dev/null || true
      else
        omarchy plugin enable "crmne.hyprmoncfg" 2>/dev/null || true
      fi
      omarchy plugin disable "${CURRENT_USER}.monitor" 2>/dev/null || true
      omarchy plugin disable "omarchy.monitor" 2>/dev/null || true

      # The notification center owns the DND control. Disable a separately
      # installed DND plugin when present, but keep Omarchy's notification
      # service enabled because the new plugin uses it as its backend.
      local dnd_plugin_id
      for dnd_plugin_id in omarchy.dnd omarchy.do-not-disturb doe.dnd; do
        if omarchy plugin list --json 2>/dev/null | jq -e --arg id "$dnd_plugin_id" \
          'any(.[]; .id == $id)' >/dev/null; then
          omarchy plugin disable "$dnd_plugin_id" 2>/dev/null || \
            log_warn "Could not disable legacy DND plugin '$dnd_plugin_id'."
        fi
      done
    fi
  fi
}
INSTALL_AND_ENABLE_PLUGINS

# ------------------------------------------------------------------------------
# 4. Install Status Bar Layout (shell.json) & Menu Extensions
# ------------------------------------------------------------------------------
log_step "4" "$TOTAL_STEPS" "Installing status bar layout & menu extensions..."

# Preserve canonical default Omarchy shell layout as shell-default.json
if [[ ! -f "$CONFIG_DIR/omarchy/shell-default.json" ]]; then
  if [[ -f "/usr/share/omarchy/config/omarchy/shell.json" ]]; then
    cp "/usr/share/omarchy/config/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell-default.json"
  elif [[ -f "$CONFIG_DIR/omarchy/shell.json" ]]; then
    cp "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell-default.json"
  fi
fi

if [[ -f "$REPO_DIR/shell/shell.json" ]]; then
  # Save Virtual Paradise bar layout as shell-paradise.json
  sed "s/__USER__/${CURRENT_USER}/g" "$REPO_DIR/shell/shell.json" > "$CONFIG_DIR/omarchy/shell-paradise.json"
  cp "$CONFIG_DIR/omarchy/shell-paradise.json" "$CONFIG_DIR/omarchy/shell.json"
  log_sub "Synchronized ~/.config/omarchy/shell-paradise.json with calibrated user IDs"

  # The shell layout copy above can reset plugin enablement. Restore the
  # external notification center after the layout is installed.
  if command -v omarchy &>/dev/null; then
    omarchy plugin enable "jankeesvw.notification-center" 2>/dev/null || \
      log_warn "Notification center could not be enabled after shell layout sync."
    omarchy plugin enable "crmne.hyprmoncfg" 2>/dev/null || \
      log_warn "hyprmoncfg could not be enabled after shell layout sync."
    omarchy plugin disable "${CURRENT_USER}.monitor" 2>/dev/null || true
    omarchy plugin disable "omarchy.monitor" 2>/dev/null || true
  fi
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
    "action": "bash -c 'for t in ghostty alacritty foot kitty xdg-terminal-exec; do if command -v \"$t\" &>/dev/null; then if [ \"$t\" = \"foot\" ]; then exec foot ~/.local/bin/virtual_matrix; else exec \"$t\" -e ~/.local/bin/virtual_matrix; fi; fi; done'"
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
  "paradise.cast": {
    "icon": "󰍹",
    "label": "Cast Screen (SUPER+SHIFT+K)",
    "description": "Wireless Display / Miracast & Chromecast projection",
    "action": "bash -c ~/.local/bin/cast_screen.sh"
  },
  "paradise.agent": {
    "icon": "󰚩",
    "label": "Paradise Local Agent",
    "description": "Autonomous offline local AI pair-programmer (Qwen 2.5 Coder)",
    "action": "bash -c 'for t in ghostty alacritty foot kitty xdg-terminal-exec; do if command -v \"$t\" &>/dev/null; then if [ \"$t\" = \"foot\" ]; then exec foot ~/.local/bin/paradise-agent; else exec \"$t\" -e ~/.local/bin/paradise-agent; fi; fi; done'"
  }
}
EOF
log_sub "Installed Quick Actions menu extensions"

# ------------------------------------------------------------------------------
# 5. Configure Hyprland Add-on Rules, Styling & Keybindings
# ------------------------------------------------------------------------------
log_step "5" "$TOTAL_STEPS" "Deploying Hyprland look'n'feel, gestures, rules & shortcuts..."

HYPR_BAK_DIR="$CONFIG_DIR/hypr/backup_$(date +%s)"
mkdir -p "$HYPR_BAK_DIR"

# 5.1 Look'n'feel (Golden ratio gaps, squircle rounding, acrylic blur, cyberSpring animations)
if [[ -f "$REPO_DIR/hypr/looknfeel.lua" ]]; then
  [[ -f "$CONFIG_DIR/hypr/looknfeel.lua" ]] && cp "$CONFIG_DIR/hypr/looknfeel.lua" "$HYPR_BAK_DIR/" 2>/dev/null || true
  cp "$REPO_DIR/hypr/looknfeel.lua" "$CONFIG_DIR/hypr/looknfeel.lua"
  log_sub "Applied Virtual Paradise look'n'feel (acrylic blur, cyberSpring animations, neon borders)"
fi

# 5.2 Input Tuning (macOS-level touchpad gestures, 50 chars/s repeat rate, cursor auto-hide)
if [[ -f "$REPO_DIR/hypr/input.lua" ]]; then
  [[ -f "$CONFIG_DIR/hypr/input.lua" ]] && cp "$CONFIG_DIR/hypr/input.lua" "$HYPR_BAK_DIR/" 2>/dev/null || true
  cp "$REPO_DIR/hypr/input.lua" "$CONFIG_DIR/hypr/input.lua"
  log_sub "Applied full-topping input & gestures (3-finger workspace swipe, pinch zoom, fast repeat)"
fi

# 5.3 Keybindings (SUPER+E file manager, SUPER+B browser, SUPER+ALT+C cooler boost, SUPER+SHIFT+K cast)
if [[ -f "$REPO_DIR/hypr/bindings.lua" ]]; then
  [[ -f "$CONFIG_DIR/hypr/bindings.lua" ]] && cp "$CONFIG_DIR/hypr/bindings.lua" "$HYPR_BAK_DIR/" 2>/dev/null || true
  cp "$REPO_DIR/hypr/bindings.lua" "$CONFIG_DIR/hypr/bindings.lua"
  log_sub "Applied full-topping keybindings (SUPER+E, SUPER+B, SUPER+ALT+C, SUPER+SHIFT+K)"
fi

# 5.4 Display / Monitors
if [[ ! -f "$CONFIG_DIR/hypr/monitors.lua" && -f "$REPO_DIR/hypr/monitors.lua" ]]; then
  cp "$REPO_DIR/hypr/monitors.lua" "$CONFIG_DIR/hypr/monitors.lua"
  log_sub "Initialized default display configuration"
elif [[ -f "$CONFIG_DIR/hypr/monitors.lua" ]] && ! grep -q "ELECTRON_OZONE_PLATFORM_HINT" "$CONFIG_DIR/hypr/monitors.lua"; then
  # Preserve user custom monitor positions but ensure crisp Wayland toolkit variables
  cat << 'EOF' >> "$CONFIG_DIR/hypr/monitors.lua"

-- Virtual☆Paradise Toolkit & Wayland Envs
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("XCURSOR_SIZE", "24")
EOF
  log_sub "Injected Wayland toolkit environment variables into ~/.config/hypr/monitors.lua"
fi

# 5.5 Autostart: ensure live wallpaper hook is present
if [[ -f "$CONFIG_DIR/hypr/autostart.lua" ]]; then
  if ! grep -q "toggle_live_wallpaper.sh" "$CONFIG_DIR/hypr/autostart.lua"; then
    echo 'o.launch_on_start("toggle_live_wallpaper.sh init")' >> "$CONFIG_DIR/hypr/autostart.lua"
    log_sub "Hooked live wallpaper to ~/.config/hypr/autostart.lua"
  fi
elif [[ -f "$REPO_DIR/hypr/autostart.lua" ]]; then
  cp "$REPO_DIR/hypr/autostart.lua" "$CONFIG_DIR/hypr/autostart.lua"
fi

# 5.6 Window Rules (Btop, Voxtype, Cast Screen, Nautilus)
if [[ -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
  if ! grep -q "GNOME Network Displays" "$CONFIG_DIR/hypr/hyprland.lua"; then
    cat << 'EOF' >> "$CONFIG_DIR/hypr/hyprland.lua"

-- Virtual Paradise Add-on Window Rules
o.window({ initial_title = "Btop Monitor" }, { float = true, size = { 1050, 650 }, center = true })
o.window({ title = "Btop Monitor" }, { float = true, size = { 1050, 650 }, center = true })
o.window({ initial_title = "Voxtype Config" }, { float = true, size = { 880, 580 }, center = true })
o.window({ title = "Voxtype Config" }, { float = true, size = { 880, 580 }, center = true })
o.window({ initial_title = "GNOME Network Displays" }, { float = true, size = { 720, 560 }, center = true })
o.window({ title = "GNOME Network Displays" }, { float = true, size = { 720, 560 }, center = true })
o.window({ class = "org.gnome.NetworkDisplays" }, { float = true, size = { 720, 560 }, center = true })
o.window({ class = "org.gnome.Nautilus", title = "File Operation Progress" }, { float = true })
o.window({ class = "org.gnome.Nautilus", title = ".*Properties.*" }, { float = true })
EOF
    log_sub "Configured floating window rules for Btop, Voxtype, Cast Screen & Nautilus"
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

# 5.5 Fcitx5 Vietnamese Input Method (Unikey) Configuration
CONFIGURE_FCITX_UNIKEY() {
  command -v fcitx5 &>/dev/null || return 0

  local fcitx_dir="$CONFIG_DIR/fcitx5"
  local fcitx_profile="$fcitx_dir/profile"
  mkdir -p "$fcitx_dir"

  if [[ ! -f "$fcitx_profile" ]]; then
    cat << 'EOF' > "$fcitx_profile"
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
EOF
    log_sub "Initialized Fcitx5 profile with US Keyboard and Unikey"
  elif ! grep -q "Name=unikey" "$fcitx_profile"; then
    local next_idx=0
    while grep -q "^\[Groups/0/Items/${next_idx}\]" "$fcitx_profile"; do
      next_idx=$((next_idx + 1))
    done
    cat << EOF >> "$fcitx_profile"

[Groups/0/Items/${next_idx}]
Name=unikey
Layout=
EOF
    log_sub "Added Unikey input method to existing Fcitx5 profile (slot ${next_idx})"
  fi

  if pgrep -x fcitx5 &>/dev/null; then
    fcitx5-remote -r 2>/dev/null || systemctl --user restart omarchy-fcitx5.service 2>/dev/null || true
  fi
}
CONFIGURE_FCITX_UNIKEY

# ------------------------------------------------------------------------------
# 6. Install Helper Scripts & Binaries
# ------------------------------------------------------------------------------
log_step "6" "$TOTAL_STEPS" "Installing binaries & CLI helper tools to $LOCAL_BIN..."
# Ensure Omarchy default commands and official Antigravity CLI (agy) are never shadowed
rm -f "$LOCAL_BIN/omarchy-agent" \
      "$LOCAL_BIN/omarchy-launch-terminal" \
      "$LOCAL_BIN/omarchy-system-logout" \
      "$LOCAL_BIN/omarchy-system-reboot" \
      "$LOCAL_BIN/omarchy-system-shutdown" \
      "$LOCAL_BIN/agy-offline" \
      "$LOCAL_BIN/agy-local" 2>/dev/null || true

if [[ -d "$REPO_DIR/bin" ]]; then
  rm -rf "$LOCAL_BIN/__pycache__" 2>/dev/null || true
  rsync -a --exclude='__pycache__' "$REPO_DIR"/bin/ "$LOCAL_BIN/"
  chmod +x "$LOCAL_BIN"/*.sh "$LOCAL_BIN"/*.py "$LOCAL_BIN"/momoisay "$LOCAL_BIN"/momoisay.real 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_agent.py" "$LOCAL_BIN/paradise-agent" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_agent.py" "$LOCAL_BIN/offline-agent" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/virtual_matrix.py" "$LOCAL_BIN/virtual_matrix" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/cast_screen.sh" "$LOCAL_BIN/cast-screen" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/format-docx" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/vn-docx" 2>/dev/null || true
  chmod +x "$LOCAL_BIN/sync_cava_theme.py" "$LOCAL_BIN/virtual_matrix.py" "$LOCAL_BIN/cast_screen.sh" "$LOCAL_BIN/format-docx-vn.py" 2>/dev/null || true
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
  [[ -f "$CONFIG_DIR/gtk-4.0/gtk.css" && ! -f "$CONFIG_DIR/gtk-4.0/gtk.css.bak_default" ]] && cp "$CONFIG_DIR/gtk-4.0/gtk.css" "$CONFIG_DIR/gtk-4.0/gtk.css.bak_default" 2>/dev/null || true
  [[ -f "$CONFIG_DIR/gtk-3.0/gtk.css" && ! -f "$CONFIG_DIR/gtk-3.0/gtk.css.bak_default" ]] && cp "$CONFIG_DIR/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css.bak_default" 2>/dev/null || true
  cp "$REPO_DIR/config/gtk.css" "$CONFIG_DIR/gtk-4.0/gtk.css"
  cp "$REPO_DIR/config/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css"
fi
if command -v gsettings &>/dev/null; then
  gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-dracula-dark" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" 2>/dev/null || true
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

# Flatten assets (preview.png, unlock.png) into theme root for Omarchy theme picker & Plymouth switcher
if [[ -d "$THEME_DEST/assets" ]]; then
  cp -f "$THEME_DEST/assets/preview.png" "$THEME_DEST/preview.png" 2>/dev/null || true
  cp -f "$THEME_DEST/assets/unlock.png" "$THEME_DEST/unlock.png" 2>/dev/null || true
  cp -f "$THEME_DEST/assets/unlock.png" "$THEME_DEST/preview-unlock.png" 2>/dev/null || true
  log_sub "Flattened assets/ (preview.png, unlock.png) to Omarchy theme root"
fi

# Post-theme-set hook
cat << 'EOF' > "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
#!/bin/bash
THEME_NAME="$1"

# 1. Sync Cava visualizer colors to the newly selected theme
if [[ -x "$HOME/.local/bin/sync_cava_theme.py" ]]; then
  python3 "$HOME/.local/bin/sync_cava_theme.py" "$THEME_NAME" >/dev/null 2>&1 || true
fi

# 2. Theme-specific setup
if [[ "$THEME_NAME" == "virtual-paradise" ]]; then
# Use hyprmoncfg in place of the cloned Display & Scaling widget.
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin enable "crmne.hyprmoncfg" >/dev/null 2>&1 || true
  omarchy plugin disable "${USER}.monitor" >/dev/null 2>&1 || true
  omarchy plugin disable "omarchy.monitor" >/dev/null 2>&1 || true
fi

  # Activate Virtual Paradise Fastfetch config
  if [[ -f "$HOME/.config/fastfetch/virtual-paradise.jsonc" ]]; then
    cp "$HOME/.config/fastfetch/virtual-paradise.jsonc" "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null || true
  fi

  # Apply Virtual Paradise Bar Layout only if it changed
  if [[ -f "$HOME/.config/omarchy/shell-paradise.json" ]]; then
    if ! cmp -s "$HOME/.config/omarchy/shell-paradise.json" "$HOME/.config/omarchy/shell.json" 2>/dev/null; then
      cp "$HOME/.config/omarchy/shell-paradise.json" "$HOME/.config/omarchy/shell.json"
      omarchy-restart-shell >/dev/null 2>&1 || true
    fi
  fi

  # Apply Virtual Paradise GTK styling
  if [[ -f "$HOME/.config/omarchy/themes/virtual-paradise/config/gtk.css" ]]; then
    mkdir -p "$HOME/.config/gtk-4.0" "$HOME/.config/gtk-3.0"
    cp "$HOME/.config/omarchy/themes/virtual-paradise/config/gtk.css" "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null || true
    cp "$HOME/.config/omarchy/themes/virtual-paradise/config/gtk.css" "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null || true
  fi

  # Start live video wallpaper (only if not already running)
  if [[ -x "$HOME/.local/bin/toggle_live_wallpaper.sh" ]]; then
    if ! pgrep -f mpvpaper >/dev/null 2>&1; then
      "$HOME/.local/bin/toggle_live_wallpaper.sh" init >/dev/null 2>&1 || true
    fi
  fi
else
  # Restore the cloned Display & Scaling widget outside this theme.
  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin disable "crmne.hyprmoncfg" >/dev/null 2>&1 || true
    omarchy plugin enable "${USER}.monitor" >/dev/null 2>&1 || true
  fi

  # Cleanly stop live video wallpaper so new theme background displays properly
  pkill -f mpvpaper 2>/dev/null || true

  # Restore default Fastfetch (Arch/Omarchy logo with native terminal colors)
  rm -f "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null || true

  # Restore default GTK CSS so other themes keep their native look
  if [[ -f "$HOME/.config/gtk-4.0/gtk.css.bak_default" ]]; then
    cp "$HOME/.config/gtk-4.0/gtk.css.bak_default" "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null || true
  else
    rm -f "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null || true
  fi
  if [[ -f "$HOME/.config/gtk-3.0/gtk.css.bak_default" ]]; then
    cp "$HOME/.config/gtk-3.0/gtk.css.bak_default" "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null || true
  else
    rm -f "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null || true
  fi

  # Restore canonical default Omarchy Bar Layout only if it changed
  if [[ -f "$HOME/.config/omarchy/shell-default.json" ]]; then
    if ! cmp -s "$HOME/.config/omarchy/shell-default.json" "$HOME/.config/omarchy/shell.json" 2>/dev/null; then
      cp "$HOME/.config/omarchy/shell-default.json" "$HOME/.config/omarchy/shell.json"
      omarchy-restart-shell >/dev/null 2>&1 || true
    fi
  fi
fi
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

# 10.1 Install Oh My Zsh framework & plugins if missing
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log_sub "Installing Oh My Zsh framework..."
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" >/dev/null 2>&1 || true
fi

mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
[[ -d /usr/share/zsh/plugins/zsh-autosuggestions ]] && ln -nsf /usr/share/zsh/plugins/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null || true
[[ -d /usr/share/zsh/plugins/zsh-syntax-highlighting ]] && ln -nsf /usr/share/zsh/plugins/zsh-syntax-highlighting "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true
if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-completions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" >/dev/null 2>&1 || true
fi

# 10.2 Synchronize full-topping zshrc
if [[ -f "$REPO_DIR/shell/zshrc" ]]; then
  [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)" 2>/dev/null || true
  cp "$REPO_DIR/shell/zshrc" "$HOME/.zshrc"
  log_sub "Synchronized full-topping ~/.zshrc shell configuration"
fi

# 10.3 Ensure default shell is Zsh
if command -v zsh &>/dev/null; then
  CURRENT_LOGIN_SHELL=$(getent passwd "$CURRENT_USER" | cut -d: -f7)
  if [[ "$CURRENT_LOGIN_SHELL" != "$(command -v zsh)" ]]; then
    log_sub "Setting default login shell to Zsh for '${CURRENT_USER}'..."
    $SUDO_CMD chsh -s "$(command -v zsh)" "$CURRENT_USER" 2>/dev/null || chsh -s "$(command -v zsh)" 2>/dev/null || true
  fi
  systemctl --user set-environment SHELL="$(command -v zsh)" 2>/dev/null || true
  hyprctl eval "hl.env('SHELL', '$(command -v zsh)')" 2>/dev/null || true
  if [[ -f "$CONFIG_DIR/ghostty/config" ]] && ! grep -q "^command = " "$CONFIG_DIR/ghostty/config"; then
    sed -i '/^# Window/a command = /usr/bin/zsh' "$CONFIG_DIR/ghostty/config" 2>/dev/null || true
  fi
fi

configure_shell_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  # Ensure $LOCAL_BIN is in PATH
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$file" && ! grep -q 'PATH=.*/\.local/bin' "$file"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$file"
  fi

  # Purge any legacy agy alias that shadows official Antigravity CLI
  sed -i '/alias agy=/d' "$file" 2>/dev/null || true

  # Add Virtual Paradise aliases
  if ! grep -q "paradise-agent" "$file"; then
    cat << 'EOF' >> "$file"

# ==============================================================================
#  Virtual☆Paradise Add-on Aliases & Integration
# ==============================================================================
alias pa="paradise-agent"
alias offline-agent="paradise-agent"
alias rice="$HOME/.local/bin/rice_layout.sh"
alias matrix="$HOME/.local/bin/virtual_matrix.py"
alias boost="$HOME/.local/bin/toggle_cooler_boost.sh"
alias cast="$HOME/.local/bin/cast_screen.sh"
EOF
  fi

  # Add fastfetch aliases
  if ! grep -q "alias ff=" "$file"; then
    echo "alias ff='fastfetch'" >> "$file"
  fi
  if ! grep -q "alias ffa=" "$file"; then
    echo "alias ffa='fastfetch --logo ~/.config/fastfetch/logo_anime.txt'" >> "$file"
  fi

  # Add cyberpunk error border hook
  if ! grep -q "__omarchy_error_border_hook" "$file" && ! grep -q "_omarchy_error_border_hook" "$file"; then
    if [[ "$file" == *".bashrc"* ]]; then
      cat << 'EOF' >> "$file"

# ==============================================================================
#  CYBERPUNK WINDOW ERROR SHAKE & BLAZING NEON RED GLOW HOOK (BASH)
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
    elif [[ "$file" == *".zshrc"* ]]; then
      cat << 'EOF' >> "$file"

# ==============================================================================
#  CYBERPUNK WINDOW ERROR SHAKE & BLAZING NEON RED GLOW HOOK (ZSH)
# ==============================================================================
typeset -g __omarchy_last_err_state=0

__omarchy_error_border_hook() {
  local exit_code=$?
  if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    if [[ $exit_code -ne 0 && $__omarchy_last_err_state -eq 0 ]]; then
      __omarchy_last_err_state=1
      (~/.local/bin/hypr_window_error_shake.sh &>/dev/null &!)
    elif [[ $exit_code -eq 0 && $__omarchy_last_err_state -ne 0 ]]; then
      __omarchy_last_err_state=0
      (~/.local/bin/hypr_window_error_restore.sh &>/dev/null &!)
    fi
  fi
  return $exit_code
}

autoload -Uz add-zsh-hook 2>/dev/null || true
add-zsh-hook precmd __omarchy_error_border_hook 2>/dev/null || precmd_functions+=(__omarchy_error_border_hook)
EOF
    fi
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
    if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
      sudo -u "$CURRENT_USER" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$CURRENT_USER")}" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" omarchy theme set "$THEME_NAME" 2>/dev/null || true
      sudo -u "$CURRENT_USER" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$CURRENT_USER")}" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" omarchy theme bg cache 2>/dev/null || true
      sudo -u "$CURRENT_USER" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$CURRENT_USER")}" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" omarchy restart shell 2>/dev/null || true
    else
      omarchy theme set "$THEME_NAME" 2>/dev/null || true
      omarchy theme bg cache 2>/dev/null || true
      omarchy restart shell 2>/dev/null || true
    fi

    # Theme activation can restart the shell and briefly race plugin
    # discovery, so enforce the notification center state last.
    if command -v omarchy &>/dev/null; then
      if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        sudo -u "$CURRENT_USER" \
          WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
          HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" \
          XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$CURRENT_USER")}" \
          DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
          omarchy plugin enable "jankeesvw.notification-center" 2>/dev/null || \
          log_warn "Notification center could not be enabled after theme activation."
      else
        omarchy plugin enable "jankeesvw.notification-center" 2>/dev/null || \
          log_warn "Notification center could not be enabled after theme activation."
      fi
    fi
  fi

  if command -v hyprctl &>/dev/null; then
    if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
      sudo -u "$CURRENT_USER" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$CURRENT_USER")}" hyprctl reload 2>/dev/null || true
    else
      hyprctl reload 2>/dev/null || true
    fi
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
  echo -e "   ${C_GREEN}SUPER + ALT + C${C_RESET}       ➔ Toggle Cooler Boost fan cooling"
  echo -e "   ${C_GREEN}SUPER + SHIFT + K${C_RESET}     ➔ Cast Screen (Wireless Display)"
  echo -e "   ${C_GREEN}ffa${C_RESET}                   ➔ Launch Fastfetch with high-res Anime Braille logo"
  echo -e "   ${C_GREEN}f${C_RESET}                     ➔ Search☆Hub (Explorer, History, Process)"
  echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────${C_RESET}\n"
fi
