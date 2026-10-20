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
