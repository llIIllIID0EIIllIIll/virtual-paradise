#!/usr/bin/env python3
"""Print the Hyprland cursor position as `x, y` lines at ~30Hz.

Used by the cursor-glow overlay plugin. Hyprland's command socket closes after
one command, so each poll opens a fresh connection; spawning `hyprctl` at this
rate would cost a process per frame instead.
"""
import os
import socket
import sys
import time


def socket_path():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not signature:
        return ""
    return os.path.join(runtime, "hypr", signature, ".socket.sock")


def cursor_pos(path):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(0.4)
    try:
        conn.connect(path)
        conn.sendall(b"cursorpos")
        return conn.recv(64).decode("utf-8", "replace").strip()
    finally:
        conn.close()


def main():
    path = socket_path()
    if not path:
        return 1
    while True:
        try:
            pos = cursor_pos(path)
            if pos and "," in pos:
                sys.stdout.write(pos + "\n")
                sys.stdout.flush()
        except Exception:
            pass
        time.sleep(0.033)
    return 0


if __name__ == "__main__":
    sys.exit(main())
