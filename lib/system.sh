#!/usr/bin/env bash
# Virtual Paradise - system setup: hardware detection, package installation and
# per-vendor configuration.
#
# Sourced by install.sh once the logging helpers, RUN_AS_INSTALL_USER and
# run_privileged are defined, and before step 1 runs. These functions read the
# caller's globals (REPO_DIR, CONFIG_DIR, LOCAL_BIN, CURRENT_USER, HAVE_SUDO)
# and write nothing outside the paths install.sh has already prepared.
#
# Split out of install.sh purely for size: the installer had grown a single
# 500-line block of detection and vendor branches in the middle of its step
# sequence, which made the sequencing hard to follow.

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
    "wtype"
  )
  local AUR_PKGS=(
    "mpvpaper"
    "gnome-network-displays"
    "hyprmoncfg"
    "voxtype-bin"
  )

  local HW_VENDOR HW_PRODUCT HW_CHASSIS
  HW_VENDOR=$(detect_hardware_vendor)
  HW_PRODUCT=$(detect_product_name)
  HW_CHASSIS=$(detect_chassis_type)

  log_sub "Detected Hardware: ${HW_VENDOR} ${HW_PRODUCT} (${HW_CHASSIS})"

  case "${HW_VENDOR,,}" in
    *acer*)
      if [[ -d "/sys/module/acer_nitro_ec" ]] || pacman -Qs acer-nitro-ec &>/dev/null; then
        log_sub "Acer Nitro EC fan driver is active"
      elif command -v nbfc &>/dev/null || pacman -Qs nbfc &>/dev/null; then
        log_sub "NoteBook FanControl is active"
      else
        log_sub "Acer hardware detected: adding Acer Nitro EC fan driver (acer-nitro-ec-dkms)..."
        REQUIRED_PKGS+=("linux-headers")
        AUR_PKGS+=("acer-nitro-ec-dkms")
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
    if [[ $HAVE_SUDO -eq 1 ]]; then
      log_sub "Installing official packages: ${OFFICIAL_TO_INSTALL[*]}"
      if command -v pacman &>/dev/null; then
        # Do not swallow this: a bad package name or a declined key import used
        # to fail silently and still print the success banner at the end.
        if ! run_privileged pacman -S --needed --noconfirm "${OFFICIAL_TO_INSTALL[@]}"; then
          log_warn "pacman failed. Install manually: ${OFFICIAL_TO_INSTALL[*]}"
        fi
      fi
    else
      log_warn "Sudo privileges unavailable. Missing official packages must be installed manually: ${OFFICIAL_TO_INSTALL[*]}"
    fi
  fi

  if [[ ${#AUR_TO_INSTALL[@]} -gt 0 ]]; then
    log_sub "Installing AUR packages: ${AUR_TO_INSTALL[*]}"
    if command -v yay &>/dev/null; then
      if ! RUN_AS_INSTALL_USER yay -S --needed --noconfirm "${AUR_TO_INSTALL[@]}"; then
        log_warn "yay failed. Install manually: ${AUR_TO_INSTALL[*]}"
      fi
    elif command -v paru &>/dev/null; then
      if ! RUN_AS_INSTALL_USER paru -S --needed --noconfirm "${AUR_TO_INSTALL[@]}"; then
        log_warn "paru failed. Install manually: ${AUR_TO_INSTALL[*]}"
      fi
    else
      log_warn "AUR helper (yay/paru) not found. Please install manually: ${AUR_TO_INSTALL[*]}"
    fi
  fi

  if [[ ${#OFFICIAL_TO_INSTALL[@]} -eq 0 && ${#AUR_TO_INSTALL[@]} -eq 0 ]]; then
    log_sub "All required packages are satisfied"
  fi
}
CONFIGURE_DEFAULT_APPS() {
  log_sub "Configuring Omarchy defaults: Ghostty, Nautilus, VS Code & GitHub Copilot..."

  if command -v omarchy &>/dev/null; then
    if command -v ghostty &>/dev/null; then
      RUN_AS_INSTALL_USER omarchy default terminal ghostty 2>/dev/null || \
        log_warn "Could not set Ghostty as the Omarchy default terminal."
    fi
    # Configure default agent safely without triggering interactive agent launch
    if [[ ! -s "$CONFIG_DIR/omarchy/defaults/agent" ]]; then
      if command -v copilot &>/dev/null || RUN_AS_INSTALL_USER command -v copilot &>/dev/null || pacman -Qi github-copilot-cli &>/dev/null || (command -v mise &>/dev/null && RUN_AS_INSTALL_USER mise where copilot &>/dev/null); then
        mkdir -p "$CONFIG_DIR/omarchy/defaults"
        printf '%s\n' "copilot" > "$CONFIG_DIR/omarchy/defaults/agent"
        if command -v mise &>/dev/null; then
          RUN_AS_INSTALL_USER mise use -g copilot >/dev/null 2>&1 || true
        fi
        log_sub "Configured GitHub Copilot as the Omarchy default agent"
      fi
    else
      log_sub "Preserving existing Omarchy default agent ($(cat "$CONFIG_DIR/omarchy/defaults/agent" 2>/dev/null))"
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

  if [[ $HAVE_SUDO -eq 1 ]]; then
    log_sub "Optimizing NVIDIA GPU persistence and compute startup..."
    run_privileged systemctl enable --now nvidia-persistenced.service 2>/dev/null || \
      log_warn "Could not enable nvidia-persistenced.service."
    run_privileged nvidia-smi -pm 1 >/dev/null 2>&1 || \
      log_warn "Could not enable NVIDIA persistence mode."
  else
    log_sub "NVIDIA GPU detected (persistence service requires sudo; skipped)"
  fi
}
CONFIGURE_HARDWARE_DRIVERS() {
  local HW_VENDOR HW_PRODUCT
  HW_VENDOR=$(detect_hardware_vendor)
  HW_PRODUCT=$(detect_product_name)

  if [[ $HAVE_SUDO -eq 0 ]]; then
    log_sub "Hardware driver udev rules require sudo; skipping hardware sysfs modifications"
    return 0
  fi

  case "${HW_VENDOR,,}" in
    *acer*)
      if [[ -d "/sys/module/acer_nitro_ec" ]] || pacman -Qs acer-nitro-ec &>/dev/null; then
        if [[ ! -d "/sys/module/acer_nitro_ec" ]]; then
          run_privileged modprobe acer-nitro-ec 2>/dev/null || true
        fi
        log_sub "Configuring Acer Nitro EC fan driver & udev permissions..."
        run_privileged bash -c 'cat << "EOF" > /etc/udev/rules.d/99-acer-nitro-fan.rules
ACTION=="add|change", SUBSYSTEM=="hwmon", ATTR{name}=="acer_nitro_ec|acer-nitro-ec|acer[-_]nitro[-_]ec", RUN+="/usr/bin/chmod 0666 /sys%p/pwm1_enable /sys%p/pwm2_enable /sys%p/pwm1 /sys%p/pwm2"
ACTION=="add|change", SUBSYSTEM=="hwmon", KERNEL=="hwmon*", DEVPATH=="*/acer-nitro-ec/hwmon/*", RUN+="/usr/bin/chmod 0666 /sys%p/pwm1_enable /sys%p/pwm2_enable /sys%p/pwm1 /sys%p/pwm2"
EOF'
        run_privileged udevadm control --reload-rules 2>/dev/null || true
        run_privileged udevadm trigger --subsystem-match=hwmon 2>/dev/null || true

        # Immediately apply 0666 permissions to any active hwmon fan nodes
        for h in /sys/class/hwmon/hwmon*; do
          if [[ -r "$h/name" ]]; then
            local n
            n=$(< "$h/name")
            if [[ "$n" == "acer_nitro_ec" || "$n" == "acer-nitro-ec" ]]; then
              run_privileged chmod 0666 "$h"/pwm* 2>/dev/null || true
              log_sub "Granted direct user control to fan sysfs at $h"
            fi
          fi
        done
      fi

      if command -v nbfc &>/dev/null; then
        log_sub "Activating NoteBook FanControl service for Acer..."
        run_privileged systemctl enable --now nbfc_service 2>/dev/null || true
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
        run_privileged systemctl enable --now asusd.service 2>/dev/null || true
      fi
      ;;
    *)
      if command -v nbfc &>/dev/null; then
        log_sub "Activating NoteBook FanControl service for ${HW_VENDOR}..."
        run_privileged systemctl enable --now nbfc_service 2>/dev/null || true
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
