#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — Auto-Detecting 5-Terminal Rice Layout Launcher
# ==============================================================================
#  Layout Tree (preview.png):
#    Left 50%:                  fastfetch-agent (Master Left panel)
#    Top Right:                 btop (System monitor)
#    Bottom-Right-Left:         momoisay (Cute animated Momoi mascot)
#    Bottom-Right-Right-Top:    cava (Audio visualizer)
#    Bottom-Right-Right-Bottom: unimatrix / virtual_matrix (Cyber matrix)
# ==============================================================================

# 1. Auto-detect User Shell (zsh / bash / sh)
DETECT_SHELL() {
  local db_shell
  db_shell="$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7)"
  if [[ -n "$db_shell" ]] && [[ "$db_shell" =~ zsh$ ]] && command -v "$db_shell" &>/dev/null; then
    echo "$db_shell"
    return
  fi

  if command -v zsh &>/dev/null; then
    command -v zsh
    return
  fi

  if [[ -n "$db_shell" ]] && command -v "$db_shell" &>/dev/null; then
    echo "$db_shell"
    return
  fi

  if [[ -n "$SHELL" ]] && command -v "$SHELL" &>/dev/null; then
    echo "$SHELL"
    return
  fi

  if command -v bash &>/dev/null; then
    command -v bash
    return
  fi
  echo "/bin/sh"
}

USER_SHELL="$(DETECT_SHELL)"
export SHELL="$USER_SHELL"

# 2. Auto-detect Terminal Emulator (Ghostty, Foot, Alacritty, Kitty, etc.)
DETECT_TERMINAL() {
  if [[ -n "$TERMINAL" ]] && [[ "$TERMINAL" != *"xdg-terminal-exec"* ]] && command -v "$TERMINAL" &>/dev/null; then
    echo "$TERMINAL"
    return
  fi
  for term in ghostty foot alacritty kitty wezterm xterm; do
    if command -v "$term" &>/dev/null; then
      echo "$term"
      return
    fi
  done
  echo "xdg-terminal-exec"
}

TERM_BIN="$(DETECT_TERMINAL)"

# 3. Find First Empty Workspace
get_first_empty_ws() {
  local occupied
  occupied=($(hyprctl workspaces -j 2>/dev/null | jq -r '.[].id' 2>/dev/null | sort -n))
  for ((id=1; id<=20; id++)); do
    local found=0
    for occ in "${occupied[@]}"; do
      if [[ "$occ" -eq "$id" ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      echo "$id"
      return
    fi
  done
  echo "5"
}

# 4. Check if Rice is Already Running
rice_clients=$(hyprctl clients -j 2>/dev/null | jq '[.[] | select((.title | test("fastfetch-agent|rice-btop|rice-momoi|rice-cava|rice-matrix")) or (.initialTitle | test("fastfetch-agent|rice-btop|rice-momoi|rice-cava|rice-matrix")))]')
rice_count=$(echo "$rice_clients" | jq 'length' 2>/dev/null || echo 0)

if [[ "$rice_count" -ge 3 ]]; then
  active_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id')
  rice_ws=$(echo "$rice_clients" | jq -r '.[0].workspace.id')

  if [[ "$active_ws" == "$rice_ws" ]]; then
    # Toggle off when pressed on the rice workspace
    pkill -f "fastfetch-agent|rice-btop|rice-momoi|rice-cava|virtual_matrix" 2>/dev/null || true
    exit 0
  else
    # Jump to rice workspace and focus master terminal
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$rice_ws\" })" 2>/dev/null || true
    hyprctl dispatch "hl.dsp.focus({ window = \"title:fastfetch-agent\" })" 2>/dev/null || true
    exit 0
  fi
fi

# 5. Switch to a Clean Workspace if Current Workspace has Windows
active_windows=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.windows' 2>/dev/null || echo 0)
if [[ "$active_windows" -gt 0 ]]; then
  TARGET_WS=$(get_first_empty_ws)
  hyprctl dispatch "hl.dsp.focus({ workspace = \"$TARGET_WS\" })" 2>/dev/null || true
  sleep 0.05
else
  TARGET_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo 1)
fi

# 6. Terminal Launcher Dispatcher with Title Support (setsid detached)
LAUNCH_RICE_TERM() {
  local title="$1"
  shift
  case "$TERM_BIN" in
    ghostty)
      setsid -f ghostty --title="$title" -e "$@" >/dev/null 2>&1
      ;;
    foot)
      setsid -f foot --title="$title" "$@" >/dev/null 2>&1
      ;;
    alacritty)
      setsid -f alacritty --title "$title" -e "$@" >/dev/null 2>&1
      ;;
    kitty)
      setsid -f kitty --title="$title" "$@" >/dev/null 2>&1
      ;;
    wezterm)
      setsid -f wezterm start --title "$title" -- "$@" >/dev/null 2>&1
      ;;
    *)
      if command -v xdg-terminal-exec &>/dev/null; then
        setsid -f xdg-terminal-exec -- "$@" >/dev/null 2>&1
      else
        setsid -f "$TERM_BIN" "$@" >/dev/null 2>&1
      fi
      ;;
  esac
}

