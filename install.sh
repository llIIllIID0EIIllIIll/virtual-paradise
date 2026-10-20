#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Full-Topping Rice & Universal Theme Automated Installer
# ==============================================================================
#  GitHub: https://github.com/llIIllIID0EIIllIIll/virtual-paradise
#  Compatible with: Omarchy Linux 4.0+ (Arch Linux + Hyprland)
# ==============================================================================

set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared plugin override layer: theme colours, QML rice and API compatibility
# fixes applied to installed Omarchy plugins. Kept in lib/ so the updater
# (bin/update-plugins.sh) can revert and re-apply exactly the same layer.
# That matters because `omarchy plugin update` fast-forwards with --ff-only and
# refuses to touch a checkout that this layer has left dirty.
export PARADISE_REPO_DIR="$REPO_DIR"
# shellcheck source=lib/plugin-overrides.sh
. "$REPO_DIR/lib/plugin-overrides.sh"
THEME_NAME="virtual-paradise"
IS_HOOK=0
ENABLE_BOOT=1
BOOT_ONLY=0
SDDM_ONLY=0
USER_ONLY=0

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
    --sddm-only)
      # Reinstall just the login theme; no Plymouth, no initramfs rebuild.
      SDDM_ONLY=1
      ENABLE_BOOT=0
      ;;
    --no-sudo|--user-only)
      USER_ONLY=1
      ENABLE_BOOT=0
      ;;
    --dry-run)
      # There is no preview mode: the installer writes to ~/.config, ~/.local
      # and /usr/share and restarts the shell. Refuse loudly rather than look
      # like it did nothing while changing the machine anyway.
      printf 'install.sh: --dry-run is not supported — nothing was installed.\n' >&2
      exit 2
      ;;
  esac
done

# Detect real user & home directory even when executed via sudo
if (( EUID == 0 )); then
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    CURRENT_USER="$SUDO_USER"
    # getent can fail (no NSS entry, broken dir service); under set -e that
    # would abort the installer on a machine it can otherwise configure.
    USER_HOME="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f6 || true)"
    [[ -n $USER_HOME ]] || USER_HOME="$HOME"
    export HOME="$USER_HOME"
  else
    CURRENT_USER="${USER:-$(id -un)}"
  fi
  SUDO_CMD=""
  # --user-only is a promise not to touch system paths, and it has to hold even
  # when the script runs as root (CI containers, `su`, the test suite). Without
  # this, EUID==0 silently turns user-only runs into real installs: /etc/udev,
  # /usr/lib/systemd, SDDM and Plymouth all get written.
  if (( USER_ONLY == 1 )); then
    HAVE_SUDO=0
  else
    HAVE_SUDO=1
  fi
else
  CURRENT_USER="${USER:-$(id -un)}"
  HAVE_SUDO=0
  if [[ $USER_ONLY -eq 0 ]] && command -v sudo &>/dev/null; then
    if sudo -n true 2>/dev/null; then
      HAVE_SUDO=1
      SUDO_CMD="sudo"
    elif [[ -t 0 && $IS_HOOK -eq 0 ]]; then
      echo -e "\033[38;2;0;245;212m🔑 Virtual☆Paradise requires sudo privileges for hardware drivers & boot setup.\033[0m"
      echo -e "\033[2m   Please enter your sudo password:\033[0m"
      if sudo -v; then
        HAVE_SUDO=1
        SUDO_CMD="sudo"
      else
        echo -e "\033[38;2;255;0;85m❌ Sudo authentication failed. Aborting.\033[0m"; exit 1;
      fi
    else
      SUDO_CMD=""
      if [[ $IS_HOOK -eq 0 ]]; then
        echo -e "\033[38;2;255;183;213mℹ️ Sudo credentials not cached in non-interactive session; running in user-space mode.\033[0m"
      fi
    fi
    if [[ $HAVE_SUDO -eq 1 && $IS_HOOK -eq 0 ]]; then
      # Keep sudo timestamp alive in background until install completes.
      # `$!` must be captured from the parent shell: wrapping the loop in
      # "( ... & )" forks a subshell that starts no job of its own, so `$!`
      # stayed empty and the loop leaked past exit.
      while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
      SUDO_KEEP_ALIVE_PID=$!
    fi
  else
    SUDO_CMD=""
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

# `omarchy restart shell` returns as soon as the old shell is signalled, and the
# replacement answers "omarchy-shell is not responding" for the first few
# seconds, so a plugin enable issued straight afterwards fails even though the
# plugin exists. Retry for up to ~15s, and keep the last error message so a real
# failure is reported with its cause instead of a bare warning.
LAST_PLUGIN_ERROR=""
enable_plugin_retry() {
  local plugin_id="$1" out
  local attempt=0
  LAST_PLUGIN_ERROR=""
  while (( attempt < 15 )); do
    attempt=$((attempt + 1))
    if out=$(RUN_AS_INSTALL_USER omarchy plugin enable "$plugin_id" 2>&1); then
      return 0
    fi
    LAST_PLUGIN_ERROR="$out"
    sleep 1
  done
  return 1
}


# Color helpers
C_CYAN="\033[38;2;0;245;212m"
C_GREEN="\033[38;2;0;255;136m"
C_PINK="\033[38;2;255;183;213m"
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
  if command -v python3 &>/dev/null && [[ -f "$REPO_DIR/bin/paradise_banner.py" ]]; then
    python3 "$REPO_DIR/bin/paradise_banner.py" 2>/dev/null || true
  fi
  echo -e "${C_CYAN}===================================================================================================================${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}  🌸 Virtual☆Paradise${C_RESET} ${C_GREEN}— Cyberpunk Rice & Theme Installer${C_RESET}"
  echo -e "${C_DIM}  Target User: ${C_PINK}${CURRENT_USER}${C_RESET} ${C_DIM}| Platform: Omarchy / Hyprland${C_RESET}"
  echo -e "${C_CYAN}===================================================================================================================${C_RESET}"
fi

# ------------------------------------------------------------------------------
# Boot & Shutdown Animations Setup Function (Shared by full and --boot-only mode)
# ------------------------------------------------------------------------------
# Run a privileged command only when elevation is actually available.
# $SUDO_CMD is empty when the installer could not obtain sudo (non-interactive
# hook, --user-only), so bare "$SUDO_CMD cmd" would silently run unprivileged
# and fail halfway through the boot setup instead of being skipped cleanly.
run_privileged() {
  # USER_ONLY is checked before EUID: root does not override an explicit
  # request to leave the system alone. Not going through sudo here is what
  # keeps `install.sh --user-only` safe to run inside a container or as root.
  if (( USER_ONLY == 1 )); then
    log_warn "Skipping privileged step: --user-only was requested."
    return 1
  fi
  local can_sudo=0
  if (( EUID == 0 )); then
    can_sudo=1
  elif [[ -n "${SUDO_CMD:-}" ]] && sudo -n true 2>/dev/null; then
    can_sudo=1
  elif command -v sudo &>/dev/null && [[ -t 0 ]]; then
    log_info "  ${C_PINK}🔑 Requesting sudo permission for system-wide setup...${C_RESET}"
    if sudo -v; then
      SUDO_CMD="sudo"
      can_sudo=1
    fi
  fi

  if [[ $can_sudo -eq 0 ]]; then
    log_warn "Skipping privileged step: no sudo available."
    return 1
  fi
  if (( EUID == 0 )); then
    "$@"
  else
    $SUDO_CMD "$@"
  fi
}

