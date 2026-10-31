#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — UI sound player
# ==============================================================================
#  Usage: vp-sound.sh login|lock|unlock|error|notify
#
#  The theme ships five short synth blips; this wrapper picks the best
#  available player and keeps a single opt-out flag. Sounds are best-effort:
#  a missing player or file is never an error.
#
#  Disable: touch ~/.local/state/virtual-paradise/sound-off
#  Volume:  VP_SOUND_VOLUME=0.3 (paplay only, 0..1)
# ==============================================================================

set -uo pipefail

event="${1:-}"
[[ -n $event ]] || exit 0

[[ -f "$HOME/.local/state/virtual-paradise/sound-off" ]] && exit 0

file="$HOME/.local/share/sounds/virtual-paradise/$event.oga"
[[ -f $file ]] || exit 0

if command -v paplay >/dev/null 2>&1; then
  volume="${VP_SOUND_VOLUME:-0.6}"
  vol="$(awk -v v="$volume" 'BEGIN { printf "%d", v * 65536 }')"
  exec paplay --volume="$vol" "$file" >/dev/null 2>&1
elif command -v pw-play >/dev/null 2>&1; then
  exec pw-play "$file" >/dev/null 2>&1
elif command -v canberra-gtk-play >/dev/null 2>&1; then
  exec canberra-gtk-play -f "$file" >/dev/null 2>&1
fi
exit 0
