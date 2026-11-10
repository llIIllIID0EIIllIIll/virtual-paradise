#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Full-Topping Rice & Universal Theme Automated Installer
# ==============================================================================
#  GitHub: https://github.com/vuhuudo/virtual-paradise
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
# shellcheck source=lib/shell-layout.sh
. "$REPO_DIR/lib/shell-layout.sh"
# shellcheck source=lib/install-helpers.sh
. "$REPO_DIR/lib/install-helpers.sh"
THEME_NAME="virtual-paradise"
IS_HOOK=0
ENABLE_BOOT=1
BOOT_ONLY=0
SDDM_ONLY=0
USER_ONLY=0
NO_AUTOLOGIN=0
FORCE_SHELL_LAYOUT=0

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      printf 'Usage: %s [--no-boot] [--boot-only] [--sddm-only] [--user-only|--no-sudo] [--no-autologin] [--force-shell-layout] [--hook]\n' "$0"
      printf '\nInstalls the Virtual☆Paradise theme.\n\n'
      printf '  --no-boot        skip the Plymouth/SDDM setup (needs sudo)\n'
      printf '  --boot-only      install only the boot and login themes (needs sudo)\n'
      printf '  --sddm-only      install only the SDDM login theme (needs sudo)\n'
      printf '  --user-only      install nothing outside your home directory\n'
      printf '  --no-sudo        alias for --user-only\n'
      printf '  --no-autologin   show the login screen instead of logging in automatically\n'
      printf '  --force-shell-layout  replace a customised shell.json with the theme layout\n'
      printf '  --hook           re-apply the overrides and the bar layout only (for scripts)\n'
      printf '  --dry-run        refused on purpose: there is no preview mode\n'
      exit 0
      ;;
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
    --no-autologin)
      # Show the login screen. Omarchy logs in automatically, so the greeter
      # is on screen for less than a second and the theme's password panel
      # would never be seen.
      NO_AUTOLOGIN=1
      ;;
    --force-shell-layout)
      FORCE_SHELL_LAYOUT=1
      ;;
    --dry-run)
      # There is no preview mode: the installer writes to ~/.config, ~/.local
      # and /usr/share and restarts the shell. Refuse loudly rather than look
      # like it did nothing while changing the machine anyway.
      printf 'install.sh: --dry-run is not supported — nothing was installed.\n' >&2
      exit 2
      ;;
    *)
      # An unknown option used to be ignored, so a typo ("--user-onyl") ran a
      # full install with the wrong privileges instead of failing.
      printf 'install.sh: unknown option: %s\n' "$arg" >&2
      printf 'Run "%s --help" for the supported options.\n' "$0" >&2
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

# Omarchy's own environment. OMARCHY_PATH is set by the user's shell
# bootstrap, but sudo resets the environment: without it every
# `omarchy ...` call answers "OMARCHY_PATH is not set" (or looks for the
# shell config in "/shell"), so the plugin, theme and shell steps fail
# silently. Resolve it the way Omarchy does and keep it for every command
# this installer starts.
#
# This has to run for a plain run as well: the systemd timers and the
# user manager's environment do not carry OMARCHY_PATH either.
# shellcheck source=lib/omarchy-env.sh
. "$REPO_DIR/lib/omarchy-env.sh"
omarchy_export_env
# The graphical session variables (Hyprland instance, Wayland display, the
# session bus) are reset by sudo as well. Without them `hyprctl reload`
# cannot find the compositor and the theme's Hyprland changes would only land
# at the next login.
omarchy_resolve_session_env "$CURRENT_USER" || true

# File helpers: replacing a config must not change its mode or its owner.
# shellcheck source=lib/file-ops.sh
. "$REPO_DIR/lib/file-ops.sh"

trap cleanup_install EXIT INT TERM

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Theme-owned paths, resolved once after the target user/home is known. The
# override layer caches these at source time, so it must be sourced *after*
# them: under `sudo ./install.sh`, HOME is still /root when this file starts,
# and sourcing earlier made every patch land in /root/.config instead of the
# user's plugins.
VP_CONFIG_DIR="$CONFIG_DIR"
VP_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise"
VP_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/virtual-paradise"
export PARADISE_CONFIG_DIR="$VP_CONFIG_DIR"
export PARADISE_STATE_DIR="$VP_STATE_DIR"
# shellcheck source=lib/plugin-overrides.sh
. "$REPO_DIR/lib/plugin-overrides.sh"







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

# Mirror or merge a directory tree. rsync is in the package list and step 1
# installs it, but --user-only runs, containers and non-Omarchy distros may not
# have it; a missing tool must not turn into a silent half-install.

