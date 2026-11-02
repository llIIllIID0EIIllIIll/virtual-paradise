#!/usr/bin/env python3
"""Serve the focused window's class and geometry on `$XDG_RUNTIME_DIR/vp-window.sock`.

Two overlays need to know when a terminal is focused and where it sits: the
hex spotlight (which paints the pool over that window) and the pointer glow
(which should only appear over a terminal). The server subscribes to
Hyprland's event socket and only asks for the window geometry when something
that can change it happens - focus, move, resize, open, close, workspace,
fullscreen, floating mode. The second plugin to start it finds the socket
taken and exits, so the session pays for one process instead of two.

Each client is answered with the current window as soon as it connects.
"""
import json
import os
import select
import socket
import sys
import time

SOCKET_NAME = "vp-window.sock"

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


def hypr_paths():
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


def window_line(cmd_path):
    raw = query_active(cmd_path)
    if not raw:
        return ""
    try:
        win = json.loads(raw)
    except ValueError:
        return ""
    cls = str(win.get("class", ""))
    at = win.get("at") or [0, 0]
    size = win.get("size") or [0, 0]
    return "%s|%d,%d %dx%d" % (cls, int(at[0]), int(at[1]),
                               int(size[0]), int(size[1]))


def main():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    cmd_path, evt_path = hypr_paths()
    if not cmd_path or not evt_path:
        return 1
    sock_path = os.path.join(runtime, SOCKET_NAME)

    # One server per session: if someone is already serving, this copy exits
    # and simply reads the broadcast.
    probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    probe.settimeout(0.2)
    try:
        probe.connect(sock_path)
        probe.close()
        return 0
    except OSError:
        probe.close()
    try:
        os.unlink(sock_path)
    except FileNotFoundError:
        pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(sock_path)
    os.chmod(sock_path, 0o600)
    server.listen(8)
    server.setblocking(False)

    clients = []
    last = ""
    try:
        while True:
            try:
                events = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                events.connect(evt_path)
            except OSError:
                time.sleep(0.2)
                continue
            # Re-state the world after every (re)connect so a Hyprland
            # restart cannot leave a stale window on screen.
            line = window_line(cmd_path)
            if line:
                last = line
            buf = b""
            while True:
                try:
                    readable, _, _ = select.select([events, server], [], [], 0.5)
                except OSError:
                    break
                if server in readable:
                    try:
                        while True:
                            conn, _ = server.accept()
                            conn.setblocking(False)
                            clients.append(conn)
                            if last:
                                conn.sendall((last + "\n").encode())
                    except OSError:
                        pass
                if events not in readable:
                    continue
                try:
                    data = events.recv(4096)
                except OSError:
                    break
                if not data:
                    break
                buf += data
                while b"\n" in buf:
                    raw, buf = buf.split(b"\n", 1)
                    name = raw.split(b">>", 1)[0].decode("utf-8", "replace")
                    if name not in WATCHED:
                        continue
                    line = window_line(cmd_path)
                    if not line or line == last:
                        continue
                    last = line
                    for conn in list(clients):
                        try:
                            conn.sendall((line + "\n").encode())
                        except OSError:
                            clients.remove(conn)
                            try:
                                conn.close()
                            except OSError:
                                pass
            events.close()
            time.sleep(0.2)
    finally:
        server.close()
        try:
            os.unlink(sock_path)
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
