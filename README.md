# 🌸 Virtual☆Paradise

> **Full-Topping Cyberpunk Rice & Universal Theme for Omarchy Linux (Arch Linux + Hyprland)**  
> *Tri-Color Palette: 40% Miku Cyan (`#00f5d4`) · 20% Hacker Green (`#00ff88`) · 40% Sakura Pink (`#ffb7d5`)*

[![Platform](https://img.shields.io/badge/Platform-Arch_Linux_|_Omarchy_4.0+-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Compositor](https://img.shields.io/badge/Compositor-Hyprland_0.56+-00f5d4?logo=wayland&logoColor=white)](https://hyprland.org)
[![Shell](https://img.shields.io/badge/Shell-Quickshell_|_Zsh-ffb7d5)](https://github.com/outfoxxed/quickshell)
[![License](https://img.shields.io/badge/License-MIT-00ff88.svg)](LICENSE)

---

## 📸 Overview & Aesthetic Philosophy

**Virtual☆Paradise** transforms your Arch Linux / Omarchy desktop into a high-performance, neon-pastel cyberpunk command center. Designed with meticulous attention to detail, every element—from hardware fan cooling to terminal omnisearch and live video wallpaper transitions—delivers fluid 60fps animations, glassmorphism transparency, and rich TrueColor ergonomics.

![Virtual Paradise Desktop Preview](preview.png)

---

## ✨ Key Architectural Innovations & Features

### 1. 🎬 Cinematic Portal Curtain Live Wallpaper Engine
* **Hardware-Accelerated 60fps GPU Playback:** Seamlessly plays live video (`Miku_live.mp4`) and animated GIFs (`Aura_farming.gif`, `Night_city.gif`) via `mpvpaper` with negligible idle CPU impact.
* **Top-to-Bottom Drop & Dual-Split Reveal:** Switching wallpapers triggers a custom Quickshell overlay (`curtain_transition.qml`) where the `Portal.jpg` curtain drops smoothly from the top of the monitor (`Easing.OutCubic`), swaps the wallpaper behind the scenes, and parts down the middle outward to both sides (`Easing.InCubic`).
* **Layer Hierarchy (`WlrLayer.Bottom`):** The transition operates above the wallpaper canvas while staying below the top status bar.
* **Directional D-Pad Navigation:**
  * `SUPER + ALT + UP`: Toggle Live Wallpaper on/off (switches to `Big_city.jpg` static fallback).
  * `SUPER + ALT + RIGHT`: Next Live Wallpaper in playlist.
  * `SUPER + ALT + LEFT`: Previous Live Wallpaper in playlist.

---

### 2. 🔒 Cyberpunk Animated Lockscreen (`doe.lock`)
* **Native QtQuick Animated Image:** Custom Quickshell session lock plugin displaying full-screen 1080p `Sleeping_miku.gif` with zero blur or lag.
* **Live Neon HUD Clock & Date:** Glowing Miku Cyan (`#00f5d4`) digital clock and Sakura Pink (`#ffb7d5`) calendar header.
* **Linux `fortune` Wisdom Engine:** Automatically invokes `fortune -s` to display dynamic system wisdom, programming jokes, and Linux aphorisms, auto-refreshing every 10 seconds.
* **Acrylic Glassmorphism Password Input:** Rounded input surface positioned at the bottom with neon green masked dots (`#00ff88`).

---

### 3. ⚡ 5-Terminal Development Rice (`SUPER + Q`)
Launches a complete 5-pane cyberpunk development workspace in microseconds via Wayland socket dispatch:
1. 🖥️ **`fastfetch`** — Master left panel with system information and high-res anime Braille logo.
2. 📊 **`btop`** — Top-right real-time CPU, GPU, memory, and process monitor in TrueColor.
3. 🌸 **`momoisay`** — Center-bottom animated Saiba Momoi ASCII mascot dialogue in glowing Cyan.
4. 🎵 **`cava`** — Bottom-right 8-band audio spectrum visualizer.
5. 👾 **`virtual_matrix`** — Tri-color cyber matrix rain (Cyan ➔ Green ➔ Sakura Pink).

---

### 4. 🔍 Unified Search☆Hub (`f` Command)
* **100% Nerd Font Standardization:** Fully decorated with crisp Nerd Font glyphs (`󰍉`, ``, `󰈙`, ``, ``, ``).
* **Omnisearch Pipeline:** Single unified search engine prioritizing:
  1. ` ` Directories (`fd -t d`) $\rightarrow$ Instant `cd`
  2. `󰈙 ` Files (`fd -t f`) $\rightarrow$ Multi-select file editor open (`micro`)
  3. ` ` Text inside files (`rg`) $\rightarrow$ Direct jump to matched line number
* **Adaptive Live Preview:** Real-time directory trees (`eza`), syntax-highlighted code (`bat`), and line previews.
* **Hierarchical `[←]` Back Navigation:** Seamlessly browse upward through parent folders or return to Search☆Hub.

---

### 5. 📝 Micro Editor Cyberpunk Rice
* **TrueColor Theme:** `virtual-paradise.micro` custom color palette with syntax highlighting, diff gutter, and line numbers.
* **Statusline:** Customized Nerd Font status bar (`󰈙 filename · 󰄬 Ln X, Col Y`).

---

### 6. ❄️ Hardware Cooler Boost (`SUPER + C`)
* **Instant Thermal Management:** One-key toggle that drives laptop/desktop cooling fans to maximum RPM, displaying an on-screen desktop OSD.

---

### 7. 🚨 Window Error Shake & Neon Red Border Hook
* When any terminal command returns a non-zero exit code, Hyprland automatically shakes the active window and turns its border glowing neon red.

---

## ⌨️ Ergonomic Keybindings & Shortcuts

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `SUPER + Q` | **Rice Layout** | Launches 5-terminal workspace (Fastfetch, Btop, Momoisay, Cava, Matrix) |
| `SUPER + ALT + UP` | **Toggle Live Wallpaper** | Switches between Live Video/GIF and static `Big_city.jpg` |
| `SUPER + ALT + RIGHT` | **Next Live Wallpaper** | Cycles to next live wallpaper with Portal curtain wipe transition |
| `SUPER + ALT + LEFT` | **Prev Live Wallpaper** | Cycles to previous live wallpaper with Portal curtain wipe transition |
| `SUPER + N` | **Next Wallpaper** | Cycles to next Omarchy theme background |
| `SUPER + C` | **Toggle Cooler Boost** | Toggles maximum fan cooling on/off |
| `SUPER + E` | **File Manager** | Auto-detects default file manager (`xdg-open`) |
| `SUPER + B` | **Web Browser** | Launches default web browser |
| `SUPER + SHIFT + T` | **Theme Switcher** | Opens interactive theme selector menu |
| `SUPER + SHIFT + C` | **Color Picker** | Magnifier with auto hex copy |
| `SUPER + \` | **Matrix Screensaver** | Fullscreen Cyberpunk Matrix in terminal |
| `SUPER + CTRL + L` | **Lock Screen** | Locks screen with Sleeping Miku animated HUD |
| `f` *(in terminal)* | **Search☆Hub** | Unified Explorer, Command History & Process Manager |
| `ffa` *(in terminal)* | **Fastfetch Anime** | High-res 65-line Braille anime art with 24-bit TrueColor gradient |

---

## 📂 Repository Directory Layout

```
omarchy-virtual-paradise/
├── backgrounds/                # Live videos, animated GIFs & static wallpapers
│   ├── Aura_farming.gif        # Aura Farming anime live wallpaper
│   ├── Big_city.jpg            # Default 1080p static city artwork
│   ├── Miku_live.mp4           # 60fps Hatsune Miku live video
│   ├── Night_city.gif          # Cyberpunk night city live wallpaper
│   └── Portal.jpg              # Curtain transition artwork (3840x1080)
├── bin/                        # CLI helper tools & transition overlays
│   ├── curtain_transition.qml  # Quickshell Portal drop & split transition
│   ├── momoisay                # Animated Saiba Momoi ASCII generator
│   ├── rice_layout.sh          # 5-terminal workspace orchestrator
│   ├── toggle_cooler_boost.sh  # Hardware fan boost controller
│   ├── toggle_live_wallpaper.sh# Live wallpaper playlist engine
│   └── virtual_matrix.py       # Tri-color Cyberpunk matrix rain
├── cava/                       # Audio spectrum visualizer configs
│   ├── config                  # Terminal cava configuration
│   └── config_bar              # Bar widget cava configuration
├── fastfetch/                  # Fastfetch system info & anime ASCII logos
│   ├── config.jsonc            # Clean fastfetch profile layout
│   └── logo_anime.txt          # 65-line Braille Anime ASCII artwork
├── hypr/                       # Hyprland system configuration
│   ├── autostart.lua           # Startup daemons & live wallpaper init
│   ├── bindings.lua            # Complete ergonomic keyboard shortcuts
│   ├── input.lua               # Touchpad & keyboard settings
│   ├── looknfeel.lua           # Window borders, gaps, blur & animations
│   └── monitors.lua            # Display & resolution rules
├── micro/                      # Micro editor cyberpunk configuration
│   ├── colorschemes/           # TrueColor theme: virtual-paradise.micro
│   └── settings.json           # Micro editor preferences & statusline
├── plugins/                    # Customized Omarchy Quickshell plugins
│   ├── doe.active-window/      # Active window title bar widget
│   ├── doe.audio/              # Audio volume & output switcher
│   ├── doe.bluetooth/          # Bluetooth device manager
│   ├── doe.clock/              # Live clock, date & calendar
│   ├── doe.cputemp/            # CPU temperature & cooler boost
│   ├── doe.lock/               # Sleeping Miku lockscreen & fortune quotes
│   ├── doe.media/              # MPRIS media player controller
│   ├── doe.memory/             # RAM / Swap memory monitor & btop launcher
│   ├── doe.menu/               # Omarchy quick applications menu
│   ├── doe.network/            # Wi-Fi / Ethernet network manager
│   ├── doe.power/              # Battery & power profile widget
│   ├── doe.weather/            # Weather forecast widget
│   └── doe.workspaces/         # Workspace switcher
├── shell/                      # Shell configurations
│   ├── shell.json              # Status bar layout (transparency off)
│   └── zshrc                   # Cyberpunk Zsh configuration with Search☆Hub
├── colors.toml                 # Master TrueColor palette definitions
├── hyprland.lua                # Theme-level window rules & animations
├── hyprlock.conf               # Theme lock screen color overrides
├── install.sh                  # Automated, idempotent installation script
├── LICENSE                     # MIT License
└── preview.png                 # Theme screenshot
```

---

## 🚀 Installation Guide

### Option 1: Automated Installation (Recommended)

Clone the repository and run the automated installer:

```bash
git clone https://github.com/llIIllIID0EIIllIIll/virtual-paradise.git
cd virtual-paradise
chmod +x install.sh
./install.sh
```

The installer will automatically:
1. Verify and install any missing packages (`cava`, `btop`, `fastfetch`, `micro`, `fortune-mod`, `mpvpaper`, `ripgrep`, `fd`, etc.).
2. Deploy theme assets, wallpapers, and fonts.
3. Configure and calibrate Quickshell plugins dynamically for your username.
4. Set up Hyprland keybindings, look'n'feel, and autostart scripts.
5. Install CLI helper tools to `~/.local/bin/`.
6. Configure `~/.zshrc` with the Search☆Hub engine and compile bytecode cache.
7. Apply the theme and initialize the live video wallpaper immediately.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
Made with 💖 for the Omarchy & Arch Linux community.