# Mirror or merge a directory tree. rsync is in the package list and step 1
# installs it, but --user-only runs, containers and non-Omarchy distros may not
# have it; a missing tool must not turn into a silent half-install.
sync_tree() {
  local src="$1" dst="$2" mode="${3:-merge}"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    if [[ $mode == mirror ]]; then
      rsync -a --delete "$src"/ "$dst"/
    else
      rsync -a "$src"/ "$dst"/
    fi
    return 0
  fi
  if [[ $mode == mirror ]]; then
    rm -rf "${dst:?}"
    mkdir -p "$dst"
  fi
  cp -a "$src"/. "$dst"/
}

# Hardware detection, package installation and per-vendor setup. Sourced here so
# those functions exist before step 1 calls them, and after the helpers above,
# which they use.
# shellcheck source=lib/system.sh
. "$REPO_DIR/lib/system.sh"

# Install (or reinstall) only the SDDM login theme. Shared by the full install,
# --boot-only and --sddm-only so all three use exactly the same code path.
INSTALL_SDDM_THEME() {
  [[ -f "$REPO_DIR/lib/sddm.sh" ]] || return 1
  run_privileged bash -c \
    '. "$1/lib/sddm.sh" && sddm_theme_install "/" "$1"' _ "$REPO_DIR"
}

INSTALL_BOOT_ANIMATIONS() {
  log_step "9" "$TOTAL_STEPS" "Configuring Plymouth Boot Animation, SDDM Display Manager & UKI Kernel..."

  if [[ $ENABLE_BOOT -eq 1 ]] && run_privileged true; then
    # 1. SDDM Setup
    #
    # The theme goes into its own directory and is selected with a drop-in;
    # patching /usr/share/sddm/themes/omarchy (owned by omarchy-settings) meant
    # a package update reverted half of it and uninstall.sh had nothing to
    # restore. sddm_theme_install also repairs machines that ran the old
    # in-place patch.
    if INSTALL_SDDM_THEME; then
      log_sub "Installed SDDM theme 'virtual-paradise' (Omarchy's theme left untouched)"
    else
      log_warn "SDDM theme was not installed; the login screen is unchanged."
    fi

    # 2. Plymouth Theme Setup
    local plymouth_theme_dir="/usr/share/plymouth/themes/omarchy"
    if [[ -d "$plymouth_theme_dir" ]]; then
      if [[ -f "$REPO_DIR/plymouth/omarchy.script" ]]; then
        run_privileged cp "$REPO_DIR/plymouth/omarchy.script" "$plymouth_theme_dir/omarchy.script"
      fi

      # Extract intro frames (259 frames) if missing
      if [[ ! -f "$plymouth_theme_dir/intro-259.png" ]] && [[ -f "$REPO_DIR/backgrounds/Miku_animated_full.mp4" ]]; then
        log_sub "Extracting 259 frames from Miku_animated_full.mp4 for Plymouth..."
        run_privileged ffmpeg -y -loglevel error -i "$REPO_DIR/backgrounds/Miku_animated_full.mp4" -vf "scale=1920:1080" "$plymouth_theme_dir/intro-%d.png"
      fi

      # Extract outro frames (72 frames) if missing
      if [[ ! -f "$plymouth_theme_dir/outro-72.png" ]] && [[ -f "$REPO_DIR/backgrounds/Miku_missing.mp4" ]]; then
        log_sub "Extracting 72 frames from Miku_missing.mp4 for Plymouth..."
        run_privileged ffmpeg -y -loglevel error -i "$REPO_DIR/backgrounds/Miku_missing.mp4" -vf "scale=1920:1080" "$plymouth_theme_dir/outro-%d.png"
      fi

      # Fallback single frame images
      if [[ -f "$plymouth_theme_dir/intro-1.png" ]]; then
        run_privileged cp "$plymouth_theme_dir/intro-1.png" "$plymouth_theme_dir/background.png" 2>/dev/null || true
      fi
      if [[ -f "$plymouth_theme_dir/outro-1.png" ]]; then
        run_privileged cp "$plymouth_theme_dir/outro-1.png" "$plymouth_theme_dir/background-shutdown.png" 2>/dev/null || true
      fi

      # Systemd overrides for instant Plymouth handover (no SDDM delay)
      run_privileged mkdir -p /etc/systemd/system/plymouth-poweroff.service.d /etc/systemd/system/plymouth-reboot.service.d
      if [[ -f "$REPO_DIR/plymouth/override.conf" ]]; then
        run_privileged cp "$REPO_DIR/plymouth/override.conf" "/etc/systemd/system/plymouth-poweroff.service.d/override.conf"
        run_privileged cp "$REPO_DIR/plymouth/override.conf" "/etc/systemd/system/plymouth-reboot.service.d/override.conf"
        run_privileged systemctl daemon-reload
      fi

      run_privileged plymouth-set-default-theme omarchy >/dev/null 2>&1 || true
      log_sub "Configured Plymouth theme with instant lazy-loading animation engine"

      # Rebuild UKI / initramfs
      if command -v limine-mkinitcpio &>/dev/null; then
        log_sub "Rebuilding UKI image with limine-mkinitcpio..."
        run_privileged limine-mkinitcpio >/dev/null 2>&1 || log_warn "limine-mkinitcpio failed; check boot partition."
      elif command -v mkinitcpio &>/dev/null; then
        log_sub "Rebuilding initramfs with mkinitcpio -P..."
        run_privileged mkinitcpio -P >/dev/null 2>&1 || log_warn "mkinitcpio failed."
      fi
    fi
  else
    log_warn "Sudo privileges not available. Skipping system-wide Plymouth/SDDM setup."
    log_warn "Run 'sudo ./install.sh --boot-only' to enable boot & shutdown animations."
    return 1
  fi
  return 0
}

if [[ $BOOT_ONLY -eq 1 ]]; then
  if INSTALL_BOOT_ANIMATIONS; then
    echo -e "\n${C_BOLD}${C_GREEN}✨ Boot and shutdown animations updated successfully!${C_RESET}\n"
  else
    echo -e "\n${C_BOLD}${C_PINK}⚠ Boot and shutdown animations were not updated (see warnings above).${C_RESET}\n"
    exit 1
  fi
  exit 0
fi

if [[ $SDDM_ONLY -eq 1 ]]; then
  if INSTALL_SDDM_THEME; then
    echo -e "\n${C_BOLD}${C_GREEN}✨ SDDM login theme installed.${C_RESET}\n"
    exit 0
  fi
  echo -e "\n${C_BOLD}${C_PINK}⚠ SDDM login theme was not installed (see warnings above).${C_RESET}\n"
  exit 1
fi

# ------------------------------------------------------------------------------
# 1. Check & Install Missing System Dependencies
# ------------------------------------------------------------------------------
# 1. Hardware Detection & Dependency Installation
# ------------------------------------------------------------------------------
log_step "1" "$TOTAL_STEPS" "Detecting hardware & installing required system packages..."

