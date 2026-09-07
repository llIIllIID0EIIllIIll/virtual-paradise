#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Wireless Display & Screen Cast (Win+K)
# ==============================================================================
#  Launches GNOME Network Displays for Miracast (Wi-Fi P2P) & Chromecast streaming.

if pgrep -x "gnome-network-displays" >/dev/null; then
  pkill -x "gnome-network-displays"
else
  if command -v gnome-network-displays &>/dev/null; then
    exec gnome-network-displays "$@"
  else
    if command -v notify-send &>/dev/null; then
      notify-send "Cast Screen" "gnome-network-displays is not installed." -u critical
    fi
    echo "gnome-network-displays is not installed." >&2
    exit 1
  fi
fi