# Hardware detection, package installation and per-vendor setup. Sourced here so
# those functions exist before step 1 calls them, and after the helpers above,
# which they use.
# shellcheck source=lib/system.sh
. "$REPO_DIR/lib/system.sh"
# shellcheck source=lib/step-shell.sh
. "$REPO_DIR/lib/step-shell.sh"
# shellcheck source=lib/step-plugins.sh
. "$REPO_DIR/lib/step-plugins.sh"
# shellcheck source=lib/step-boot.sh
. "$REPO_DIR/lib/step-boot.sh"

# Install (or reinstall) only the SDDM login theme. Shared by the full install,
# --boot-only and --sddm-only so all three use exactly the same code path.

# Install (or reinstall) only the Plymouth boot theme. Same contract as
# INSTALL_SDDM_THEME: the theme goes into its own directory and is selected
# by name, so the package-owned omarchy theme is never written to.

# The boot image this machine boots from, and how old it is.
#
# Limine boots a unified kernel image, mkinitcpio writes a plain initramfs.
# Both are checked so the installer can tell whether the splash really made
# it into the image that is booted. The check runs as root: /boot is not
# readable by the user.

# Turn the SDDM autologin off so the greeter is actually shown.
#
# Omarchy logs in automatically, so the login screen is on screen for less than
# a second: the theme's password panel would never be seen. The original file
# is kept next to it so uninstall.sh can put it back.


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
    if [[ $NO_AUTOLOGIN -eq 1 ]]; then
      disable_autologin || true
    fi
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

