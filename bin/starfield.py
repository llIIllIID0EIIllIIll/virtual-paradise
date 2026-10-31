#!/usr/bin/env python3
"""Virtual☆Paradise — neon starfield screensaver.

A tiny terminal warp field: stars fly out of the centre, tinted cyan, sakura,
white, green and magenta. Ctrl+C quits. No dependencies beyond the standard
library.
"""
import random
import shutil
import sys
import time

PALETTE = [
    (0, 255, 221),
    (255, 183, 213),
    (255, 255, 255),
    (0, 255, 136),
    (255, 43, 214),
]

GLYPHS = [".", "+", "*"]


def hide_cursor():
    sys.stdout.write("\033[?25l")
    sys.stdout.flush()


def show_cursor():
    sys.stdout.write("\033[?25h")
    sys.stdout.flush()


def main():
    try:
        width, height = shutil.get_terminal_size((120, 40))
    except Exception:
        width, height = 120, 40
    width = max(20, width)
    height = max(10, height)

    cx = width / 2.0
    cy = height / 2.0
    stars = []
    for _ in range(max(40, (width * height) // 70)):
        stars.append({
            "x": random.uniform(-1.0, 1.0),
            "y": random.uniform(-0.7, 0.7),
            "z": random.uniform(0.05, 1.0),
            "color": random.choice(PALETTE),
        })

    hide_cursor()
    sys.stdout.write("\033[2J")
    try:
        while True:
            grid = [[" "] * width for _ in range(height)]
            colors = [[None] * width for _ in range(height)]
            for star in stars:
                star["z"] -= 0.012
                if star["z"] <= 0.05:
                    star["x"] = random.uniform(-1.0, 1.0)
                    star["y"] = random.uniform(-0.7, 0.7)
                    star["z"] = 1.0
                    star["color"] = random.choice(PALETTE)
                px = int(cx + star["x"] / star["z"] * cx * 0.9)
                py = int(cy + star["y"] / star["z"] * cy * 0.9)
                if not (0 <= px < width and 0 <= py < height):
                    continue
                glyph = GLYPHS[0] if star["z"] > 0.7 else (
                    GLYPHS[1] if star["z"] > 0.3 else GLYPHS[2])
                grid[py][px] = glyph
                colors[py][px] = star["color"]

            out = ["\033[H"]
            for row in range(height):
                line = []
                last = None
                for col in range(width):
                    color = colors[row][col]
                    if color != last:
                        if color is None:
                            line.append("\033[0m")
                        else:
                            line.append("\033[38;2;%d;%d;%dm" % color)
                        last = color
                    line.append(grid[row][col])
                out.append("".join(line))
                out.append("\033[0m")
            sys.stdout.write("\n".join(out))
            sys.stdout.flush()
            time.sleep(1.0 / 30.0)
    except KeyboardInterrupt:
        pass
    finally:
        show_cursor()
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