# 7. Ultra-Fast Event-Driven Sequential Launcher with Auto-Focus
# To preserve Hyprland dwindle's exact tree layout, each pane splits against
# the currently focused window. When a user moves their mouse, focus would shift
# and corrupt the layout.
# By immediately auto-focusing each newly mapped window via Hyprland's IPC socket2,
# windows split in the exact deterministic order instantly without requiring
# sleep delays or being affected by mouse movement.

HYPR_SOCK2="/run/user/${UID:-1000}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

# Launch and immediately wait for window to map, auto-focusing it
LAUNCH_AND_FOCUS() {
  local target_title="$1"
  shift

  # Connect to socket2 before launching so we never miss the event
  python3 -c "
import socket, subprocess, sys, time, os

title = sys.argv[1]
cmd = sys.argv[2:]
sock_path = '$HYPR_SOCK2'

s = None
if os.path.exists(sock_path):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        s.setblocking(False)
        try:
            s.recv(8192)
        except BlockingIOError:
            pass
    except Exception:
        s = None

# Spawn detached terminal
subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

# Wait for openwindow / windowtitle event
t0 = time.time()
found_addr = None
buf = ''
while s is not None and time.time() - t0 < 0.6:
    try:
        data = s.recv(4096).decode('utf-8', errors='ignore')
        if not data:
            break
        buf += data
        lines = buf.split('\n')
        buf = lines[-1]
        for line in lines[:-1]:
            if line.startswith('openwindow>>') or line.startswith('windowtitlev2>>'):
                parts = line.split('>>')[1].split(',')
                # openwindow: address,workspace,class,title
                # windowtitlev2: address,title
                if any(title in p for p in parts[1:]):
                    found_addr = parts[0]
                    break
        if found_addr:
            break
    except BlockingIOError:
        time.sleep(0.005)

if s:
    s.close()

if found_addr:
    subprocess.run(['hyprctl', 'eval', f'hl.dsp.focus({{ window = \"address:0x{found_addr}\" }})'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
else:
    time.sleep(0.06)
    subprocess.run(['hyprctl', 'eval', f'hl.dsp.focus({{ window = \"title:{title}\" }})'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
" "$target_title" "$@"
}

# Window 1: Fastfetch + Paradise Banner (Master Left Panel)
# VIRTUAL_PARADISE_NO_BANNER=1 ensures the interactive shell inside doesn't repeat the banner
MASTER_CMD="trap '' INT; printf '\033]0;fastfetch-agent\007'; fastfetch; \"$HOME/.local/bin/paradise_banner.py\" || true; exec $USER_SHELL -l"
case "$TERM_BIN" in
  ghostty)
    LAUNCH_AND_FOCUS "fastfetch-agent" env VIRTUAL_PARADISE_NO_BANNER=1 ghostty --title="fastfetch-agent" -e "$USER_SHELL" -i -c "$MASTER_CMD"
    ;;
  foot)
    LAUNCH_AND_FOCUS "fastfetch-agent" env VIRTUAL_PARADISE_NO_BANNER=1 foot --title="fastfetch-agent" "$USER_SHELL" -i -c "$MASTER_CMD"
    ;;
  alacritty)
    LAUNCH_AND_FOCUS "fastfetch-agent" env VIRTUAL_PARADISE_NO_BANNER=1 alacritty --title "fastfetch-agent" -e "$USER_SHELL" -i -c "$MASTER_CMD"
    ;;
  kitty)
    LAUNCH_AND_FOCUS "fastfetch-agent" env VIRTUAL_PARADISE_NO_BANNER=1 kitty --title="fastfetch-agent" "$USER_SHELL" -i -c "$MASTER_CMD"
    ;;
  *)
    LAUNCH_AND_FOCUS "fastfetch-agent" env VIRTUAL_PARADISE_NO_BANNER=1 "$TERM_BIN" -e "$USER_SHELL" -i -c "$MASTER_CMD"
    ;;
