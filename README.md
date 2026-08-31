# 🌸 Virtual☆Paradise — Cyberpunk Neon Rice & Theme for Omarchy 🌸

[![Omarchy](https://img.shields.io/badge/Omarchy-4.0+-00f5d4.svg?style=for-the-badge&logo=archlinux)](https://omarchy.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00ff88.svg?style=for-the-badge&logo=wayland)](https://hyprland.org/)
[![Theme](https://img.shields.io/badge/Theme-Neon%20Pastel%20Cyberpunk-ffb7d5.svg?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/License-MIT-ff0055.svg?style=for-the-badge)](LICENSE)

**Virtual☆Paradise** is a full-topping, high-contrast **Neon Pastel Cyberpunk** Rice and Universal Theme for [Omarchy Linux](https://omarchy.org/) (Arch Linux + Hyprland).

Featuring an electric gradient flow:
$$\mathbf{\text{Miku Cyan (\#00f5d4)}}\ \longrightarrow\ \mathbf{\text{Hacker Green (\#00ff88)}}\ \longrightarrow\ \mathbf{\text{Sakura Pink (\#ffb7d5)}}$$
layered against a deep void black background (`#07080d`) with an emergency **Blazing Neon Warning Red (`#ff0055`)** diagnostic alert system.

---

## 📸 Preview

![Virtual Paradise Preview](preview.png)

---

## 🎨 Color Palette & Architecture

| Role | Color Hex | Sample Preview | Description |
| :--- | :--- | :--- | :--- |
| **Accent Primary** | `#00f5d4` | ![#00f5d4](https://placehold.co/15x15/00f5d4/00f5d4.png) `Miku Cyan` | Main focal accent, active badges, focus indicators |
| **Accent Secondary** | `#00ff88` | ![#00ff88](https://placehold.co/15x15/00ff88/00ff88.png) `Hacker Green` | Occupied workspaces, playback active, live stream |
| **Accent Highlight** | `#ffb7d5` | ![#ffb7d5](https://placehold.co/15x15/ffb7d5/ffb7d5.png) `Sakura Pink` | Gradient third stop, CPU thermal normal pill |
| **Neon Warning Red** | `#ff0055` | ![#ff0055](https://placehold.co/15x15/ff0055/ff0055.png) `Warning Red` | Hardware error, low battery ($\le 15\%$), Wi-Fi alert, command error |
| **Background Void** | `#07080d` | ![#07080d](https://placehold.co/15x15/07080d/07080d.png) `Void Black` | 94% Acrylic frosted glass background |
| **Muted Slate** | `#7091a4` | ![#7091a4](https://placehold.co/15x15/7091a4/7091a4.png) `Slate Blue` | Inactive text, unselected borders, standby states |

---

## 🚀 One-Line Installation

### Option 1: Full Rice Automated Setup (Recommended)
Clones the theme, custom status bar plugins, Hyprland configuration, helper scripts, and audio visualizer in one step:

```bash
git clone https://github.com/OldJobobo/virtual-paradise.git /tmp/virtual-paradise && bash /tmp/virtual-paradise/install.sh && rm -rf /tmp/virtual-paradise
```

### Option 2: Standard Theme Installation via Omarchy CLI
Installs just the theme color scheme and backgrounds:

```bash
omarchy theme install https://github.com/OldJobobo/virtual-paradise.git
```

---

## ✨ Key Features & Enhancements

### 1. 🪟 Full-Topping Hyprland Look'n'Feel
- **Tri-Stop Animated Border Gradient:** 45-degree angle transitioning between Cyan $\to$ Green $\to$ Pink.
- **Per-Window Isolated Error Warning:** When a command fails in terminal, that specific window's border turns **Thick Neon Red (`#ff0055`)** while other windows stay Cyan. On success, it smoothly morphs back through a multi-tier spectrum gradient!
- **Silky Smooth Layer Animations:** `slidefade 25%` on popups and menus without full-screen dimming/blurring.

### 2. 📊 Modern Status Bar & Island Dock (Quickshell)
- **Real-Time PipeWire Audio Visualizer (Cava):** 6-bar live frequency spectrum right on the center island.
- **Universal CPU Thermal Detection:** Auto-scans Intel Core/Ultra (`x86_pkg_temp`, `coretemp`) and AMD Ryzen (`k10temp`, `zenpower`) without hardcoded sensor numbers.
- **Smart Alert States:** Wi-Fi disconnected alert `󰤫` with glowing red halo; Battery critical `󰂃` alert; RAM usage breakdown notification on right click.
- **Unified Minimalist Workspaces:** Slim dock with `★ Active`, `● Occupied`, and `· Empty` badges.

### 3. ⌨️ Ergonomic Hotkeys & Controls

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `SUPER + Q` | **Rice Layout** | Sequentially launches Fastfetch, Btop, Cava & 3-Color Matrix |
| `SUPER + E` | **File Manager** | Auto-detects default file manager (`xdg-open`) |
| `SUPER + B` | **Web Browser** | Launches default browser |
| `SUPER + C` | **Cooler Boost** | Toggles maximum fan cooling |
| `SUPER + N` | **Next Wallpaper** | Cycles through cyberpunk wallpaper gallery |
| `SUPER + SHIFT + T` | **Theme Switcher** | Opens interactive theme picker |
| `SUPER + SHIFT + C` | **Color Picker** | Magnifier + auto hex copy |
| `SUPER + \` | **Matrix Screensaver**| Cyberpunk Matrix animation in terminal |

---

## 🛠️ Multi-Hardware & Portable Compatibility
- **100% Username Agnostic:** Zero hardcoded paths; respects `$HOME` and `$XDG_CONFIG_HOME`.
- **Universal Monitors:** Auto-detects native refresh rates (60Hz, 144Hz, 240Hz, 4K, Ultrawide, OLED).
- **Default Application Detection:** Fully compliant with `xdg-terminal-exec`, `xdg-mime`, and standard FreeDesktop protocols.

---

## ⚖️ License
Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.
Crafted with 🌸 for the **Omarchy** Community.