# The stock system tray is deliberately left alone. The old drawer-reveal patch
# is gone: narrowing the clip region moved the pinned items under the drawer
# icons, and any in-place edit of a package-owned QML file would be lost on the
# next Omarchy update anyway. The island bar uses the upstream tray unchanged.

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
mkdir -p "$CONFIG_DIR/omarchy/themes/$THEME_NAME"
mkdir -p "$CONFIG_DIR/omarchy/backgrounds/$THEME_NAME"
mkdir -p "$CONFIG_DIR/omarchy/plugins"
mkdir -p "$CONFIG_DIR/omarchy/hooks/theme-set.d"
mkdir -p "$CONFIG_DIR/omarchy/hooks/post-update.d"
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
# Set to 1 only when both the first-party bar copy and its plugin enablement
# succeed. Step 4 uses it to decide whether to keep the stock bar enabled.
BAR_INSTALL_OK=0

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
  # Render the theme layout into a temp file and let the ownership rules decide
  # whether the live file may be replaced. A user-customised shell.json is
  # preserved unless --force-shell-layout was passed.
  _vp_layout_tmp="$(mktemp)" || _vp_layout_tmp=""
  if [[ -n $_vp_layout_tmp ]]; then
    sed "s/__USER__/${CURRENT_USER}/g" "$REPO_DIR/shell/shell.json" >"$_vp_layout_tmp"
    _vp_layout_result="$(vp_layout_install_from "$_vp_layout_tmp" "$FORCE_SHELL_LAYOUT" || true)"
    rm -f "$_vp_layout_tmp"
    unset _vp_layout_tmp

    case "$_vp_layout_result" in
      applied)
        log_sub "Installed the Virtual Paradise shell layout (shell-paradise.json)"
        ;;
      preserved)
        log_warn "Existing ~/.config/omarchy/shell.json contains customizations; preserving it."
        log_info "  Run '$0 --force-shell-layout' to replace it with the theme layout."
        ;;
      *)
        log_warn "Could not install the Virtual Paradise shell layout."
        ;;
    esac
    unset _vp_layout_result
  else
    log_warn "Could not create a temporary file for the shell layout."
  fi

  # The shell layout copy above can reset plugin enablement. Restore the
  # external plugins after the layout is installed.
  if command -v omarchy &>/dev/null; then
    po_apply_all
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
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.bluetooth" 2>/dev/null || true
    enable_plugin_retry "io.github.tyrichards.workspaces-jap" || \
      log_warn "Japanese workspace plugin could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
    RUN_AS_INSTALL_USER omarchy plugin disable "${CURRENT_USER}.workspaces" 2>/dev/null || true
    RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.workspaces" 2>/dev/null || true
    if (( BAR_INSTALL_OK == 1 )); then
      enable_plugin_retry "${CURRENT_USER}.island-bar" || \
        log_warn "Paradise Island Bar could not be enabled after shell layout sync: ${LAST_PLUGIN_ERROR:-unknown error}"
      RUN_AS_INSTALL_USER omarchy plugin disable "omarchy.bar" 2>/dev/null || true
      RUN_AS_INSTALL_USER omarchy plugin disable "mscurtescu.island-bar" 2>/dev/null || true
    else
      # No usable first-party bar: leave the stock one enabled. The layout may
      # still name the island bar, and Omarchy's activeBarId handles the
      # fallback without us editing the user's file.
      RUN_AS_INSTALL_USER omarchy plugin enable "omarchy.bar" 2>/dev/null || true
    fi
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
  },
  "paradise.logout": {
    "icon": "󰍾",
    "label": "Log out with transition",
    "description": "Glitch curtain, then hand over to the login screen",
    "action": "bash -c ~/.local/bin/transition.sh logout"
  },
  "paradise.reboot": {
    "icon": "󰖦",
    "label": "Reboot with transition",
    "description": "Glitch curtain, then hand over to Plymouth",
    "action": "bash -c ~/.local/bin/transition.sh reboot"
  },
  "paradise.shutdown": {
    "icon": "󰐥",
    "label": "Shut down with transition",
    "description": "Glitch curtain, then hand over to Plymouth",
    "action": "bash -c ~/.local/bin/transition.sh shutdown"
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
#
# The display layout belongs to hyprmoncfg, Omarchy's display manager: it
# applies a profile per monitor setup and switches between them on hotplug,
# lid and suspend. The theme used to ship static rules for eDP-1, HDMI-A-1,
# DP-1 and DP-2 with a fixed scale of 1.0. That kept the laptop panel alive
# with the wrong scale even when hyprmoncfg wanted it off, and made every
# external display render at 1x on a HiDPI panel. Those presets are removed
# here on machines that ran the old installer.
monitors_file="$CONFIG_DIR/hypr/monitors.lua"
if [[ -f $monitors_file ]]; then
  # Strip the theme's legacy display presets. A block is only ours when it
  # names one of the theme's outputs *and* carries the theme's signature
  # fields, so a rule the user wrote by hand is never touched.
  legacy_presets="$(awk '
    function flush() {
      if (buf != "") {
        is_preset = (named_edp && scaled && transform0 && pos0) \
          || (named_ext && scaled && autright)
        if (!is_preset) printf "%s", buf
        buf = ""; named_edp = 0; named_ext = 0; scaled = 0
        autright = 0; transform0 = 0; pos0 = 0
      }
    }
    function inspect(line) {
      if (line ~ /output[[:space:]]*=[[:space:]]*"eDP-1"/) named_edp = 1
      if (line ~ /output[[:space:]]*=[[:space:]]*"(HDMI-A-1|DP-1|DP-2)"/) named_ext = 1
      if (line ~ /scale[[:space:]]*=[[:space:]]*1\.0/) scaled = 1
      if (line ~ /position[[:space:]]*=[[:space:]]*"auto-right"/) autright = 1
      if (line ~ /transform[[:space:]]*=[[:space:]]*0/) transform0 = 1
      if (line ~ /position[[:space:]]*=[[:space:]]*"0x0"/) pos0 = 1
    }
    /hl\.monitor\(\{/ {
      buf = $0 "\n"
      inspect($0)
      if ($0 ~ /\}\)/) { flush(); next }
      inblock = 1
      next
    }
    inblock {
      buf = buf $0 "\n"
      inspect($0)
      if ($0 ~ /^\}\)/) { flush(); inblock = 0 }
      next
    }
    { print }
  ' "$monitors_file")"

  if [[ "$legacy_presets" != "$(cat "$monitors_file")" ]]; then
    hypr_backup "$monitors_file"
    printf '%s\n' "$legacy_presets" >"$monitors_file"
    log_sub "Removed the static display presets so hyprmoncfg owns the layout"
  fi

  # Preserve user custom monitor positions but ensure crisp Wayland toolkit variables
  if ! grep -q "ELECTRON_OZONE_PLATFORM_HINT" "$monitors_file"; then
    hypr_backup "$monitors_file"
    cat << 'EOF' >> "$monitors_file"

-- Virtual☆Paradise Toolkit & Wayland Envs
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
EOF
    log_sub "Injected Wayland toolkit environment variables into ~/.config/hypr/monitors.lua"
  fi
elif [[ -f "$REPO_DIR/hypr/monitors.lua" ]]; then
  cp "$REPO_DIR/hypr/monitors.lua" "$CONFIG_DIR/hypr/monitors.lua"
  log_sub "Initialized default display configuration"
fi

