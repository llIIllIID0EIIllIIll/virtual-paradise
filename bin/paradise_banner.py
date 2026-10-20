#!/usr/bin/env python3
"""
Virtual☆Paradise — Standalone Cyberpunk ASCII Banner Display
Renders 45-degree diagonal RGB gradient (Cyan -> Green -> Sakura Pink)
adapted to the active Omarchy theme.
"""

import os
import re
import sys
from typing import Tuple

def hex_to_rgb(hex_str: str) -> Tuple[int, int, int]:
    hex_str = hex_str.lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join([c * 2 for c in hex_str])
    r = int(hex_str[0:2], 16)
    g = int(hex_str[2:4], 16)
    b = int(hex_str[4:6], 16)
    return (r, g, b)

def get_theme_colors():
    theme_file = os.path.expanduser("~/.local/state/omarchy/current/theme.name")
    active = ""
    if os.path.exists(theme_file):
        try:
            with open(theme_file, "r") as f:
                active = f.read().strip()
        except Exception:
            pass

    if active == "virtual-paradise" or not active:
        return (0, 245, 212), (0, 255, 136), (255, 183, 213)

    colors_file = os.path.expanduser("~/.local/state/omarchy/current/theme/colors.toml")
    colors = {}
    if os.path.exists(colors_file):
        try:
            with open(colors_file, "r") as f:
                for line in f:
                    m = re.match(r'^\s*([a-zA-Z0-9_]+)\s*=\s*"([^"]+)"', line)
                    if m:
                        colors[m.group(1)] = m.group(2)
        except Exception:
            pass

    cyan = colors.get("accent", "#89b4fa")
    green = colors.get("green", colors.get("cyan", cyan))
    pink = colors.get("magenta", colors.get("yellow", cyan))
    return hex_to_rgb(cyan), hex_to_rgb(green), hex_to_rgb(pink)

def get_banner_art() -> str:
    raw_lines = [
        "██╗   ██╗██╗██████╗ ████████╗██╗   ██╗ █████╗ ██╗         ██████╗  █████╗ ██████╗  █████╗ ██████╗ ██╗███████╗███████╗",
        "██║   ██║██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██║         ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║██╔════╝██╔════╝",
        "██║   ██║██║██████╔╝   ██║   ██║   ██║███████║██║         ██████╔╝███████║██████╔╝███████║██║  ██║██║███████╗█████╗  ",
        "╚██╗ ██╔╝██║██╔══██╗   ██║   ██║   ██║██╔══██║██║         ██╔═══╝ ██╔══██║██╔══██╗██╔══██║██║  ██║██║╚════██║██╔══╝  ",
        " ╚████╔╝ ██║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗    ██║     ██║  ██║██║  ██║██║  ██║██████╔╝██║███████║███████╗",
        "  ╚═══╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚══════╝╚══════╝"
    ]

    c_cyan, c_green, c_pink = get_theme_colors()

    h = len(raw_lines)
    w = max(len(l) for l in raw_lines)
    alpha = 2.0

    def lerp(c1, c2, p):
        p = max(0.0, min(1.0, p))
        return (
            int(c1[0] + (c2[0] - c1[0]) * p),
            int(c1[1] + (c2[1] - c1[1]) * p),
            int(c1[2] + (c2[2] - c1[2]) * p)
        )

    formatted_banner = []
    for r, line in enumerate(raw_lines):
        out = []
        for c, char in enumerate(line):
            if char == ' ':
                out.append(' ')
                continue
            t = (c + alpha * r) / (w + alpha * (h - 1))
            t = max(0.0, min(1.0, t))

            # True visual 40% Cyan / 20% Green / 40% Sakura Pink
            if t < 0.28:
                red, green, blue = c_cyan
            elif t < 0.38:
                red, green, blue = lerp(c_cyan, c_green, (t - 0.28) / 0.10)
            elif t < 0.62:
                red, green, blue = c_green
            elif t < 0.72:
                red, green, blue = lerp(c_green, c_pink, (t - 0.62) / 0.10)
            else:
                red, green, blue = c_pink

            out.append(f"\033[38;2;{red};{green};{blue}m{char}\033[0m")
        formatted_banner.append("  " + "".join(out))
    return "\n".join(formatted_banner)

def main():
    # The banner is static art whose colors come from the active theme, so it
    # only has to be rendered once per theme. Rendering it took ~30 ms of
    # every interactive shell; the cached copy is printed in ~2 ms.
    c_cyan, c_green, c_pink = get_theme_colors()
    cache_dir = os.path.expanduser("~/.cache/virtual-paradise")
    cache_file = os.path.join(cache_dir, "banner.txt")
    key = f"{c_cyan}:{c_green}:{c_pink}"

    try:
        os.makedirs(cache_dir, exist_ok=True)
        with open(cache_file, "r") as fh:
            cached = fh.read()
        if cached.startswith(f"# {key}"):
            sys.stdout.write(cached.split("\n", 1)[1])
            return
    except OSError:
        pass

    art = get_banner_art()
    output = f"\n{art}\n"

    try:
        with open(cache_file, "w") as fh:
            fh.write(f"# {key}\n{output}")
    except OSError:
        pass

    print(output, end="")

if __name__ == "__main__":
    main()