esac

# Window 2: btop (Top Right)
case "$TERM_BIN" in
  ghostty)   LAUNCH_AND_FOCUS "rice-btop" ghostty --title="rice-btop" -e btop ;;
  foot)      LAUNCH_AND_FOCUS "rice-btop" foot --title="rice-btop" btop ;;
  alacritty) LAUNCH_AND_FOCUS "rice-btop" alacritty --title "rice-btop" -e btop ;;
  kitty)     LAUNCH_AND_FOCUS "rice-btop" kitty --title="rice-btop" btop ;;
  *)         LAUNCH_AND_FOCUS "rice-btop" "$TERM_BIN" -e btop ;;
esac

# Window 3: momoisay (Bottom Right Left - Cute Mascot)
case "$TERM_BIN" in
  ghostty)   LAUNCH_AND_FOCUS "rice-momoi" ghostty --title="rice-momoi" -e "$HOME/.local/bin/momoisay" -f ;;
  foot)      LAUNCH_AND_FOCUS "rice-momoi" foot --title="rice-momoi" "$HOME/.local/bin/momoisay" -f ;;
  alacritty) LAUNCH_AND_FOCUS "rice-momoi" alacritty --title "rice-momoi" -e "$HOME/.local/bin/momoisay" -f ;;
  kitty)     LAUNCH_AND_FOCUS "rice-momoi" kitty --title="rice-momoi" "$HOME/.local/bin/momoisay" -f ;;
  *)         LAUNCH_AND_FOCUS "rice-momoi" "$TERM_BIN" -e "$HOME/.local/bin/momoisay" -f ;;
esac

# Window 4: cava (Bottom Right Right Top - Audio Visualizer)
case "$TERM_BIN" in
  ghostty)   LAUNCH_AND_FOCUS "rice-cava" ghostty --title="rice-cava" -e cava ;;
  foot)      LAUNCH_AND_FOCUS "rice-cava" foot --title="rice-cava" cava ;;
  alacritty) LAUNCH_AND_FOCUS "rice-cava" alacritty --title "rice-cava" -e cava ;;
  kitty)     LAUNCH_AND_FOCUS "rice-cava" kitty --title="rice-cava" cava ;;
  *)         LAUNCH_AND_FOCUS "rice-cava" "$TERM_BIN" -e cava ;;
esac

# Window 5: unimatrix / virtual_matrix (Bottom Right Right Bottom - Tri-color Cyber Matrix)
case "$TERM_BIN" in
  ghostty)   LAUNCH_AND_FOCUS "rice-matrix" ghostty --title="rice-matrix" -e "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧" ;;
  foot)      LAUNCH_AND_FOCUS "rice-matrix" foot --title="rice-matrix" "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧" ;;
  alacritty) LAUNCH_AND_FOCUS "rice-matrix" alacritty --title "rice-matrix" -e "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧" ;;
  kitty)     LAUNCH_AND_FOCUS "rice-matrix" kitty --title="rice-matrix" "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧" ;;
  *)         LAUNCH_AND_FOCUS "rice-matrix" "$TERM_BIN" -e "$HOME/.local/bin/virtual_matrix" -a -f -s 50 -l k -u "☆★✦✧" ;;
esac

# 8. Return Focus to Master Terminal
hyprctl eval 'hl.dsp.focus({ window = "title:fastfetch-agent" })' >/dev/null 2>&1 || true
