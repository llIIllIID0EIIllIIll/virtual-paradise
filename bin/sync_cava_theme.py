#!/usr/bin/env python3
import os, sys, re

def main():
    cava_path = os.path.expanduser("~/.config/cava/config")
    if not os.path.exists(cava_path):
        return

    theme_name = sys.argv[1] if len(sys.argv) > 1 else ""
    colors_file = os.path.expanduser("~/.local/state/omarchy/current/theme/colors.toml")

    user_theme_colors = os.path.expanduser(f"~/.config/omarchy/themes/{theme_name}/colors.toml")
    system_theme_colors = f"/usr/share/omarchy/themes/{theme_name}/colors.toml"

    if theme_name == "virtual-paradise":
        c1 = c2 = c3 = "#00f5d4"
        c4 = c5 = "#00ff88"
        c6 = c7 = c8 = "#ffb7d5"
    else:
        target_colors = colors_file
        if os.path.exists(user_theme_colors):
            target_colors = user_theme_colors
        elif os.path.exists(system_theme_colors):
            target_colors = system_theme_colors

        colors = {}
        if os.path.exists(target_colors):
            with open(target_colors, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    m = re.match(r'^\s*([a-zA-Z0-9_]+)\s*=\s*"([^"]+)"', line)
                    if m:
                        colors[m.group(1)] = m.group(2)

        accent = colors.get("accent", "#89b4fa")
        green = colors.get("green", colors.get("cyan", accent))
        magenta = colors.get("magenta", colors.get("yellow", accent))
        c1 = c2 = c3 = accent
        c4 = c5 = green
        c6 = c7 = c8 = magenta

    with open(cava_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    palette = {
        "gradient_color_1": c1,
        "gradient_color_2": c2,
        "gradient_color_3": c3,
        "gradient_color_4": c4,
        "gradient_color_5": c5,
        "gradient_color_6": c6,
        "gradient_color_7": c7,
        "gradient_color_8": c8,
    }

    new_lines = []
    for line in lines:
        matched = False
        for k, v in palette.items():
            if line.startswith(f"{k} =") or line.startswith(f"{k}="):
                new_lines.append(f"{k} = '{v}'\n")
                matched = True
                break
        if not matched:
            new_lines.append(line)

    with open(cava_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)

    os.system("pkill -USR1 cava 2>/dev/null || pkill -USR2 cava 2>/dev/null || true")

if __name__ == "__main__":
    main()