# 5.5 Autostart: ensure the session splash and the live wallpaper are hooked
#
# The file is the user's (Omarchy ships its own), so the hooks are added to it
# instead of replacing it. Both are checked separately: a machine that
# already had the live wallpaper still needs the splash.
if [[ -f "$CONFIG_DIR/hypr/autostart.lua" ]]; then
  if ! grep -q "session_splash.sh" "$CONFIG_DIR/hypr/autostart.lua"; then
    hypr_backup "$CONFIG_DIR/hypr/autostart.lua"
    echo 'o.launch_on_start("session_splash.sh")' >> "$CONFIG_DIR/hypr/autostart.lua"
    log_sub "Hooked the session splash to ~/.config/hypr/autostart.lua"
  fi
  if ! grep -q "vp_death_daemon.sh" "$CONFIG_DIR/hypr/autostart.lua"; then
    hypr_backup "$CONFIG_DIR/hypr/autostart.lua"
    echo 'o.launch_on_start("vp_death_daemon.sh")' >> "$CONFIG_DIR/hypr/autostart.lua"
    log_sub "Hooked the window death daemon to ~/.config/hypr/autostart.lua"
  fi
  # Omarchy 4.5 renders video wallpapers itself, so the theme's mpvpaper
  # engine is retired. Remove the old autostart line so an updated install
  # does not start a second decoder.
  if grep -q "toggle_live_wallpaper.sh" "$CONFIG_DIR/hypr/autostart.lua"; then
    hypr_backup "$CONFIG_DIR/hypr/autostart.lua"
    sed -i '/o\.launch_on_start("toggle_live_wallpaper\.sh/d' \
      "$CONFIG_DIR/hypr/autostart.lua" 2>/dev/null || true
    log_sub "Retired the mpvpaper autostart from ~/.config/hypr/autostart.lua"
  fi
  # The window death burst moved into the shell as an overlay plugin. Remove
  # the old daemon line so an updated install does not keep a second
  # Quickshell resident.
  if grep -q "vp_death_daemon.sh" "$CONFIG_DIR/hypr/autostart.lua"; then
    hypr_backup "$CONFIG_DIR/hypr/autostart.lua"
    sed -i '/o\.launch_on_start("vp_death_daemon\.sh")/d' \
      "$CONFIG_DIR/hypr/autostart.lua" 2>/dev/null || true
    log_sub "Retired the old window-death daemon from ~/.config/hypr/autostart.lua"
  fi
  if ! grep -q "vp-sound.sh" "$CONFIG_DIR/hypr/autostart.lua"; then
    hypr_backup "$CONFIG_DIR/hypr/autostart.lua"
    echo 'o.launch_on_start("vp-sound.sh login")' >> "$CONFIG_DIR/hypr/autostart.lua"
    log_sub "Hooked the login chime to ~/.config/hypr/autostart.lua"
  fi
elif [[ -f "$REPO_DIR/hypr/autostart.lua" ]]; then
  cp "$REPO_DIR/hypr/autostart.lua" "$CONFIG_DIR/hypr/autostart.lua"
fi

# 5.6 Window Rules (Btop, Voxtype, Cast Screen, Nautilus)
#
# hyprmoncfg loads its generated monitor rules last, on purpose: anything after
# that line can override the layout it applies, and its own doctor reports the
# setup as broken. The window rules therefore have to sit *before* that line.
VP_RULES_BLOCK=""

# Take the theme's window-rule block out of a Hyprland config and keep it in
# $VP_RULES_BLOCK.

# Replace a file without changing who owns it or how it may be read.
#
# A mktemp file is created with mode 600 and `mv` keeps that mode, so the
# Hyprland config ended up as -rw------- : the compositor answered "cannot
# open ~/.config/hypr/hyprland.lua: Permission denied", and during a root run
# the file was root-owned on top of that until the installer cleaned up. The
# original mode and owner are restored here.
# (lib/file-ops.sh, so the test suite can exercise it directly.)

# Put the block back, in front of hyprmoncfg's "load last" line.

