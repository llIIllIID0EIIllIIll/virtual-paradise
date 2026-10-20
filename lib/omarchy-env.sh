#!/usr/bin/env bash
# Virtual☆Paradise — Omarchy environment helpers.
#
# Omarchy sets OMARCHY_PATH in the user's shell (its env-bootstrap) and every
# `omarchy ...` command needs it:
#
#   $ env -i PATH=/usr/bin HOME=~ omarchy plugin list
#   OMARCHY_PATH is not set
#   $ env -i PATH=/usr/bin HOME=~ omarchy restart shell
#   Omarchy shell config not found: /shell
#
# sudo resets the environment, so `sudo ./install.sh` starts without it. Every
# plugin, theme and shell step then fails - and because the installer ignores
# those failures, the run looks successful while the plugins were never
# enabled and the shell was never restarted.
#
# This resolves the path the way Omarchy itself does and exports it, so the
# installer works the same whether it is started from a terminal, with sudo,
# from a hook or from a service.
#
# Sourced by install.sh and uninstall.sh; defines functions only.

# The path of the Omarchy installation.
#
# /etc/omarchy.conf is written by omarchy-dev-link (and reset by
# omarchy-dev-unlink) as `export OMARCHY_PATH="/path/to/checkout"`. It is
# parsed instead of sourced, so nothing but the path is taken from it.
omarchy_resolve_path() {
  local conf="/etc/omarchy.conf" value=""

  if [[ -f $conf ]]; then
    value="$(sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?OMARCHY_PATH[[:space:]]*=[[:space:]]*(.*)$/\2/p' "$conf" | tail -n 1)"
    value="${value%"${value%%[![:space:]]*}"}"  # trim leading space
    value="${value%"${value##*[![:space:]]}"}"  # trim trailing space
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
  fi

  # The packaged installation is the default; a dev checkout is the exception.
  [[ -n $value ]] || value="/usr/share/omarchy"

  printf '%s\n' "$value"
}

# Resolve OMARCHY_PATH for this process and everything it starts.
omarchy_export_env() {
  OMARCHY_PATH="$(omarchy_resolve_path)"
  export OMARCHY_PATH

  # A dev checkout keeps its commands in $OMARCHY_PATH/bin, which is not on
  # PATH under sudo.
  if [[ "$OMARCHY_PATH" != "/usr/share/omarchy" ]]; then
    case ":$PATH:" in
      *":$OMARCHY_PATH/bin:"*) ;;
      *) PATH="$OMARCHY_PATH/bin:$PATH"; export PATH ;;
    esac
  fi
}

# Resolve the graphical session variables of a user.
#
# sudo resets them along with OMARCHY_PATH, and without them `hyprctl reload`
# cannot find the compositor: the theme's Hyprland changes would only land at
# the next login, and the notifications would go nowhere. The values are read
# from the user's runtime directory, which is where Hyprland and the Wayland
# compositor keep them anyway.
omarchy_resolve_session_env() {
  local user="${1:-${USER:-$(id -un)}}" uid runtime candidate
  uid="$(id -u "$user" 2>/dev/null)" || return 1
  [[ -n $uid ]] || return 1
  runtime="/run/user/$uid"

  if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    # The running instance is the newest one; the older directories in the
    # runtime directory are leftovers of previous sessions.
    HYPRLAND_INSTANCE_SIGNATURE="$(ls -1t "$runtime/hypr" 2>/dev/null | head -n 1)"
  fi

  if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    for candidate in "$runtime"/wayland-*; do
      if [[ -S $candidate ]]; then
        WAYLAND_DISPLAY="${candidate##*/}"
        break
      fi
    done
  fi

  if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]] && [[ -S "$runtime/bus" ]]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
  fi

  XDG_RUNTIME_DIR="$runtime"

  export HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR
  return 0
}
