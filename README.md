<div align="center">

# Virtual☆Paradise

**Full-Topping Cyberpunk Rice & Universal Theme for Omarchy Linux**

*Arch Linux · Hyprland · Wayland*

[![Platform](https://img.shields.io/badge/Platform-Arch_Linux_|_Omarchy_4.0+-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Compositor](https://img.shields.io/badge/Compositor-Hyprland_0.56+-00f5d4?logo=wayland&logoColor=white)](https://hyprland.org)
[![Shell](https://img.shields.io/badge/Shell-Quickshell_|_Zsh-ffb7d5)](https://github.com/outfoxxed/quickshell)
[![License](https://img.shields.io/badge/License-MIT-00ff88.svg)](LICENSE)

*Tri-Color Palette — 40% Miku Cyan `#00f5d4` · 20% Hacker Green `#00ff88` · 40% Sakura Pink `#ffb7d5`*

</div>

---

![Virtual Paradise Desktop Rice & Paradise Agent Preview](assets/preview.png)
*5-Terminal Development Rice featuring Live Video Wallpaper, Quickshell Status Bar, System Telemetry & Paradise Agent*

---

## Features

### 🎬 Cinematic Live Wallpaper Engine
Hardware-accelerated 60fps video & GIF playback via `mpvpaper`. Switching wallpapers triggers a Cyberpunk **Glitch Transition** — horizontal slice displacement, RGB chromatic aberration flashes, and digital signal breakdown — courtesy of a custom Quickshell overlay (`glitch_transition.qml`).

| Shortcut | Action |
| :--- | :--- |
| `SUPER + ALT + UP` | Toggle live wallpaper on/off |
| `SUPER + ALT + RIGHT` | Next wallpaper in playlist |
| `SUPER + ALT + LEFT` | Previous wallpaper in playlist |

Playlist order: `Miku_live.mp4` → `Miku_missing.gif` → `Miku_animated_full.gif` → `Miku_animated1~4.gif`

---

### 🔒 Animated Cyberpunk Lockscreen
Full-screen `Sleeping_miku.gif` via native QtQuick. Neon HUD clock (`#00f5d4`), Sakura Pink date (`#ffb7d5`), live `fortune` quotes refreshing every 10 seconds, and a glassmorphism acrylic password field with neon green masked dots.

---

### 🚀 Cinematic Boot & Shutdown Animations
- **Plymouth boot:** 259-frame 1080p `Miku_animated_full.gif` with instant lazy-loading (frame 1 renders in `<15ms`). Also shown during LUKS decryption.
- **SDDM login:** QtQuick6 animated login screen with 20% acrylic overlay.
- **Shutdown outro:** 72-frame `Miku_missing.gif`. Custom systemd drop-ins eliminate the black screen gap — Plymouth claims DRM immediately on session exit.

---

### ⚡ 5-Terminal Development Rice (`SUPER + Q`)
Launches a complete cyberpunk workspace in a single keystroke:

| Pane | App | Role |
| :--- | :--- | :--- |
| Left | `fastfetch` | System info with high-res Braille anime logo |
| Top-right | `btop` | Real-time CPU / memory / process monitor |
| Center | `momoisay` | Saiba Momoi ASCII mascot dialogue |
| Bottom-right | `cava` | 8-band audio spectrum visualizer |
| Far-right | `virtual_matrix` | Tri-color matrix rain (Cyan → Green → Pink) |

---

### 🔍 Search☆Hub (`f`)
Unified terminal omnisearch with adaptive live preview:
- **Directories** (`fd -t d`) → instant `cd`
- **Files** (`fd -t f`) → multi-select open in `micro`
- **Text in files** (`rg`) → jump to matched line
- `[←]` back navigation through parent folders

---

### 🤖 Offline AI System Agent (`paradise-agent` / `a`)
100% air-gapped local AI powered by **Ollama + Qwen 2.5 Coder** — no cloud, no API keys, ~2 GB RAM:

- **Auto-escalating model tiers:** starts on the smallest installed model (1.5B), automatically upgrades to 3B → 7B when tasks become too complex.
- **Full tool belt:** read/write/edit files, run bash, grep/find codebase, system health diagnostics, session persistence, expert skills (Hyprland config, crash diagnosis).
- **Local Intent Analysis panel:** shows the agent's decision reasoning, planned tool call, and telemetry inline before every action.
- **Add-on coexistence:** Coexists seamlessly with Omarchy's official agent system. `omarchy agent` (or alias `a`) continues running your chosen default (Copilot, Claude, etc.), while Paradise Agent is instantly accessible via `paradise-agent` · `agy-offline` · alias `pa` / `agy`.

---

### 🚨 Window Error Shake & Neon Red Border
Any terminal command returning a non-zero exit code automatically shakes the active window and turns its border glowing neon red.

### ❄️ Hardware Cooler Boost (`SUPER + C`)
One-key fan cooling toggle with on-screen OSD notification.

---

## Keybindings

| Shortcut | Action |
| :--- | :--- |
| `SUPER + Q` | 5-Terminal Rice Layout |
| `SUPER + ALT + UP` | Toggle Live Wallpaper |
| `SUPER + ALT + RIGHT/LEFT` | Next / Prev Live Wallpaper |
| `SUPER + N` | Next theme background |
| `SUPER + C` | Toggle Cooler Boost |
| `SUPER + E` | File Manager |
| `SUPER + B` | Web Browser |
| `SUPER + SHIFT + T` | Theme Switcher |
| `SUPER + SHIFT + C` | Color Picker |
| `SUPER + \` | Matrix Screensaver |
| `SUPER + CTRL + L` | Lock Screen |
| `f` *(terminal)* | Search☆Hub |
| `ffa` *(terminal)* | Fastfetch with Anime Braille logo |
| `a` *(terminal)* | Omarchy Default Agent (`copilot`, `claude`, etc.) |
| `pa` *(terminal)* | Paradise Local Offline AI Agent (`paradise-agent`) |

---

## Repository Structure

```
omarchy-virtual-paradise/
│
├── README.md               Project documentation
├── LICENSE                 MIT License
├── .gitignore
├── install.sh              Automated 10-step installer
│
├── assets/
│   ├── preview.png         Desktop screenshot
│   └── unlock.png          Lock screen logo
│
├── config/
│   ├── terminal/           alacritty · foot · ghostty · kitty configs
│   ├── editor/             helix · neovim · gum_env configs
│   └── gtk.css             GTK 3/4 cyberpunk stylesheet
│
├── theme/
│   ├── colors.toml         Master TrueColor palette
│   ├── colors.css          CSS custom property definitions
│   ├── btop.theme          Btop TrueColor theme
│   ├── chromium.theme      Chromium browser theme
│   ├── shell.toml          Shell environment color tokens
│   ├── icons.theme         Icon theme definition
│   ├── keyboard.rgb        RGB backlight profile
│   ├── vscode.json         VS Code extension config
│   └── vscode-theme.json   VS Code color token definitions
│
├── hypr/
│   ├── hyprland.conf       Hyprland top-level config
│   ├── hyprland.lua        Window decoration & animation rules
│   ├── hyprlock.conf       Lockscreen color overrides
│   ├── hyprland-preview-share-picker.css
│   ├── autostart.lua       Startup daemons & wallpaper init
│   ├── bindings.lua        Keybindings & D-Pad navigation
│   ├── input.lua           Touchpad, mouse & keyboard layout
│   ├── looknfeel.lua       Gaps, blur & spring physics
│   └── monitors.lua        Display resolution & layout
│
├── bin/
│   ├── paradise_agent.py         Offline AI agent (Ollama / Qwen)
│   ├── toggle_live_wallpaper.sh  Live wallpaper playlist engine
│   ├── glitch_transition.qml     Cyberpunk glitch transition overlay
│   ├── curtain_transition.qml    Alternate transition overlay
│   ├── logout_splash.qml         Miku outro shutdown splash
│   ├── rice_layout.sh            5-terminal workspace launcher
│   ├── virtual_matrix.py         Tri-color matrix rain generator
│   ├── toggle_cooler_boost.sh    Fan Cooler Boost controller
│   ├── toggle_btop.sh            Floating Btop toggle
│   ├── momoisay                  Saiba Momoi ASCII mascot
│   ├── format-docx-vn.py         Vietnamese .docx formatter
│   ├── memory_detail_notify.sh   RAM desktop notification
│   ├── hypr_window_error_shake.sh    Error shake hook
│   ├── hypr_window_error_restore.sh  Error border restore
│   ├── omarchy-launch-terminal   Terminal launcher
│   ├── omarchy-system-logout     Animated logout wrapper
│   ├── omarchy-system-reboot     Animated reboot wrapper
│   ├── omarchy-system-shutdown   Animated shutdown wrapper
│   └── toggle_voxtype_config.sh  Voice-to-text config toggle
│
├── backgrounds/
│   ├── Miku_live.mp4             1080p 60fps live video wallpaper (default)
│   ├── Miku_animated_full.gif    259-frame boot/SDDM wallpaper
│   ├── Miku_animated1~4.gif      Additional animated wallpapers
│   ├── Miku_missing.gif          72-frame shutdown outro
│   ├── Miku_missing.jpg          Static cyberpunk fallback
│   └── Glitch.jpg                Glitch transition artwork (8001×4500)
│
├── plugins/                Quickshell status bar plugins (auto-calibrated to $USER.*)
│   ├── active-window/      Window title widget
│   ├── audio/              Volume & output switcher
│   ├── bluetooth/          Bluetooth manager
│   ├── clock/              Clock, date & calendar
│   ├── cputemp/            CPU temp & Cooler Boost
│   ├── indicators/         System indicators (recording, night light, DND)
│   ├── lock/               Sleeping Miku lockscreen plugin
│   ├── media/              MPRIS media controller
│   ├── memory/             RAM monitor & btop launcher
│   ├── menu/               Quick applications menu
│   ├── microphone/         Mic mute & volume
│   ├── monitor/            Brightness & resolution
│   ├── network/            Wi-Fi & Ethernet manager
│   ├── power/              Battery & power profile
│   ├── system-update/      Update notifications
│   ├── weather/            Weather forecast
│   └── workspaces/         Workspace switcher
│
├── cava/                   Audio spectrum visualizer configs
├── fastfetch/              System info layout & anime Braille logo
├── micro/                  Micro editor theme & settings
├── shell/                  shell.json (bar layout) & zshrc
├── plymouth/               Boot animation engine & systemd drop-ins
└── sddm/                   Animated login display manager theme
```

---

## Installation

### Quick Install (Recommended)

```bash
git clone https://github.com/llIIllIID0EIIllIIll/virtual-paradise.git
cd virtual-paradise
./install.sh
```

The installer runs **10 automated steps**:

1. Verify & install required packages (`mpvpaper`, `btop`, `cava`, `fastfetch`, `micro`, `fortune-mod`, `ripgrep`, `fd`, `ffmpeg`, `ollama`, …)
2. Create runtime directories & back up existing configs
3. Calibrate & install all 18 Quickshell plugins for your `$USER`
4. Deploy status bar layout & quick-action menu extensions
5. Install Hyprland keybindings, look'n'feel & autostart configs
6. Install CLI tools & scripts to `~/.local/bin/`
7. Install component themes (Cava, Btop, Fastfetch, Micro, GTK)
8. Sync theme assets, wallpapers & automation hooks
9. Configure Plymouth boot animation, SDDM login & rebuild UKI *(requires sudo)*
10. Configure `~/.zshrc` / `~/.bashrc` with Search☆Hub & error shake hooks

### Flags

| Flag | Effect |
| :--- | :--- |
| *(none)* | Full installation |
| `--no-boot` | Skip Plymouth / SDDM / UKI — no sudo required |
| `--boot-only` | Boot & shutdown animations only |

```bash
# User-space only, no sudo needed
./install.sh --no-boot

# Boot animations only
sudo ./install.sh --boot-only
```

### Requirements

- **Omarchy Linux 4.0+** (Arch Linux + Hyprland)
- **Ollama** with at least one `qwen2.5-coder` model for the AI agent
- Internet connection for the initial package install step

---

## License

[MIT](LICENSE) · Made with 💖 for the Omarchy & Arch Linux community.
