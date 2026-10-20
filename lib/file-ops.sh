#!/usr/bin/env bash
# Virtual☆Paradise — file helpers.
#
# Sourced by install.sh; defines functions only.

# Replace a file without changing who owns it or how it may be read.
#
# A mktemp file is created with mode 600 and `mv` keeps that mode, so moving
# a freshly built Hyprland config into place turned it into -rw-------. In a
# `sudo ./install.sh` run the file was root-owned on top of that, and the
# compositor answered "cannot open ~/.config/hypr/hyprland.lua: Permission
# denied" in its error overlay. The original mode and owner are restored
# here.
replace_file_preserving() {
  local target="$1" source="$2" mode owner
  mode="$(stat -c '%a' "$target" 2>/dev/null || echo 644)"
  owner="$(stat -c '%u:%g' "$target" 2>/dev/null || echo '')"

  mv "$source" "$target" || return 1

  chmod "$mode" "$target" 2>/dev/null || chmod 644 "$target" 2>/dev/null || true
  if [[ -n $owner ]] && (( EUID == 0 )); then
    chown "$owner" "$target" 2>/dev/null || true
  fi
  return 0
}

# Make a file the compositor has to read readable, and owned by the user when
# the installer runs as root. A config that the compositor cannot open shows
# up in its error overlay and takes the whole session with it.
ensure_readable_file() {
  local file="$1" user="${2:-}"
  [[ -f $file ]] || return 1

  chmod 644 "$file" 2>/dev/null || true

  if (( EUID == 0 )) && [[ -n $user && $user != "root" ]]; then
    chown "$user:$user" "$file" 2>/dev/null || true
  fi
  return 0
}