if [[ -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
  # Guard on our own marker, not on "GNOME Network Displays": a user comment
  # mentioning that app must not suppress the rules, and the marker is what
  # uninstall.sh removes.
  if ! grep -q "Virtual Paradise Add-on Window Rules" "$CONFIG_DIR/hypr/hyprland.lua"; then
    hypr_backup "$CONFIG_DIR/hypr/hyprland.lua"
    VP_RULES_BLOCK="$(cat << 'EOF'

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
)"
  else
    # The rules are already there, but a previous install appended them after
    # hyprmoncfg's line. Take them out and put them back in front of it.
    hypr_backup "$CONFIG_DIR/hypr/hyprland.lua"
    extract_rules_block "$CONFIG_DIR/hypr/hyprland.lua" || true
  fi

  if [[ -n $VP_RULES_BLOCK ]]; then
    insert_rules_block "$CONFIG_DIR/hypr/hyprland.lua"
    log_sub "Configured floating window rules for Btop, Voxtype, Cast Screen & Nautilus"
  fi
fi

# 5.7 Config files the compositor has to read
#
# The compositor runs as the user, so a config file that ended up unreadable
# (mode 600 - a mktemp file that was moved into place - or owned by root
# during a `sudo ./install.sh` run) shows up in the error overlay as
# "cannot open ~/.config/hypr/hyprland.lua: Permission denied". Every file
# the theme writes is made readable and owned by the user again.
for hypr_file in looknfeel.lua input.lua bindings.lua monitors.lua autostart.lua hyprland.lua; do
  ensure_readable_file "$CONFIG_DIR/hypr/$hypr_file" "$CURRENT_USER" || true
done

# NOTE: hypr/hyprland.lua and hypr/hyprland.conf were removed. Omarchy loads
# hyprland.lua as its own entry point which require()s monitors -> input ->
# bindings -> looknfeel -> autostart, so a standalone repo hyprland.lua was
# never loaded and only shadowed looknfeel.lua. hypr/hyprlock.conf was removed
# too: hyprlock is not used (Omarchy locks via the Quickshell lock plugin).
if [[ -f "$REPO_DIR/hypr/hyprland-preview-share-picker.css" ]]; then
  cp "$REPO_DIR/hypr/hyprland-preview-share-picker.css" "$CONFIG_DIR/hypr/hyprland-preview-share-picker.css" 2>/dev/null || true
fi

# Older releases shipped their own hyprland.conf. Hyprland ignores it while
# hyprland.lua exists, but it looks like a live config and hides the real one,
# so drop it when it is clearly ours.
legacy_hypr_conf="$CONFIG_DIR/hypr/hyprland.conf"
if [[ -f $legacy_hypr_conf ]] && grep -qF 'Virtual☆Paradise Hyprland Config' "$legacy_hypr_conf"; then
  if [[ -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
    rm -f "$legacy_hypr_conf"
    log_sub "Removed the legacy hyprland.conf (Omarchy loads hyprland.lua)"
  else
    log_warn "Keeping $legacy_hypr_conf: it is the only Hyprland config on this machine."
  fi
fi

# 5.5 Fcitx5 Vietnamese Input Method (Unikey) Configuration
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

  # Scripts that used to be part of the theme. sync_tree merges, so a file the
  # repository no longer ships would stay in ~/.local/bin forever and keep
  # answering to a name the documentation dropped.
  rm -f "$LOCAL_BIN/widgets.sh" "$LOCAL_BIN/rice" "$LOCAL_BIN/Miku_missing.mp4" \
    "$LOCAL_BIN/session_splash.qml" 2>/dev/null || true

  sync_tree "$REPO_DIR/bin" "$LOCAL_BIN"
  rm -rf "$LOCAL_BIN/__pycache__"
  chmod +x "$LOCAL_BIN"/*.sh "$LOCAL_BIN"/*.py "$LOCAL_BIN"/momoisay "$LOCAL_BIN"/momoisay.real 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/paradise_banner.sh" "$LOCAL_BIN/paradise-banner" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/virtual_matrix.py" "$LOCAL_BIN/virtual_matrix" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/cast_screen.sh" "$LOCAL_BIN/cast-screen" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/format-docx" 2>/dev/null || true
  ln -nsf "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/vn-docx" 2>/dev/null || true
  chmod +x "$LOCAL_BIN/sync_cava_theme.py" "$LOCAL_BIN/virtual_matrix.py" "$LOCAL_BIN/cast_screen.sh" "$LOCAL_BIN/format-docx-vn.py" "$LOCAL_BIN/paradise_banner.py" "$LOCAL_BIN/paradise_banner.sh" "$LOCAL_BIN/session_splash.sh" "$LOCAL_BIN/window_death.sh" "$LOCAL_BIN/vp_death_daemon.sh" 2>/dev/null || true

  # The artwork for the session splash: the cyber background, the animation
  # still and the neon frame in one picture, which the glitch curtain cuts
  # apart. The whole way from the firmware to the desktop is one image.
  for splash_asset in session_base.png noise.jpg scanlines.png; do
    [[ -f "$REPO_DIR/plymouth/$splash_asset" ]] &&
      cp -f "$REPO_DIR/plymouth/$splash_asset" "$LOCAL_BIN/$splash_asset" 2>/dev/null || true
  done

  # Self-contained uninstaller: the file in ~/.local/bin is only a wrapper.
  # The real script runs from the theme's data directory, where the libs and
  # payload it needs (sddm, plymouth, hypr, fastfetch, micro, plugins, bin) are
  # mirrored next to it, so it can remove the boot/login themes and restore
  # configs even when the repository is gone. Copying only uninstall.sh used to
  # leave it without lib/sddm.sh and lib/plymouth.sh (themes stayed installed)
  # and without shell-layout.sh (it overwrote a custom shell.json).
  sync_tree "$REPO_DIR/lib" "$VP_DATA_DIR/lib" mirror
  sync_tree "$REPO_DIR/hypr" "$VP_DATA_DIR/hypr" mirror
  sync_tree "$REPO_DIR/fastfetch" "$VP_DATA_DIR/fastfetch" mirror
  sync_tree "$REPO_DIR/micro" "$VP_DATA_DIR/micro" mirror
  sync_tree "$REPO_DIR/plugins" "$VP_DATA_DIR/plugins" mirror
  sync_tree "$REPO_DIR/bin" "$VP_DATA_DIR/bin" mirror
  sync_tree "$REPO_DIR/overrides" "$VP_DATA_DIR/overrides" mirror
  mkdir -p "$VP_DATA_DIR/plymouth"
  [[ -f "$REPO_DIR/plymouth/override.conf" ]] \
    && cp -f "$REPO_DIR/plymouth/override.conf" "$VP_DATA_DIR/plymouth/override.conf"
  cp "$REPO_DIR/uninstall.sh" "$VP_DATA_DIR/uninstall.sh"
  chmod +x "$VP_DATA_DIR/uninstall.sh"
  cat > "$LOCAL_BIN/uninstall-virtual-paradise" <<EOF
#!/usr/bin/env bash
# Wrapper: the self-contained uninstaller lives in the theme data directory.
exec "$VP_DATA_DIR/uninstall.sh" "\$@"
EOF
  chmod +x "$LOCAL_BIN/uninstall-virtual-paradise"
  log_sub "Installed helper tools (rice_layout, momoisay, toggle_live_wallpaper, logout_splash, paradise-banner, etc.)"
fi

# ------------------------------------------------------------------------------
# 6b. Plugin update mechanism
# ------------------------------------------------------------------------------
# bin/update-plugins.sh locates the override layer relative to its own path, so
# the shared lib has to sit next to it rather than only in the repo.
if [[ -f "$REPO_DIR/bin/update-plugins.sh" && -f "$REPO_DIR/lib/plugin-overrides.sh" ]]; then
  mkdir -p "$VP_DATA_DIR"
  cp "$REPO_DIR/lib/plugin-overrides.sh" "$VP_DATA_DIR/plugin-overrides.sh"
  cp "$REPO_DIR/lib/lock.sh" "$VP_DATA_DIR/lock.sh" 2>/dev/null || true
  # The theme-set hook and the post-update hook both need the same three-way
  # shell.json rules the installer just used.
  [[ -f "$REPO_DIR/lib/shell-layout.sh" ]] &&
    cp "$REPO_DIR/lib/shell-layout.sh" "$VP_DATA_DIR/shell-layout.sh"
  # The updater runs from a systemd timer whose environment has no
  # OMARCHY_PATH, so it needs the same helper the installer uses.
  [[ -f "$REPO_DIR/lib/omarchy-env.sh" ]] &&
    cp "$REPO_DIR/lib/omarchy-env.sh" "$VP_DATA_DIR/omarchy-env.sh"
  # The installed updater has no repo in sight, so mirror overrides/ next to the
  # lib; it re-applies this rice after every update.
  rm -rf "$VP_DATA_DIR/overrides"
  [[ -d "$REPO_DIR/overrides" ]] &&
    cp -r "$REPO_DIR/overrides" "$VP_DATA_DIR/overrides"
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
log_step "7" "$TOTAL_STEPS" "Installing Cava, Btop, Fastfetch, Micro, Yazi, Bat & tmux theme profiles..."

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

# Yazi file manager rice
if [[ -f "$REPO_DIR/config/yazi/theme.toml" ]]; then
  mkdir -p "$CONFIG_DIR/yazi"
  if [[ -f "$CONFIG_DIR/yazi/theme.toml" ]] \
    && ! cmp -s "$REPO_DIR/config/yazi/theme.toml" "$CONFIG_DIR/yazi/theme.toml"; then
    if [[ ! -f "$CONFIG_DIR/yazi/theme.toml.paradise.bak" ]]; then
      cp "$CONFIG_DIR/yazi/theme.toml" \
        "$CONFIG_DIR/yazi/theme.toml.paradise.bak" || true
    fi
  fi
  cp "$REPO_DIR/config/yazi/theme.toml" "$CONFIG_DIR/yazi/theme.toml"
fi

# Bat syntax highlighter theme (additive: the file is ours, the cache rebuild
# is what makes `bat` see it).
if [[ -d "$REPO_DIR/config/bat/themes" ]]; then
  mkdir -p "$CONFIG_DIR/bat/themes"
  cp -r "$REPO_DIR/config/bat/themes"/* "$CONFIG_DIR/bat/themes/" 2>/dev/null || true
  if command -v bat >/dev/null 2>&1; then
    RUN_AS_INSTALL_USER bat cache --build >/dev/null 2>&1 || true
  fi
fi

# tmux status bar theme: install the palette file and source it from the
# user's tmux.conf behind a marker block, so uninstall can strip it again.
if [[ -f "$REPO_DIR/config/tmux/paradise.conf" ]]; then
  mkdir -p "$CONFIG_DIR/tmux"
  cp "$REPO_DIR/config/tmux/paradise.conf" "$CONFIG_DIR/tmux/paradise.conf"
  if [[ -f "$CONFIG_DIR/tmux/tmux.conf" ]] \
    && ! grep -q 'Virtual☆Paradise tmux theme' "$CONFIG_DIR/tmux/tmux.conf"; then
    if [[ ! -f "$CONFIG_DIR/tmux/tmux.conf.paradise.bak" ]]; then
      cp "$CONFIG_DIR/tmux/tmux.conf" \
        "$CONFIG_DIR/tmux/tmux.conf.paradise.bak" || true
    fi
    printf '\n# Virtual☆Paradise tmux theme (managed by install.sh; remove this block to opt out)\nsource-file %s\n' \
      "$CONFIG_DIR/tmux/paradise.conf" >> "$CONFIG_DIR/tmux/tmux.conf"
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

# Optional qt6ct colour scheme. Omarchy points Qt at the GTK platform theme, so
# this is only used by machines that switch to qt6ct themselves.
if [[ -f "$REPO_DIR/config/qt6ct/colors/VirtualParadise.conf" ]]; then
  mkdir -p "$CONFIG_DIR/qt6ct/colors"
  cp "$REPO_DIR/config/qt6ct/colors/VirtualParadise.conf" \
     "$CONFIG_DIR/qt6ct/colors/VirtualParadise.conf"
fi

# Theme UI sounds (login, lock, unlock, error, notify). Played by vp-sound.sh.
if [[ -d "$REPO_DIR/sounds" ]]; then
  mkdir -p "$HOME/.local/share/sounds/virtual-paradise"
  cp "$REPO_DIR/sounds"/*.oga "$HOME/.local/share/sounds/virtual-paradise/" 2>/dev/null || true
fi
log_sub "Component themes installed (Cava, Btop, Fastfetch, Micro, Yazi, Bat, tmux, GTK/Nautilus & Tela-Circle Icons)"

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
  # read back by the theme-set hook. Everything installed to its own place -
  # plugins, bars, bin, lib, shell, systemd, sddm, plymouth, micro, cava,
  # fastfetch - is delivered by its own step and would only be dead weight
  # here.
  #
  # `backgrounds/` is excluded on purpose. The wallpapers are ~95 MB of video,
  # and Omarchy stages the whole theme directory into
  # ~/.local/state/omarchy/current/theme on every theme switch - copying 95 MB
  # of video took ~15 seconds, on every login. They live in
  # ~/.config/omarchy/backgrounds/virtual-paradise instead, which Omarchy
  # scans for wallpapers as well.
  #
  # One list feeds both the rsync excludes and the cleanup below. --exclude also
  # stops --delete removing a copy an earlier run placed, so the two must agree
  # or a stripped directory would linger forever.
  THEME_STRIP=(
    .git .github .githooks .gitignore
    tests tools docs backgrounds sounds
    install.sh uninstall.sh README.md LICENSE CONTRIBUTING.md
    plugins bars bin lib shell systemd sddm plymouth micro cava fastfetch
  )

  strip_args=()
  for item in "${THEME_STRIP[@]}"; do strip_args+=(--exclude="$item"); done

  # Copy without --delete: a file the user drops into the theme directory must
  # survive a reinstall. Theme files removed upstream are pruned from the
  # manifest, so stale payload does not accumulate either.
  if ! sync_manifest "$REPO_DIR" "$THEME_DEST" "${strip_args[@]}"; then
    log_warn "Theme copy failed. The theme may be incomplete — re-run the installer."
  fi

  for item in "${THEME_STRIP[@]}"; do
    rm -rf "${THEME_DEST:?}/$item"
  done
  rm -rf "$THEME_DEST/__pycache__"
  find "$THEME_DEST" -name '*.pyc' -delete 2>/dev/null || true

  # A fresh install replaces the theme files with the repository's originals,
  # so the palette baseline the variant switcher keeps has to go with them.
  rm -rf "$HOME/.local/state/virtual-paradise/theme-variant-orig"
  rm -f "$HOME/.local/state/virtual-paradise/current_variant" \
        "$HOME/.local/state/virtual-paradise/theme-variant-map"
fi

# The wallpapers live outside the theme directory.
#
# Omarchy stages the whole theme into ~/.local/state/omarchy/current/theme on
# every theme switch, and the wallpapers are ~95 MB of video: copying them
# took about 15 seconds of every login and every theme switch. Omarchy scans
# ~/.config/omarchy/backgrounds/<theme>/ for wallpapers as well, so they go
# there - the theme directory stays small and the switch is instant.
WALLPAPER_DEST="$CONFIG_DIR/omarchy/backgrounds/$THEME_NAME"
if [[ -d "$REPO_DIR/backgrounds" ]]; then
  mkdir -p "$WALLPAPER_DEST"
  # Copy without --delete: a user's own wallpaper in this directory must not be
  # destroyed by a reinstall. Theme files removed upstream are pruned via the
  # manifest.
  sync_manifest "$REPO_DIR/backgrounds" "$WALLPAPER_DEST" || true
  # The animated GIFs are not wallpapers here: they are the SDDM login
  # animation, and the login theme reads them straight from the repository.
  # As wallpapers they were pure cost - Omarchy picks the bar's text color
  # with ImageMagick, and rendering 250 animation frames took over a minute
  # on every theme switch.
  #
  # They are removed rather than converted: the repository ships a sharp
  # 1920x1080 JPG with the same name, and converting the GIF over it
  # replaced that picture with a blurry 480x270 frame.
  # Remove only the theme's own animated GIFs; a user's GIF in the wallpaper
  # directory is not ours to delete.
  for gif in "$REPO_DIR"/backgrounds/*.gif; do
    [[ -f $gif ]] && rm -f "$WALLPAPER_DEST/$(basename "$gif")" 2>/dev/null || true
  done
  unset gif

  log_sub "Installed wallpapers to $WALLPAPER_DEST"
fi

# The theme needs a preview image: without one the theme switcher falls back
# to the first wallpaper it finds, which is the slow path this theme just
# avoided.
if [[ -f "$REPO_DIR/backgrounds/Glitch.jpg" && -d "$CONFIG_DIR/omarchy/themes/$THEME_NAME" ]]; then
  cp -f "$REPO_DIR/backgrounds/Glitch.jpg" \
    "$CONFIG_DIR/omarchy/themes/$THEME_NAME/preview.jpg" 2>/dev/null || true
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

# Flatten assets (preview.png, unlock.png) into theme root for the Omarchy
# theme picker & Plymouth switcher.
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

# Post-update repair hook. `omarchy update` runs this as the user after
# packages and migrations; it verifies the first-party bar, repairs it from the
# user-owned copy when possible, re-applies overrides, and never edits a
# package-owned Omarchy file.
if [[ -f "$REPO_DIR/lib/post-update-hook.sh" ]]; then
  cp "$REPO_DIR/lib/post-update-hook.sh" "$CONFIG_DIR/omarchy/hooks/post-update.d/virtual-paradise.sh"
  chmod +x "$CONFIG_DIR/omarchy/hooks/post-update.d/virtual-paradise.sh"
  log_sub "Installed post-update repair hook (island bar, overrides, shell layout)"
else
  log_warn "Post-update hook template not found at $REPO_DIR/lib/post-update-hook.sh"
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
    # Wallpaper rotation and the day/night variant switch change the desktop
    # behind the user's back, so they are installed as opt-in units and left
    # disabled. The palette timer in particular must not surprise anyone with
    # a pink evening; `systemctl --user enable --now` turns either one on.
    if [[ -f "$REPO_DIR/systemd/paradise-wallpaper-rotate.timer" ]]; then
      cp "$REPO_DIR/systemd/paradise-wallpaper-rotate.service" \
         "$REPO_DIR/systemd/paradise-wallpaper-rotate.timer" \
         "$REPO_DIR/systemd/paradise-variant-by-time.service" \
         "$REPO_DIR/systemd/paradise-variant-by-time.timer" \
         "$CONFIG_DIR/systemd/user/"
      log_sub "Wallpaper rotation + day/night variant installed (opt-in, disabled)"
      log_sub "  enable wallpaper rotation: systemctl --user enable --now paradise-wallpaper-rotate.timer"
      log_sub "  enable day/night variant:  systemctl --user enable --now paradise-variant-by-time.timer"
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
    # discovery, so enforce the external plugin state last.
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
