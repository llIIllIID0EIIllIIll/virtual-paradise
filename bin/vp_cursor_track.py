#!/usr/bin/env python3
"""Serve the Hyprland cursor position on `$XDG_RUNTIME_DIR/vp-cursor.sock`.

Two overlays need the pointer at cursor rate: the pointer glow and the hex
spotlight. Each used to run its own copy of this poller (a Python process
each); the socket makes exactly one of them the server - the second copy
finds the socket taken and exits at once - and both plugins read the
broadcast, so the session pays for one process instead of two.

Clients get the current position as soon as they connect, so an overlay that
loads while the pointer is still is not left waiting for the next move.
"""
import os
import socket
import sys
import time

SOCKET_NAME = "vp-cursor.sock"


def hypr_socket():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not signature:
        return ""
    return os.path.join(runtime, "hypr", signature, ".socket.sock")


def cursor_pos(path):
    """One command-socket round trip; no process is spawned."""
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(0.4)
    try:
        conn.connect(path)
        conn.sendall(b"cursorpos")
        return conn.recv(64).decode("utf-8", "replace").strip()
    finally:
        conn.close()


def main():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    hypr = hypr_socket()
    if not hypr:
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
                while True:
                    conn, _ = server.accept()
                    conn.setblocking(False)
                    clients.append(conn)
                    if last:
                        try:
                            conn.sendall((last + "\n").encode())
                        except OSError:
                            clients.remove(conn)
                            conn.close()
            except BlockingIOError:
                pass
            try:
                pos = cursor_pos(hypr)
            except Exception:
                pos = ""
            if "," in pos and pos != last:
                last = pos
                line = (pos + "\n").encode()
                for conn in list(clients):
                    try:
                        conn.sendall(line)
                    except OSError:
                        clients.remove(conn)
                        try:
                            conn.close()
                        except OSError:
                            pass
            time.sleep(0.033)
    finally:
        server.close()
        try:
            os.unlink(sock_path)
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
