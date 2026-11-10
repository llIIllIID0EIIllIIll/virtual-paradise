#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034
# SC2154: installer globals are set by install.sh before these run.
# SC2034: variables are read by install.sh, not here.
# ==============================================================================
#  Virtual☆Paradise — boot theme step (SDDM, Plymouth, UKI)
# ==============================================================================
#  Shared by the full install, --boot-only and --sddm-only. Sourced by
#  install.sh after the helper and system libraries.
# ==============================================================================

INSTALL_SDDM_THEME() {
  [[ -f "$REPO_DIR/lib/sddm.sh" ]] || return 1
  run_privileged bash -c \
    '. "$1/lib/sddm.sh" && sddm_theme_install "/" "$1"' _ "$REPO_DIR"
}

INSTALL_PLYMOUTH_THEME() {
  [[ -f "$REPO_DIR/lib/plymouth.sh" ]] || return 1
  run_privileged bash -c \
    '. "$1/lib/plymouth.sh" && plymouth_theme_install "/" "$1"' _ "$REPO_DIR"
}

boot_image_age() {
  run_privileged bash -c '
    for f in /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/Linux/arch-linux.efi \
             /boot/initramfs-linux.img /boot/initrd.img; do
      [ -e "$f" ] || continue
      echo "$f $(( $(date +%s) - $(stat -c %Y "$f") ))"
      exit 0
    done
    exit 1
  ' 2>/dev/null
}

disable_autologin() {
  local conf="/etc/sddm.conf.d/autologin.conf"
  [[ -f $conf ]] || return 0
  grep -qE '^[[:space:]]*User=' "$conf" || return 0

  run_privileged cp -a "$conf" "$conf.paradise.bak" 2>/dev/null || true
  if run_privileged sed -i \
      -e 's/^\([[:space:]]*User=\)/\;#\1/' \
      -e 's/^\([[:space:]]*Session=\)/\;#\1/' \
      "$conf"; then
    printf 'Disabled the SDDM autologin; the login screen is shown now.\n'
    return 0
  fi
  printf 'Could not disable the SDDM autologin.\n' >&2
  return 1
}

INSTALL_BOOT_ANIMATIONS() {
  log_step "9" "$TOTAL_STEPS" "Configuring Plymouth Boot Animation, SDDM Display Manager & UKI Kernel..."
  local sddm_ok=0 plymouth_ok=0

  if [[ $ENABLE_BOOT -eq 1 ]] && run_privileged true; then
    # 1. SDDM Setup
    #
    # The theme goes into its own directory and is selected with a drop-in;
    # patching /usr/share/sddm/themes/omarchy (owned by omarchy-settings) meant
    # a package update reverted half of it and uninstall.sh had nothing to
    # restore. sddm_theme_install also repairs machines that ran the old
    # in-place patch.
    if INSTALL_SDDM_THEME; then
      sddm_ok=1
      log_sub "Installed SDDM theme 'virtual-paradise' (Omarchy's theme left untouched)"
    else
      log_warn "SDDM theme was not installed; the login screen is unchanged."
    fi

    if [[ $NO_AUTOLOGIN -eq 1 ]]; then
      disable_autologin || true
    fi

    # 2. Plymouth Theme Setup
    #
    # The theme goes into its own directory and is selected by name. The old
    # installer overwrote /usr/share/plymouth/themes/omarchy/omarchy.script and
    # dropped ~330 generated PNGs into that package-owned directory: a package
    # update reverted the animation and uninstall.sh had nothing to restore.
    # plymouth_theme_install also repairs machines that ran the old in-place
    # patch.
    if INSTALL_PLYMOUTH_THEME; then
      plymouth_ok=1
      log_sub "Installed Plymouth theme 'virtual-paradise' (Omarchy's theme left untouched)"
    else
      log_warn "Plymouth theme was not installed; the boot splash is unchanged."
    fi

    # Systemd overrides for instant Plymouth handover (no SDDM delay). These
    # are our own drop-ins; uninstall.sh removes them again.
    run_privileged mkdir -p /etc/systemd/system/plymouth-poweroff.service.d /etc/systemd/system/plymouth-reboot.service.d
    if [[ -f "$REPO_DIR/plymouth/override.conf" ]]; then
      run_privileged cp "$REPO_DIR/plymouth/override.conf" "/etc/systemd/system/plymouth-poweroff.service.d/override.conf"
      run_privileged cp "$REPO_DIR/plymouth/override.conf" "/etc/systemd/system/plymouth-reboot.service.d/override.conf"
      run_privileged systemctl daemon-reload
    fi

    # Rebuild UKI / initramfs
    #
    # Both paths are tried and the output is shown. The old code picked one
    # with an if/elif and threw the output away, so a failing rebuild left
    # the boot image with the previous splash and the installer said nothing:
    # the theme was installed, the machine rebooted, and the splash was
    # exactly the same. The mtime of the boot image is checked afterwards so
    # a silently skipped rebuild cannot pass as a success.
    local rebuild_ok=0
    local image_info image age

    if command -v limine-mkinitcpio &>/dev/null; then
      log_sub "Rebuilding UKI image with limine-mkinitcpio..."
      if run_privileged limine-mkinitcpio; then
        rebuild_ok=1
      else
        log_warn "limine-mkinitcpio failed; falling back to mkinitcpio -P."
      fi
    fi

    if [[ $rebuild_ok -eq 0 ]] && command -v mkinitcpio &>/dev/null; then
      log_sub "Rebuilding initramfs with mkinitcpio -P..."
      if run_privileged mkinitcpio -P; then
        rebuild_ok=1
      else
        log_warn "mkinitcpio -P failed."
      fi
    fi

    if [[ $rebuild_ok -eq 1 ]]; then
      image_info="$(boot_image_age || true)"
      image="${image_info%% *}"
      age="${image_info##* }"
      if [[ -n $image && $image =~ ^/ && $age =~ ^[0-9]+$ && $age -gt 600 ]]; then
        log_warn "The boot image $image was not updated (older than 10 minutes)."
        log_warn "The new splash only shows up after the boot image is rebuilt."
      elif [[ -n $image ]]; then
        log_sub "Boot image rebuilt: $image"
      else
        log_warn "The boot image could not be located after the rebuild."
      fi
    else
      log_warn "The boot image was NOT rebuilt - the old splash stays until it is."
      log_warn "Run 'sudo mkinitcpio -P' (or 'sudo limine-mkinitcpio') by hand, then reboot."
    fi

    # --boot-only promises the boot/login themes; report failure instead of
    # printing success when neither could be installed.
    if [[ $sddm_ok -eq 0 && $plymouth_ok -eq 0 && $BOOT_ONLY -eq 1 ]]; then
      log_warn "Neither the SDDM nor the Plymouth theme could be installed."
      return 1
    fi
  else
    log_warn "Sudo privileges not available. Skipping system-wide Plymouth/SDDM setup."
    log_warn "Run 'sudo ./install.sh --boot-only' to enable boot & shutdown animations."
    return 1
  fi
  return 0
}

