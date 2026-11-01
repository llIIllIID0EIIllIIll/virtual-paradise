#!/usr/bin/env python3
"""Stream the focused window's class and geometry as `class|x,y wxh` lines.

The spotlight must react the moment focus lands on a terminal. Polling
`hyprctl` cost a process per poll and made the glow appear up to half a second
late, so this helper subscribes to Hyprland's event socket instead and only
asks for the window geometry when something that can change it happens:
focus, move, resize, open, close, workspace, fullscreen, floating mode.
"""
import json
import os
import socket
import sys
import time

# Events after which the active window or its geometry can differ.
WATCHED = {
    "activewindow",
    "activewindowv2",
    "openwindow",
    "closewindow",
    "movewindow",
    "movewindowv2",
    "resizewindow",
    "resizewindowv2",
    "workspace",
    "focusedmon",
    "fullscreen",
    "changefloatingmode",
}


def socket_paths():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not signature:
        return "", ""
    base = os.path.join(runtime, "hypr", signature)
    return os.path.join(base, ".socket.sock"), os.path.join(base, ".socket2.sock")


def query_active(cmd_path):
    """One command-socket round trip; no process is spawned."""
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(0.5)
    try:
        conn.connect(cmd_path)
        conn.sendall(b"j/activewindow")
        chunks = []
        while True:
            try:
                data = conn.recv(65536)
            except socket.timeout:
                break
            if not data:
                break
            chunks.append(data)
        return b"".join(chunks).decode("utf-8", "replace")
    finally:
        conn.close()


def emit(cmd_path, state):
    raw = query_active(cmd_path)
    if not raw:
        return
    try:
        win = json.loads(raw)
    except ValueError:
        return
    cls = str(win.get("class", ""))
    at = win.get("at") or [0, 0]
    size = win.get("size") or [0, 0]
    line = "%s|%d,%d %dx%d\n" % (cls, int(at[0]), int(at[1]), int(size[0]), int(size[1]))
    # Focus fires both `activewindow` and `activewindowv2`; skip the echo.
    if line == state[0]:
        return
    state[0] = line
    sys.stdout.write(line)
    sys.stdout.flush()


def main():
    cmd_path, evt_path = socket_paths()
    if not cmd_path or not evt_path:
        return 1
    state = [""]
    while True:
        try:
            conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            conn.connect(evt_path)
            # Re-state the world after every (re)connect so a Hyprland
            # restart cannot leave a stale window on screen.
            try:
                emit(cmd_path, state)
            except Exception:
                pass
            buf = b""
            while True:
                data = conn.recv(4096)
                if not data:
                    break
                buf += data
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    name = line.split(b">>", 1)[0].decode("utf-8", "replace")
                    if name in WATCHED:
                        try:
                            emit(cmd_path, state)
                        except Exception:
                            pass
        except Exception:
            pass
        time.sleep(0.2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
