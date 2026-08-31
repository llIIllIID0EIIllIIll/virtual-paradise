# 🌸 Virtual☆Paradise — Cyberpunk Neon Rice & Universal Theme for Omarchy 🌸

[![Omarchy](https://img.shields.io/badge/Omarchy-4.0+-00f5d4.svg?style=for-the-badge&logo=archlinux)](https://omarchy.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00ff88.svg?style=for-the-badge&logo=wayland)](https://hyprland.org/)
[![Theme](https://img.shields.io/badge/Theme-Neon%20Pastel%20Cyberpunk-ffb7d5.svg?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/License-MIT-ff0055.svg?style=for-the-badge)](LICENSE)

**Virtual☆Paradise** is a high-contrast, fully-topped **Neon Pastel Cyberpunk** Rice and Universal Theme for [Omarchy Linux](https://omarchy.org/) (Arch Linux + Hyprland).

Featuring a harmonious tripartite color gradient flow:
> **40% Miku Cyan (`#00f5d4`)** ➔ **20% Hacker Green (`#00ff88`)** ➔ **40% Sakura Pink (`#ffb7d5`)**

layered against a deep void black frosted acrylic glass background (`#07080d`), paired with an animated live video wallpaper engine, sequential 5-terminal high-speed rice layout, and custom Quickshell island widgets.

---

## 📸 Preview

![Virtual☆Paradise Desktop Preview](preview.png)

---

## 🎨 System-Wide Color Ratio & Palette

All theme components (Hyprland window borders, ambient shadows, Fastfetch logos, Btop system graphs, Cava audio visualizer, Unimatrix digital rain, and status bar modules) strictly adhere to the calibrated **40 / 20 / 40** neon gradient ratio:

| Role | Color Hex | Preview | Proportion | Component Mapping |
| :--- | :--- | :---: | :---: | :--- |
| **Miku Cyan** | `#00f5d4` | ![#00f5d4](https://placehold.co/15x15/00f5d4/00f5d4.png) | **40%** | Active window borders, Fastfetch top block, CPU monitors, Clock badges |
| **Hacker Green** | `#00ff88` | ![#00ff88](https://placehold.co/15x15/00ff88/00ff88.png) | **20%** | Center gradient bridge, OS details, Network transfer rates, Live audio |
| **Sakura Pink** | `#ffb7d5` | ![#ffb7d5](https://placehold.co/15x15/ffb7d5/ffb7d5.png) | **40%** | Bottom gradient block, Memory usage, Wi-Fi telemetry, Battery pill |
| **Warning Red** | `#ff0055` | ![#ff0055](https://placehold.co/15x15/ff0055/ff0055.png) | *Alert* | Isolated window error shake, low battery (≤15%), critical CPU temp |
| **Void Black** | `#07080d` | ![#07080d](https://placehold.co/15x15/07080d/07080d.png) | *Base* | 94% Acrylic frosted glass background with dynamic compositor blur |

---

## ✨ Key Features & Architectural Innovations

### 1. 🎬 Native Live Video Wallpaper Engine with Slanted Curtain Reveal
- **Hardware-Accelerated Playback:** Plays high-bitrate 60fps 1080p live wallpaper (`miku-horizontal-live.mp4`) via GPU acceleration with 0% idle CPU overhead.
- **Slanted 2-Sided Curtain Reveal Animation:** When toggling or switching between video and static wallpaper, a geometric slanted curtain opens outwards from center to both sides over 520ms (`Easing.InOutCubic`), seamlessly matching Omarchy's system wallpaper transitions.
- **Instant Fallback Protection:** If live video playback is stopped or unavailable, the system automatically falls back to crystal-clear 1080p static artwork (`miku-cyber-peace.png`) without black screens.

### 2. ⚡ High-Speed 5-Terminal Rice Layout (`SUPER + Q`)
Launches a complete 5-pane cyberpunk development workspace in microseconds via Wayland socket dispatch:
1. 🖥️ **`fastfetch`** — Master left panel with system information and 40/20/40 gradient logo.
2. 📊 **`btop`** — Top-right real-time CPU, GPU, memory, and process monitor.
3. 🌸 **`momoisay`** — Center-bottom animated Saiba Momoi ASCII mascot in glowing Miku Cyan.
4. 🎵 **`cava`** — Bottom-right 8-band audio spectrum visualizer.
5. 👾 **`unimatrix` (`virtual_matrix`)** — Tri-color cyber matrix rain (Cyan ➔ Green ➔ Sakura Pink).

### 3. 🚨 Per-Window Isolated Error Shake & Blazing Red Alert
- When a command fails with a non-zero exit status in Ghostty / Zsh / Bash, **only that specific window's border turns Thick Blazing Neon Red (`#ff0055`)** and executes a tactile horizontal shake animation.
- Other workspace windows remain in tranquil Miku Cyan.
- Upon executing a successful command, the active window smoothly morphs back to the Cyan/Pink gradient!

### 4. 📊 Custom Quickshell Status Bar & Floating Island Dock
- **Center Audio Island:** Live 6-bar PipeWire audio frequency visualizer integrated directly into the center media pill.
- **Universal CPU Thermal Engine:** Scans Intel Core/Ultra (`x86_pkg_temp`, `coretemp`) and AMD Ryzen (`k10temp`, `zenpower`) sensors dynamically.
- **One-Touch Cooler Boost:** Right-click CPU badge or press `SUPER + C` to toggle maximum fan cooling.
- **Frosted Popups & Panels:** Clean Acrylic popup cards for Clock/Calendar, Power, Audio, Network, Bluetooth, and Monitor controls with `slidefade 25%` layer transitions.

### 5. 🎨 Fastfetch High-Resolution Braille Anime Artwork
- **`ff`** — Standard Fastfetch system overview with 40/20/40 gradient block logo.
- **`ffa`** — High-resolution 65-line Braille anime art with 24-bit TrueColor diagonal gradient.

---

## ⌨️ Ergonomic Keybindings & Shortcuts

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `SUPER + Q` | **Rice Layout** | Sequentially launches Fastfetch, Btop, Momoisay, Cava & Virtual Matrix |
| `SUPER + ALT + UP` | **Toggle Live Wallpaper** | Toggles between 1080p live video/GIF and static wallpaper |
| `SUPER + ALT + RIGHT` | **Next Live Wallpaper** | Cycles to next live wallpaper with Portal curtain wipe transition |
| `SUPER + ALT + LEFT` | **Prev Live Wallpaper** | Cycles to previous live wallpaper with Portal curtain wipe transition |
| `SUPER + C` | **Toggle Cooler Boost** | Toggles maximum fan cooling on/off |
| `SUPER + E` | **File Manager** | Auto-detects default file manager (`xdg-open`) |
| `SUPER + B` | **Web Browser** | Launches default web browser |
| `SUPER + SHIFT + T` | **Theme Switcher** | Opens interactive theme picker |
| `SUPER + SHIFT + C` | **Color Picker** | Magnifier with auto hex copy |
| `SUPER + \` | **Matrix Screensaver**| Fullscreen Cyberpunk Matrix in terminal |

---

## 🚀 One-Line Installation

### Option 1: Full Rice Automated Setup (Recommended)
Clones the theme, custom Quickshell plugins, Hyprland configuration, helper scripts, and audio visualizer in one step:

```bash
git clone https://github.com/llIIllIID0EIIllIIll/virtual-paradise.git /tmp/virtual-paradise && bash /tmp/virtual-paradise/install.sh && rm -rf /tmp/virtual-paradise
```

### Option 2: Standard Theme Installation via Omarchy CLI
Installs the color scheme and wallpapers into Omarchy:

```bash
omarchy theme install https://github.com/llIIllIID0EIIllIIll/virtual-paradise.git
```

---

## 🛠️ Multi-Hardware & Shell Portability
- **Universal Shell Detection:** Seamlessly supports **Zsh**, **Bash**, and standard POSIX shells.
- **Universal Terminal Detection:** Automatically works across **Ghostty**, **Foot**, **Alacritty**, **Kitty**, and **WezTerm**.
- **100% Username Agnostic:** Zero hardcoded paths; strictly respects `$HOME` and `$XDG_CONFIG_HOME`.
- **Display Agnostic:** Auto-detects native refresh rates (60Hz, 144Hz, 240Hz, 4K, Ultrawide, OLED).

---

## ⚖️ License
Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.  
Crafted with 🌸 for the **Omarchy** and **Arch Linux** Community.