# Install Paradise Island Bar into Omarchy's bundled first-party plugin dir.
#
# First-party is a hard requirement, not a preference: the shell only hands a
# bar the full ShellRoot when manifest.__isFirstParty is set, and that flag
# comes from which directory the manifest was scanned in. A copy under
# ~/.config/omarchy/plugins would scan as third-party and every service-backed
# bar widget would silently lose its service.
#
# Idempotent: re-running replaces the tracked files and leaves anything else
# in the directory alone. Falls back to a warning instead of aborting the
# install when the bundle is not writable.
po_install_island_bar() {
  local src_dir="$REPO_DIR/bars/island-bar"
  local dest_root="/usr/share/omarchy/shell/plugins"
  local dest_dir="$dest_root/${CURRENT_USER}.island-bar"

  if [[ ! -d "$src_dir" ]]; then
    log_warn "Island Bar sources missing at $src_dir"
    return 1
  fi

  if [[ ! -w "$dest_root" && ! -d "$dest_dir" ]] && ! run_privileged true; then
    log_warn "Cannot write $dest_root and no sudo available — Paradise Island Bar skipped."
    log_info "  sudo mkdir -p '$dest_dir' && sudo cp -r '$src_dir'/* '$dest_dir'/"
    return 1
  fi

  run_privileged mkdir -p "$dest_dir" 2>/dev/null || {
    log_warn "Could not create $dest_dir — skipping Paradise Island Bar."
    return 1
  }

  # Substitute the repo's __USER__ placeholder so the deployed manifest carries
  # the installing user's plugin id. Stage through a user-owned temp dir: the
  # destination may be root-owned and not writable without elevation.
  local stage f src
  stage="$(mktemp -d)" || {
    log_warn "Could not create staging dir — skipping Paradise Island Bar."
    return 1
  }

  # Every file the bundle ships, rather than a hand-maintained subset: a QML
  # component added to bars/island-bar/ has to reach the deployed copy, or the
  # bar ends up importing a component that is not installed alongside it.
  for src in "$src_dir"/*.qml "$src_dir"/*.js "$src_dir"/*.json; do
    [[ -f $src ]] || continue
    f="$(basename "$src")"
    sed "s/__USER__/${CURRENT_USER}/g" "$src" >"$stage/$f" 2>/dev/null || {
      rm -rf "$stage"
      log_warn "Could not render $src"
      return 1
    }
    if ! run_privileged cp "$stage/$f" "$dest_dir/$f" 2>/dev/null; then
      # A pre-existing root-owned copy from an older run can block the write
      # even with sudo in play; surface it instead of failing silently.
      if ! run_privileged cp -f "$stage/$f" "$dest_dir/$f" 2>/dev/null; then
        rm -rf "$stage"
        log_warn "Could not write $dest_dir/$f"
        return 1
      fi
    fi
  done
  rm -rf "$stage"

  # The registry only rescans on demand, so ask for one now rather than
  # leaving the shell on the previous bar until the next restart.
  RUN_AS_INSTALL_USER omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  log_sub "Installed Paradise Island Bar to $dest_dir"
}

# The stock system tray reserves its entire drawer width even while collapsed,
# so a bar host never shrinks when the drawer is closed and never moves when it
# opens. Reserve only what is actually revealed instead.
#
# This is a stock Omarchy file, not ours, so it is edited in place rather than
# replaced: shipping a full copy would silently roll back any upstream fix the
# next time Omarchy updates the tray. The edit only lands when the exact
# upstream expression is still present, and uninstall.sh restores the saved
# original.
patch_system_tray() {
  # Disabled: reserving only the revealed drawer broke the tray's own layout.
  # Its clip region is drawerExtent wide and is expected to sit left of the
  # pinned items; narrowing it moved the pinned items under the drawer icons,
  # which then drew over them. Doing this properly means redesigning the
  # drawer's slide geometry, and a patch that deep would be lost on the next
  # Omarchy update. Left here as documentation, not called.
  return 0
  local tray="/usr/share/omarchy/shell/plugins/bar/widgets/Tray.qml"
  local orig="$tray.paradise.orig"
  [[ -f "$tray" ]] || return 0

  if grep -q 'expandIcon.implicitWidth + root.revealExtent' "$tray" 2>/dev/null; then
    log_sub "System tray already follows its drawer reveal"
    return 0
  fi
  if ! grep -q 'expandIcon.implicitWidth + root.drawerExtent' "$tray" 2>/dev/null; then
    log_warn "System tray layout differs upstream; skipping the drawer-reveal patch."
    return 0
  fi
  [[ -f "$orig" ]] || run_privileged cp "$tray" "$orig" 2>/dev/null || true
  if run_privileged sed -i \
    's/expandIcon\.implicitWidth + root\.drawerExtent/expandIcon.implicitWidth + root.revealExtent/' \
    "$tray" 2>/dev/null; then
    log_sub "Patched system tray to follow its drawer reveal"
  else
    log_warn "Could not patch the system tray (needs sudo)."
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

# Keep third-party bar icons on the active theme accent instead of the
# default bar foreground, which is intentionally white in some Omarchy setups.







# Resolve a plugin manifest entryPoint to a path relative to the plugin dir.
# Plugins may ship their QML inside a versioned runtime/<hash>/ tree, so an
# override copied to the plugin root would never be loaded by Quickshell.



# ------------------------------------------------------------------------------
# 3. Install & Enable Custom Omarchy Bar Plugins
# ------------------------------------------------------------------------------
INSTALL_AND_ENABLE_PLUGINS() {
  log_step "3" "$TOTAL_STEPS" "Installing and enabling custom Quickshell plugins for user '$CURRENT_USER'..."
  # These repo-owned clones were replaced by maintained external plugins.
  # Remove their installed copies so an install cannot briefly re-enable or
  # leave stale rice widgets in the plugin registry.
  local replaced_plugin
  for replaced_plugin in audio bluetooth monitor power workspaces media memory; do
    RUN_AS_INSTALL_USER omarchy plugin remove "${CURRENT_USER}.${replaced_plugin}" --yes 2>/dev/null || true
    rm -rf "$CONFIG_DIR/omarchy/plugins/${CURRENT_USER}.${replaced_plugin}"
  done
  if [[ -d "$REPO_DIR/plugins" ]]; then
    local count=0
    for pdir in "$REPO_DIR"/plugins/*; do
      if [[ -d "$pdir" && -n "$(find "$pdir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        local plugin_name
        plugin_name=$(basename "$pdir")
        local target_plugin_id="${CURRENT_USER}.${plugin_name}"
        local target_dir="$CONFIG_DIR/omarchy/plugins/$target_plugin_id"

        mkdir -p "$target_dir"
        # --delete, not cp: a file we rename or drop upstream would otherwise
        # linger here forever and keep loading, reintroducing removed widgets or
        # double-registering an IPC handler against the current one.
        sync_tree "$pdir" "$target_dir" mirror

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
      RUN_AS_INSTALL_USER omarchy-shell shell rescanPlugins 2>/dev/null || true
    fi

    # Explicitly activate and register each plugin in Omarchy
    if command -v omarchy &>/dev/null; then
      local enabled_count=0
      for pdir in "$REPO_DIR"/plugins/*; do
        if [[ -d "$pdir" && -n "$(find "$pdir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
          local pname
          pname=$(basename "$pdir")
          local pid="${CURRENT_USER}.${pname}"
          RUN_AS_INSTALL_USER omarchy plugin enable "$pid" 2>/dev/null || true
          enabled_count=$((enabled_count + 1))
        fi
      done
      po_apply_all
      log_sub "Enabled all ${enabled_count} Virtual Paradise plugins in Omarchy shell"

      # Install & enable external Omarchy webcam plugin
      if [[ ! -d "$CONFIG_DIR/omarchy/plugins/io.github.kristoferlund.webcam" ]] && ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.kristoferlund.webcam")' >/dev/null; then
        log_sub "Adding external Omarchy webcam plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/kristoferlund/omarchy-webcam.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.kristoferlund.webcam" 2>/dev/null || true
      fi

      # Install the notification center once, then ensure it stays enabled on
      # subsequent theme installations.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "jankeesvw.notification-center")' >/dev/null; then
        log_sub "Adding external Omarchy notification center plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/jankeesvw/omarchy-notification-center.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "jankeesvw.notification-center" 2>/dev/null || true
      fi

      # hyprmoncfg replaces the cloned Display & Scaling widget in this
      # theme. Keep the old widget disabled to avoid duplicate controls.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "crmne.hyprmoncfg")' >/dev/null; then
        log_sub "Adding external Omarchy monitor manager plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/crmne/omarchy-hyprmoncfg.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "crmne.hyprmoncfg" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.monitor" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.monitor" 2>/dev/null || true

      # Vitals replaces the memory-only widget in this theme's center bar slot.
      # It supersedes harshith.system-monitor, which could not show a GPU on
      # this machine: that plugin reads GPU telemetry from sysfs only, and the
      # proprietary NVIDIA driver exposes nothing there, so every GPU tile stayed
      # hidden. Vitals queries nvidia-smi and covers the same CPU/RAM/disk/net
      # data plus GPU, sensors and processes.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.woogy7.vitals")' >/dev/null; then
        log_sub "Adding external Vitals system monitor from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/Woogy7/omarchy-vitals.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.woogy7.vitals" 2>/dev/null || true
      fi
      # Retire the plugin Vitals supersedes, otherwise its RAM readout stays on
      # the bar next to Vitals' own chip.
      RUN_AS_INSTALL_USER omarchy plugin disable "harshith.system-monitor" 2>/dev/null || true
      po_apply_all
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.memory" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.memory" 2>/dev/null || true

      # Projector & Cast adds screen-mirroring controls to the right bar.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.jeffcortez23.omarchy-projector-cast")' >/dev/null; then
        log_sub "Adding external Projector & Cast plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/JeffCortez23/omarchy-projector-cast.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.jeffcortez23.omarchy-projector-cast" 2>/dev/null || true
      fi
      po_apply_all

      # The external power manager replaces the cloned Power & Battery widget.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "onlyvishesh.power-manager")' >/dev/null; then
        log_sub "Adding external Omarchy power manager plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/onlyVishesh/omarchy-power-manager.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "onlyvishesh.power-manager" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.power" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.power" 2>/dev/null || true

      # Extra bar widgets for the rice. Each is a self-contained Quickshell
      # plugin; the VPN widget needs a Proton account before it does anything,
      # and the radar downloads its engine from upstream Releases on first use.
      while IFS='|' read -r extra_id extra_url; do
        [[ -n $extra_id ]] || continue
        if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null |
             jq -e --arg i "$extra_id" 'any(.[]; .id == $i)' >/dev/null; then
          log_sub "Adding external plugin ${extra_id} from git..."
          RUN_AS_INSTALL_USER omarchy plugin add "$extra_url" --enable --yes 2>/dev/null || true
        else
          RUN_AS_INSTALL_USER omarchy plugin enable "$extra_id" 2>/dev/null || true
        fi
      done <<'EXTRA_PLUGINS'
io.github.randazraik.xray|https://github.com/RandaZraik/omarchy-xray
io.github.grichard99.omaproton-vpn|https://github.com/grichard99/omaproton-vpn
EXTRA_PLUGINS
      po_apply_all

      # Advanced Audio Control replaces the cloned Omarchy audio widget.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "ssupt.audio-control")' >/dev/null; then
        log_sub "Adding external Omarchy audio control plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/ssupt/omarchy-audio-control.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "ssupt.audio-control" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.audio" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.audio" 2>/dev/null || true
      po_apply_all

      # Advanced Bluetooth Audio replaces the cloned Bluetooth widget while
      # retaining its bar position and native device-management behavior.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "ssupt.bluetooth-audio")' >/dev/null; then
        log_sub "Adding external Omarchy Bluetooth audio plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/ssupt/omarchy-bluetooth-audio.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "ssupt.bluetooth-audio" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.bluetooth" 2>/dev/null || true

      # Wavebar replaces the media/Cava widget in the center of the
      # Virtual Paradise bar.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.erikburdett.wavebar")' >/dev/null; then
        log_sub "Adding Omarchy Wavebar media widget from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/ErikBurdett/omarchy-wavebar.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.erikburdett.wavebar" 2>/dev/null || true
      fi
      po_apply_all

      # Workspaces (JAP) replaces the cloned Omarchy workspace widget.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.tyrichards.workspaces-jap")' >/dev/null; then
        log_sub "Adding external Japanese workspace plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/TyRichards/omarchy-workspaces-jap.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.tyrichards.workspaces-jap" 2>/dev/null || true
      fi
      RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.workspaces" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.workspaces" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin remove "${CURRENT_USER}.media" --yes 2>/dev/null || true
      po_apply_all

      # Voxtype Aura provides the themed dictation overlay.
      if ! RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "io.github.adamcbrewer.voxtype-aura")' >/dev/null; then
        log_sub "Adding Voxtype Aura dictation overlay plugin from git..."
        RUN_AS_INSTALL_USER omarchy plugin add https://github.com/adamcbrewer/voxtype-aura.git --enable --yes 2>/dev/null || true
      else
        RUN_AS_INSTALL_USER omarchy plugin enable "io.github.adamcbrewer.voxtype-aura" 2>/dev/null || true
      fi
      po_apply_all

      # Paradise Island Bar is installed as a first-party plugin so it inherits
      # the host ShellRoot. A third-party bar only ever receives a scoped
      # plugin shell whose serviceFor() is gated to the bar's own id, which is
      # why service-backed widgets (ssupt.audio-control) resolved null and
      # reported "Audio service is unavailable" over a healthy backend.
# A missing bar bundle is a warning, not a fatal error: every other
      # plugin is still usable, so don't let `set -e` abort the whole install.
      po_install_island_bar || true
      # The stock tray reserves its whole drawer width by design; shrinking it
      # is not a one-line change, see patch_system_tray.
      enable_plugin_retry "${CURRENT_USER}.island-bar" || \
        log_warn "Paradise Island Bar could not be enabled: ${LAST_PLUGIN_ERROR:-unknown error}"
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.bar" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "mscurtescu.island-bar" 2>/dev/null || true
      po_apply_all


      # The notification center owns the DND control. Disable a separately
      # installed DND plugin when present, but keep Omarchy's notification
      # service enabled because the new plugin uses it as its backend.
      local dnd_plugin_id
      for dnd_plugin_id in omarchy.dnd omarchy.do-not-disturb "${CURRENT_USER}.dnd"; do
        if RUN_AS_INSTALL_USER omarchy plugin list --json 2>/dev/null | jq -e --arg id "$dnd_plugin_id" \
          'any(.[]; .id == $id)' >/dev/null; then
          RUN_AS_INSTALL_USER omarchy plugin disable "$dnd_plugin_id" 2>/dev/null || \
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

# Preserve canonical default Omarchy shell layout as shell-default.json.
#
# This has to run before the block below overwrites shell.json, and it must never
# fall back to our own template. Where Omarchy's own layout lives is overridable
# only so the test suite can exercise the "Omarchy not installed" path, which is
# where the fallback bug lived.
OMARCHY_SHELL_DEFAULT_SRC="${OMARCHY_SHELL_DEFAULT_SRC:-/usr/share/omarchy/config/omarchy/shell.json}"

if [[ ! -f "$CONFIG_DIR/omarchy/shell-default.json" ]]; then
  if [[ -f "$OMARCHY_SHELL_DEFAULT_SRC" ]]; then
    cp "$OMARCHY_SHELL_DEFAULT_SRC" "$CONFIG_DIR/omarchy/shell-default.json"
  elif [[ -f "$CONFIG_DIR/omarchy/shell.json" ]] \
    && ! grep -qE '__USER__\.|woogy7\.vitals' "$CONFIG_DIR/omarchy/shell.json"; then
    cp "$CONFIG_DIR/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell-default.json"
  else
    log_warn "No pristine Omarchy shell.json found; shell-default.json not created."
    log_info "  uninstall.sh will preserve your shell.json rather than restore a guessed default."
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
    po_apply_all
    enable_plugin_retry "jankeesvw.notification-center" || \
      log_warn "Notification center could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    enable_plugin_retry "crmne.hyprmoncfg" || \
      log_warn "hyprmoncfg could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    enable_plugin_retry "io.github.jeffcortez23.omarchy-projector-cast" || \
      log_warn "Projector & Cast could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    enable_plugin_retry "onlyvishesh.power-manager" || \
      log_warn "power manager could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.monitor" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.monitor" 2>/dev/null || true
    enable_plugin_retry "io.github.woogy7.vitals" || \
      log_warn "Vitals could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    RUN_AS_INSTALL_USER omarchy plugin disable "harshith.system-monitor" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.memory" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.memory" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.power" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.power" 2>/dev/null || true
    enable_plugin_retry "io.github.erikburdett.wavebar" || \
      log_warn "Wavebar could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    enable_plugin_retry "ssupt.audio-control" || \
      log_warn "audio control could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.audio" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.audio" 2>/dev/null || true
    enable_plugin_retry "ssupt.bluetooth-audio" || \
      log_warn "Bluetooth audio could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.bluetooth" 2>/dev/null || true
    enable_plugin_retry "io.github.tyrichards.workspaces-jap" || \
      log_warn "Japanese workspace plugin could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.workspaces" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.workspaces" 2>/dev/null || true
    enable_plugin_retry "${CURRENT_USER}.island-bar" || \
      log_warn "Paradise Island Bar could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.bar" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "mscurtescu.island-bar" 2>/dev/null || true
    po_apply_all

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
    "description": "Play/pause live wallpaper (SUPER + ALT + W)",
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
  }
}
EOF
log_sub "Installed Quick Actions menu extensions"

# ------------------------------------------------------------------------------
# 5. Configure Hyprland Add-on Rules, Styling & Keybindings
# ------------------------------------------------------------------------------
log_step "5" "$TOTAL_STEPS" "Deploying Hyprland look'n'feel, gestures, rules & shortcuts..."

# Reuse one timestamped backup dir per run, and only materialise it when there
# is actually something to back up. Previously a fresh (usually empty)
# ~/.config/hypr/backup_<epoch>/ was created on every single run and never
# cleaned up by uninstall.sh.
HYPR_BAK_DIR=""
hypr_state_dir="$HOME/.local/state/virtual-paradise"
hypr_state_file="$hypr_state_dir/hypr-backup-dir"

# Record one snapshot directory per install cycle, even on a fresh machine with
# no Hypr files yet: a later re-install must not mistake its own files for the
# user's originals. Uninstall reads this path (and removes the file).
if [[ ! -f "$hypr_state_file" ]]; then
  HYPR_BAK_DIR="$CONFIG_DIR/hypr/backup_$BACKUP_TIMESTAMP"
  mkdir -p "$HYPR_BAK_DIR" "$hypr_state_dir" 2>/dev/null || true
  printf '%s\n' "$HYPR_BAK_DIR" >"$hypr_state_file" 2>/dev/null || true
fi

hypr_backup() {
  local src="$1"
  [[ -f "$src" ]] || return 0
  if [[ -z "$HYPR_BAK_DIR" ]]; then
    HYPR_BAK_DIR="$CONFIG_DIR/hypr/backup_$BACKUP_TIMESTAMP"
    mkdir -p "$HYPR_BAK_DIR"
  fi
  cp "$src" "$HYPR_BAK_DIR/" 2>/dev/null || true
}

# 5.1 Look'n'feel (Golden ratio gaps, squircle rounding, acrylic blur, cyberSpring animations)
if [[ -f "$REPO_DIR/hypr/looknfeel.lua" ]]; then
  hypr_backup "$CONFIG_DIR/hypr/looknfeel.lua"
  cp "$REPO_DIR/hypr/looknfeel.lua" "$CONFIG_DIR/hypr/looknfeel.lua"
  log_sub "Applied Virtual Paradise look'n'feel (acrylic blur, cyberSpring animations, neon borders)"
fi

# 5.2 Input Tuning (macOS-level touchpad gestures, 50 chars/s repeat rate, cursor auto-hide)
if [[ -f "$REPO_DIR/hypr/input.lua" ]]; then
  hypr_backup "$CONFIG_DIR/hypr/input.lua"
  cp "$REPO_DIR/hypr/input.lua" "$CONFIG_DIR/hypr/input.lua"
  log_sub "Applied full-topping input & gestures (3-finger workspace swipe, pinch zoom, fast repeat)"
fi

# 5.3 Keybindings (SUPER+E file manager, SUPER+B browser, SUPER+ALT+C cooler boost, SUPER+SHIFT+K cast)
if [[ -f "$REPO_DIR/hypr/bindings.lua" ]]; then
  hypr_backup "$CONFIG_DIR/hypr/bindings.lua"
  cp "$REPO_DIR/hypr/bindings.lua" "$CONFIG_DIR/hypr/bindings.lua"
  log_sub "Applied full-topping keybindings (SUPER+E, SUPER+B, SUPER+ALT+C, SUPER+SHIFT+K)"
fi

# 5.4 Display / Monitors
if [[ ! -f "$CONFIG_DIR/hypr/monitors.lua" && -f "$REPO_DIR/hypr/monitors.lua" ]]; then
  cp "$REPO_DIR/hypr/monitors.lua" "$CONFIG_DIR/hypr/monitors.lua"
  log_sub "Initialized default display configuration"
elif [[ -f "$CONFIG_DIR/hypr/monitors.lua" ]] && ! grep -q "ELECTRON_OZONE_PLATFORM_HINT" "$CONFIG_DIR/hypr/monitors.lua"; then
  # Preserve user custom monitor positions but ensure crisp Wayland toolkit variables
  hypr_backup "$CONFIG_DIR/hypr/monitors.lua"
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
    hypr_backup "$CONFIG_DIR/hypr/autostart.lua"
    echo 'o.launch_on_start("toggle_live_wallpaper.sh init")' >> "$CONFIG_DIR/hypr/autostart.lua"
    log_sub "Hooked live wallpaper to ~/.config/hypr/autostart.lua"
  fi
elif [[ -f "$REPO_DIR/hypr/autostart.lua" ]]; then
  cp "$REPO_DIR/hypr/autostart.lua" "$CONFIG_DIR/hypr/autostart.lua"
fi

# 5.6 Window Rules (Btop, Voxtype, Cast Screen, Nautilus)
if [[ -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
  # Guard on our own marker, not on "GNOME Network Displays": a user comment
  # mentioning that app must not suppress the rules, and the marker is what
  # uninstall.sh removes.
  if ! grep -q "Virtual Paradise Add-on Window Rules" "$CONFIG_DIR/hypr/hyprland.lua"; then
    hypr_backup "$CONFIG_DIR/hypr/hyprland.lua"
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

# NOTE: hypr/hyprland.lua and hypr/hyprland.conf were removed. Omarchy loads
# hyprland.lua as its own entry point which require()s monitors -> input ->
# bindings -> looknfeel -> autostart, so a standalone repo hyprland.lua was
# never loaded and only shadowed looknfeel.lua. hypr/hyprlock.conf was removed
# too: hyprlock is not used (Omarchy locks via the Quickshell lock plugin).
if [[ -f "$REPO_DIR/hypr/hyprland-preview-share-picker.css" ]]; then
  cp "$REPO_DIR/hypr/hyprland-preview-share-picker.css" "$CONFIG_DIR/hypr/hyprland-preview-share-picker.css" 2>/dev/null || true
fi

# 5.5 Fcitx5 Vietnamese Input Method (Unikey) Configuration
CONFIGURE_FCITX_UNIKEY() {
  command -v fcitx5 &>/dev/null || return 0

  local fcitx_dir="$CONFIG_DIR/fcitx5"
  local fcitx_profile="$fcitx_dir/profile"
  mkdir -p "$fcitx_dir"

  # Keep the user's own profile so uninstall.sh can put it back. Only taken when
  # the profile lacks our unikey entry, i.e. when it is genuinely the user's: a
  # later run must not back up the file we ourselves wrote, or uninstall would
  # "restore" our profile and leave fcitx5 configured for the rice.
  if [[ -f "$fcitx_profile" ]] \
    && ! grep -q "Name=unikey" "$fcitx_profile" \
    && [[ ! -f "$fcitx_profile.paradise.bak" ]]; then
    cp "$fcitx_profile" "$fcitx_profile.paradise.bak" 2>/dev/null || true
  fi

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
  rm -f "$LOCAL_BIN/paradise_agent.py" "$LOCAL_BIN/paradise-agent" "$LOCAL_BIN/offline-agent" 2>/dev/null || true
  sync_tree "$REPO_DIR/bin" "$LOCAL_BIN"
  rm -rf "$LOCAL_BIN/__pycache__"
  chmod +x "$LOCAL_BIN"/*.sh "$LOCAL_BIN"/*.py "$LOCAL_BIN"/momoisay "$LOCAL_BIN"/momoisay.real 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_banner.py" "$LOCAL_BIN/paradise-banner" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/virtual_matrix.py" "$LOCAL_BIN/virtual_matrix" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/cast_screen.sh" "$LOCAL_BIN/cast-screen" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/format-docx" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/vn-docx" 2>/dev/null || true
  chmod +x "$LOCAL_BIN/sync_cava_theme.py" "$LOCAL_BIN/virtual_matrix.py" "$LOCAL_BIN/cast_screen.sh" "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/paradise_banner.py" 2>/dev/null || true
  cp "$REPO_DIR/uninstall.sh" "$LOCAL_BIN/uninstall-virtual-paradise"
  chmod +x "$LOCAL_BIN/uninstall-virtual-paradise"
  log_sub "Installed helper tools (rice_layout, momoisay, toggle_live_wallpaper, logout_splash, paradise-banner, etc.)"
fi

# ------------------------------------------------------------------------------
# 6b. Plugin update mechanism
# ------------------------------------------------------------------------------
# bin/update-plugins.sh locates the override layer relative to its own path, so
# the shared lib has to sit next to it rather than only in the repo.
if [[ -f "$REPO_DIR/bin/update-plugins.sh" && -f "$REPO_DIR/lib/plugin-overrides.sh" ]]; then
  mkdir -p "$HOME/.local/share/virtual-paradise"
  cp "$REPO_DIR/lib/plugin-overrides.sh" "$HOME/.local/share/virtual-paradise/plugin-overrides.sh"
  # The installed updater has no repo in sight, so mirror overrides/ next to the
  # lib; it re-applies this rice after every update.
  rm -rf "$HOME/.local/share/virtual-paradise/overrides"
  [[ -d "$REPO_DIR/overrides" ]] &&
    cp -r "$REPO_DIR/overrides" "$HOME/.local/share/virtual-paradise/overrides"
  chmod +x "$LOCAL_BIN/update-plugins.sh" "$LOCAL_BIN/notify-plugin-updates.sh" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/update-plugins.sh" "$LOCAL_BIN/paradise-plugin-update"
  chmod +x "$LOCAL_BIN/audio-backend-watchdog.sh" 2>/dev/null || true
  log_sub "Installed plugin updater (paradise-plugin-update --check | --apply | --rollback | --status)"

  # Record the revisions that just landed. `omarchy plugin add` clones upstream
  # HEAD, which is neither reproducible nor reversible on its own; pinning here
  # means --rollback has a known-good target from the first install, and
  # --status can show later drift.
  if [[ -n "${CURRENT_USER:-}" ]] && command -v git &>/dev/null; then
    RUN_AS_INSTALL_USER "$LOCAL_BIN/paradise-plugin-update" --pin >/dev/null 2>&1 &&
      log_sub "Pinned installed plugin revisions" ||
      log_warn "Could not pin plugin revisions; run 'paradise-plugin-update --pin' later."
  fi
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
  # fastfetch only reads config.jsonc. virtual-paradise.jsonc is the
  # theme-specific asset that the theme hook re-applies on every theme change,
  # so publish it here too instead of shipping two diverging config files.
  if [[ -f "$CONFIG_DIR/fastfetch/virtual-paradise.jsonc" ]]; then
    # Never silently clobber the user's fastfetch config: back up once.
    if [[ -f "$CONFIG_DIR/fastfetch/config.jsonc" ]] \
      && ! cmp -s "$CONFIG_DIR/fastfetch/virtual-paradise.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"; then
      if [[ ! -f "$CONFIG_DIR/fastfetch/config.jsonc.paradise.bak" ]]; then
        cp "$CONFIG_DIR/fastfetch/config.jsonc" \
          "$CONFIG_DIR/fastfetch/config.jsonc.paradise.bak" || true
      fi
    fi
    cp "$CONFIG_DIR/fastfetch/virtual-paradise.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
  fi
fi

# Micro Editor Rice
if [[ -d "$REPO_DIR/micro" ]]; then
  if [[ -f "$REPO_DIR/micro/settings.json" ]]; then
    # Never silently clobber the user's editor settings: back up once.
    if [[ -f "$CONFIG_DIR/micro/settings.json" ]] \
      && ! cmp -s "$REPO_DIR/micro/settings.json" "$CONFIG_DIR/micro/settings.json"; then
      if [[ ! -f "$CONFIG_DIR/micro/settings.json.paradise.bak" ]]; then
        cp "$CONFIG_DIR/micro/settings.json" \
          "$CONFIG_DIR/micro/settings.json.paradise.bak" || true
      fi
    fi
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
  # Do not swallow this rsync: it is the step that actually delivers the theme.
  # A failure here used to be invisible and still printed the success banner.
  THEME_DEST="$CONFIG_DIR/omarchy/themes/$THEME_NAME"

  # What the theme actually needs, and nothing else. `theme/` and `config/` are
  # flattened into the root below; `hypr/*.css`, `assets/` and `overrides/` are
  # read back by the theme-set hook; `backgrounds/` is what `omarchy theme bg
  # next` cycles. Everything installed to its own place - plugins, bars, bin,
  # lib, shell, systemd, sddm, plymouth, micro, cava, fastfetch - is delivered
  # by its own step and would only be dead weight here.
  #
  # One list feeds both the rsync excludes and the cleanup below. --exclude also
  # stops --delete removing a copy an earlier run placed, so the two must agree
  # or a stripped directory would linger forever.
  THEME_STRIP=(
    .git .github .githooks .gitignore
    tests tools docs
    install.sh uninstall.sh README.md LICENSE CONTRIBUTING.md
    plugins bars bin lib shell systemd sddm plymouth micro cava fastfetch
  )

  strip_args=()
  for item in "${THEME_STRIP[@]}"; do strip_args+=(--exclude="$item"); done

  if command -v rsync &>/dev/null; then
    if ! rsync -a --delete "${strip_args[@]}" "$REPO_DIR"/ "$THEME_DEST/"; then
      log_warn "Theme rsync failed. The theme may be incomplete — re-run the installer."
    fi
  else
    # No rsync: copy everything, then let the cleanup loop below strip the repo
    # boilerplate. The theme is what the whole install delivers, so a missing
    # tool must not leave it half-populated.
    rm -rf "${THEME_DEST:?}"
    mkdir -p "$THEME_DEST"
    cp -a "$REPO_DIR"/. "$THEME_DEST"/
  fi

  for item in "${THEME_STRIP[@]}"; do
    rm -rf "${THEME_DEST:?}/$item"
  done
  rm -rf "$THEME_DEST/__pycache__"
  find "$THEME_DEST" -name '*.pyc' -delete 2>/dev/null || true
fi

# Wavebar replaced the legacy media/Cava bar plugin. Remove any copy left in
# the theme runtime from older Virtual Paradise installations.
rm -rf "$CONFIG_DIR/omarchy/themes/$THEME_NAME/plugins/media"

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
# Flatten hypr/ assets into theme root. hyprland.lua and hyprlock.conf are
# intentionally absent: flattening a standalone hyprland.lua to the theme root
# would shadow Omarchy's require()-based entry point.
f=hyprland-preview-share-picker.css
if [[ -f "$THEME_DEST/hypr/$f" ]]; then
  cp "$THEME_DEST/hypr/$f" "$THEME_DEST/$f" 2>/dev/null || true
fi
unset f
log_sub "Flattened hypr/ Omarchy-required files to theme root"

# Flatten assets (preview.png, unlock.png) into theme root for Omarchy theme picker & Plymouth switcher
if [[ -d "$THEME_DEST/assets" ]]; then
  cp -f "$THEME_DEST/assets/preview.png" "$THEME_DEST/preview.png" 2>/dev/null || true
  cp -f "$THEME_DEST/assets/unlock.png" "$THEME_DEST/unlock.png" 2>/dev/null || true
  cp -f "$THEME_DEST/assets/unlock.png" "$THEME_DEST/preview-unlock.png" 2>/dev/null || true
  log_sub "Flattened assets/ (preview.png, unlock.png) to Omarchy theme root"
fi

# Post-theme-set hook
# Copy the hook template from lib/ to the Omarchy hooks directory.
# The hook runs when the active theme changes and handles plugin state,
# overrides, GTK styling, and live wallpaper lifecycle.
if [[ -f "$REPO_DIR/lib/theme-set-hook.sh" ]]; then
  cp "$REPO_DIR/lib/theme-set-hook.sh" "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
  chmod +x "$CONFIG_DIR/omarchy/hooks/theme-set.d/virtual-paradise.sh"
  log_sub "Installed post-theme-set hook for plugin & widget lifecycle management"
else
  log_warn "Theme-set hook template not found at $REPO_DIR/lib/theme-set-hook.sh"
fi

# Daily read-only update check. Deliberately does NOT update: applying an
# update restarts the shell, so that stays a deliberate, typed action.
if [[ -f "$REPO_DIR/systemd/paradise-plugin-check.timer" ]]; then
  # $CONFIG_DIR, not $HOME/.config: uninstall.sh removes these units through
  # XDG_CONFIG_HOME and would leave them behind otherwise.
  mkdir -p "$CONFIG_DIR/systemd/user"
  cp "$REPO_DIR/systemd/paradise-plugin-check.service" \
     "$REPO_DIR/systemd/paradise-plugin-check.timer" \
     "$CONFIG_DIR/systemd/user/"
  if [[ -f "$REPO_DIR/systemd/paradise-audio-watchdog.timer" ]]; then
    cp "$REPO_DIR/systemd/paradise-audio-watchdog.service" \
       "$REPO_DIR/systemd/paradise-audio-watchdog.timer" \
       "$CONFIG_DIR/systemd/user/"
  fi
  if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    if systemctl --user enable --now paradise-plugin-check.timer >/dev/null 2>&1; then
      log_sub "Enabled daily plugin update check (paradise-plugin-update --check)"
    else
      log_sub "Plugin update timer installed but not enabled; enable with: systemctl --user enable --now paradise-plugin-check.timer"
    fi
    # The audio-control panel cannot recover from a wedged backend on its own,
    # so this one does act unattended.
    if systemctl --user enable --now paradise-audio-watchdog.timer >/dev/null 2>&1; then
      log_sub "Enabled audio backend watchdog (every 5 min)"
    else
      log_sub "Audio watchdog installed but not enabled; enable with: systemctl --user enable --now paradise-audio-watchdog.timer"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 9. Install Boot & Shutdown Animations (Plymouth, SDDM & UKI)
# ------------------------------------------------------------------------------
if [[ $ENABLE_BOOT -eq 1 && $HAVE_SUDO -eq 1 ]]; then
  INSTALL_BOOT_ANIMATIONS
else
  log_step "9" "$TOTAL_STEPS" "Boot & shutdown animation setup skipped (requires sudo / --no-boot)"
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
  [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$BACKUP_TIMESTAMP" 2>/dev/null || true
  cp "$REPO_DIR/shell/zshrc" "$HOME/.zshrc"
  log_sub "Synchronized full-topping ~/.zshrc shell configuration"
fi

# Backups are timestamped per run, so repeated installs pile up indefinitely.
# The OLDEST entry is the user's genuine pre-install state, so it is always
# kept; only the middle copies (all identical post-install snapshots) are
# trimmed, newest ones surviving.
prune_backups() (
  local dir="$1" pattern="$2" keep="$3" protect="${4:-}" f n=0 total=0
  # nullglob matters: with `set -o pipefail`, a non-matching glob makes `ls`
  # exit 2 and would abort the install on a first-ever run. Running in a
  # subshell keeps the caller's shell options untouched.
  shopt -s nullglob
  # shellcheck disable=SC2206  # the glob must expand into the array
  local matches=("$dir"/$pattern)
  (( ${#matches[@]} == 0 )) && return 0
  total=${#matches[@]}
  # Explicit `if` blocks: a false `&&`/`||` chain yields exit status 1, which
  # `set -e` treats as a fatal error and would kill the loop mid-way.
  printf '%s\n' "${matches[@]}" | sort -r | while read -r f; do
    n=$((n + 1))
    if (( n == 1 )); then continue; fi          # newest snapshot
    if (( n == total )); then continue; fi     # original pre-install state
    if [[ -n $protect && $f == "$protect" ]]; then continue; fi  # uninstall target
    if (( n > keep )); then rm -rf "$f"; fi
  done
)
prune_backups "$HOME" ".zshrc.bak.*" 5
[[ -n $HYPR_BAK_DIR ]] && prune_backups "$CONFIG_DIR/hypr" "backup_*" 5 \
  "$(head -n1 "$hypr_state_file" 2>/dev/null || true)"

# 10.3 Ensure default shell is Zsh
#
# The shell must be listed in /etc/shells verbatim: pam_shells compares strings,
# and a path like /usr/sbin/zsh (the /usr/sbin → /usr/bin symlink) is rejected
# even though it is the same binary. That was a real login loop — SDDM reported
# "Authentication error" for both password login and autologin.
if [[ $IS_HOOK -eq 0 ]] && command -v zsh &>/dev/null; then
  LOGIN_SHELL="$(resolve_login_shell)"
  CURRENT_LOGIN_SHELL="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7 || true)"
  VP_STATE_DIR="$HOME/.local/state/virtual-paradise"

  if [[ -n $LOGIN_SHELL ]]; then
    if ! grep -qxF "$LOGIN_SHELL" /etc/shells 2>/dev/null; then
      log_sub "Registering ${LOGIN_SHELL} as a login shell..."
      run_privileged sh -c 'grep -qxF "$1" /etc/shells || printf "%s\n" "$1" >> /etc/shells' \
        _ "$LOGIN_SHELL" 2>/dev/null || true
    fi

    if ! grep -qxF "$LOGIN_SHELL" /etc/shells 2>/dev/null; then
      log_warn "Leaving the login shell unchanged: ${LOGIN_SHELL} is not listed in /etc/shells (PAM would reject it)."
    elif [[ "$CURRENT_LOGIN_SHELL" != "$LOGIN_SHELL" ]]; then
      log_sub "Setting default login shell to ${LOGIN_SHELL} for '${CURRENT_USER}'..."
      if run_privileged chsh -s "$LOGIN_SHELL" "$CURRENT_USER" 2>/dev/null; then
        # Remember the previous shell so uninstall.sh can put it back. Never
        # overwrite the first recorded value on a re-install.
        if [[ -n $CURRENT_LOGIN_SHELL && ! -f "$VP_STATE_DIR/login-shell.previous" ]]; then
          mkdir -p "$VP_STATE_DIR" 2>/dev/null || true
          printf '%s\n' "$CURRENT_LOGIN_SHELL" >"$VP_STATE_DIR/login-shell.previous" 2>/dev/null || true
        fi
      else
        log_warn "Could not change the login shell to ${LOGIN_SHELL}."
      fi
    fi

    systemctl --user set-environment SHELL="$LOGIN_SHELL" 2>/dev/null || true
    hyprctl eval "hl.env('SHELL', '$LOGIN_SHELL')" 2>/dev/null || true
  fi
  if [[ -f "$CONFIG_DIR/ghostty/config" ]] && ! grep -q "^command = " "$CONFIG_DIR/ghostty/config"; then
    # Back up before editing in place, so uninstall.sh has something to restore.
    [[ -f "$CONFIG_DIR/ghostty/config.paradise.bak" ]] \
      || cp "$CONFIG_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config.paradise.bak" 2>/dev/null || true
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

  # Purge any legacy agy or paradise-agent aliases
  sed -i '/alias agy=/d; /alias pa=/d; /alias offline-agent=/d' "$file" 2>/dev/null || true

  # Add Virtual Paradise aliases
  if ! grep -q "paradise_banner" "$file" && ! grep -q "paradise-banner" "$file"; then
    cat << 'EOF' >> "$file"

# ==============================================================================
#  Virtual☆Paradise Add-on Aliases & Integration
# ==============================================================================
alias banner="$HOME/.local/bin/paradise_banner.py"
alias rice="$HOME/.local/bin/rice_layout.sh"
alias matrix="$HOME/.local/bin/virtual_matrix.py"
alias boost="$HOME/.local/bin/toggle_cooler_boost.sh"
alias cast="$HOME/.local/bin/cast_screen.sh"

# Run Virtual Paradise Cyberpunk Banner on terminal startup (only in interactive shells)
if [[ -o interactive ]] 2>/dev/null || [[ "$-" == *i* ]]; then
  if [[ -z "$VIRTUAL_PARADISE_NO_BANNER" && -x "$HOME/.local/bin/paradise_banner.py" ]]; then
    "$HOME/.local/bin/paradise_banner.py"
  fi
fi
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
    RUN_AS_INSTALL_USER omarchy theme set "$THEME_NAME" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy theme bg cache 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy restart shell 2>/dev/null || true

    # Theme activation can restart the shell and briefly race plugin
    # discovery, so enforce the notification center state last.
    enable_plugin_retry "jankeesvw.notification-center" || \
      log_warn "Notification center could not be enabled after theme activation: ${LAST_PLUGIN_ERROR:-unknown error}"
    enable_plugin_retry "crmne.hyprmoncfg" || true
    enable_plugin_retry "onlyvishesh.power-manager" || true
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.power" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.power" 2>/dev/null || true
  fi

  if command -v hyprctl &>/dev/null; then
    RUN_AS_INSTALL_USER hyprctl reload 2>/dev/null || true
  fi

  # Initialize and launch the live video wallpaper immediately (SUPER + ALT + W
  # toggles it later).
  if [[ -x "$LOCAL_BIN/toggle_live_wallpaper.sh" ]]; then
    log_sub "Initializing live video wallpaper (toggle with SUPER + ALT + W)..."
    (sleep 0.4; RUN_AS_INSTALL_USER "$LOCAL_BIN/toggle_live_wallpaper.sh" init >/dev/null 2>&1 &)
  fi

  echo -e "\n${C_BOLD}${C_GREEN}✨ Virtual☆Paradise Theme & Rice successfully installed for '${CURRENT_USER}'!${C_RESET}"
  echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────${C_RESET}"
  echo -e " ${C_BOLD}Useful shortcuts:${C_RESET}"
  echo -e "   ${C_GREEN}SUPER + Q${C_RESET}             ➔ Launch 5-terminal Rice layout"
  echo -e "   ${C_GREEN}SUPER + ALT + W${C_RESET}       ➔ Toggle Live Video / Static Wallpaper"
  echo -e "   ${C_GREEN}SUPER + ALT + N${C_RESET}       ➔ Next Live Wallpaper (Cyberpunk Glitch Transition)"
  echo -e "   ${C_GREEN}SUPER + ALT + SHIFT + N${C_RESET} ➔ Previous Live Wallpaper (Cyberpunk Glitch Transition)"
  echo -e "   ${C_GREEN}SUPER + N${C_RESET}             ➔ Cycle next wallpaper"
  echo -e "   ${C_GREEN}SUPER + ALT + C${C_RESET}       ➔ Toggle Cooler Boost fan cooling"
  echo -e "   ${C_GREEN}SUPER + SHIFT + K${C_RESET}     ➔ Cast Screen (Wireless Display)"
  echo -e "   ${C_GREEN}ffa${C_RESET}                   ➔ Launch Fastfetch with high-res Anime Braille logo"
  echo -e "   ${C_GREEN}f${C_RESET}                     ➔ Search☆Hub (Explorer, History, Process)"
  echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────${C_RESET}\n"
fi
