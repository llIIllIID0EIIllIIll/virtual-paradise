<div align="center">

# Virtual☆Paradise

**Cyberpunk rice, theme and local development workspace for Omarchy Linux**

Arch Linux · Hyprland · Wayland · Quickshell

[![Platform](https://img.shields.io/badge/Platform-Arch%20%7C%20Omarchy%204.0%2B-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Compositor](https://img.shields.io/badge/Compositor-Hyprland-00f5d4?logo=wayland&logoColor=white)](https://hyprland.org)
[![License](https://img.shields.io/badge/License-MIT-00ff88.svg)](LICENSE)

</div>

Virtual☆Paradise is an Omarchy theme and desktop integration package built around a
cyan, green and sakura-pink palette. It installs the theme, Quickshell widgets,
live wallpapers, development tools, local AI assistant and hardware helpers
without editing Omarchy's packaged files under `/usr/share/omarchy`.

![Virtual Paradise desktop preview](assets/preview.png)

*Five-terminal development rice with live wallpaper, system telemetry, Cava and
Paradise Agent.*

## Highlights

### Workspace and wallpaper

- `SUPER + Q` opens the five-terminal rice in deterministic dwindle order:
  `fastfetch`/Paradise Agent, `btop`, `momoisay`, `cava` and `virtual_matrix`.
- The launcher waits only for windows to map, so startup is faster without
  breaking the intended layout.
- `mpvpaper` provides hardware-accelerated video/GIF wallpapers.
- Glitch transitions include a responsive neon loading HUD, target filename,
  animated progress bar and a 4.5-second safety timeout.

| Shortcut | Action |
| --- | --- |
| `SUPER + Q` | Five-terminal development rice |
| `SUPER + ALT + UP` | Toggle live/static wallpaper |
| `SUPER + ALT + RIGHT` | Next live wallpaper |
| `SUPER + ALT + LEFT` | Previous live wallpaper |
| `SUPER + N` | Next static theme background |

### Local Paradise Agent

`paradise-agent` is an Ollama/Qwen local coding and diagnostic assistant. It
supports file inspection and editing, shell execution, search, health checks,
session persistence and local skills.

The agent uses GPU-aware Ollama options by default:

- all available GPU layers (`num_gpu=99`);
- bounded CPU threads and tuned batch size;
- compact context handling and shorter tool-call output;
- internal reasoning hidden by default for a cleaner terminal UI.

Use `/thinking` to toggle reasoning display. Runtime tuning is available with:

```bash
export PARADISE_AGENT_MODEL=qwen2.5-coder:3b
export PARADISE_AGENT_NUM_CTX=4096
export PARADISE_AGENT_NUM_THREADS=8
export PARADISE_AGENT_NUM_GPU=99
export PARADISE_AGENT_NUM_BATCH=512
```

Aliases: `pa` and `offline-agent`.

### Hardware and GPU integration

- Acer Nitro EC, NBFC, ASUS `asusctl` and MSI `isw` are selected according to
  detected hardware.
- Cooler Boost uses the existing fan driver and only sends desktop
  notifications on errors or missing permissions/drivers; successful toggles
  print concise terminal output.
- NVIDIA systems enable `nvidia-persistenced` and NVIDIA persistence mode when
  `nvidia-smi` is available.

| Shortcut | Action |
| --- | --- |
| `SUPER + ALT + C` | Toggle Cooler Boost |
| `SUPER + E` | Open the default file manager |
| `SUPER + B` | Open the default browser |
| `SUPER + SHIFT + K` | Cast screen |
| `SUPER + SHIFT + T` | Theme switcher |
| `SUPER + SHIFT + C` | Color picker |
| `SUPER + \` | Matrix screensaver |

## Omarchy integrations

The installer configures these applications when available:

| Component | Configuration |
| --- | --- |
| Ghostty | Omarchy default terminal |
| Nautilus | Default `inode/directory` handler |
| VS Code | Default text/code MIME handlers and `EDITOR=code --wait` |
| GitHub Copilot CLI | Omarchy default coding agent |
| `crmne.hyprmoncfg` | Display & Scaling replacement |
| `jankeesvw.notification-center` | Notification center and DND control |

`hyprmoncfg` is installed from AUR as `hyprmoncfg` and the shell plugin is
installed with:

```bash
omarchy plugin add https://github.com/crmne/omarchy-hyprmoncfg.git --enable --yes
```

The theme disables the cloned `${USER}.monitor` and `omarchy.monitor` widgets
to prevent duplicate display controls. When another theme is selected, the
post-theme hook disables `crmne.hyprmoncfg` and restores `${USER}.monitor`.

The notification center is installed and enabled idempotently. Its DND control
replaces the standalone DND indicator in the Virtual☆Paradise bar, while
Omarchy's notification service remains enabled as its backend.

## Installation

### Recommended

```bash
git clone https://github.com/llIIllIID0EIIllIIll/virtual-paradise.git
cd virtual-paradise
./install.sh --no-boot
```

Use `./install.sh` for the complete installation including Plymouth, SDDM and
initramfs/UKI work. The installer requests sudo when needed and keeps package
operations under the regular user when launched through `sudo`.

### Installer modes

| Command | Purpose |
| --- | --- |
| `./install.sh` | Full installation |
| `./install.sh --no-boot` | Skip system-wide boot/login animation setup |
| `sudo ./install.sh --boot-only` | Update Plymouth/SDDM/UKI only |
| `./install.sh --hook` | Run theme/plugin synchronization without package or boot setup |

The installer is designed to be safely re-run. It backs up important existing
configuration, checks packages before installing, avoids duplicate plugin
clones, and reapplies the intended plugin state after shell/theme reloads.

### Uninstall

```bash
~/.local/bin/uninstall-virtual-paradise
```

The uninstaller stops only Virtual Paradise wallpaper/helper processes, restores
the saved Omarchy shell and GTK files when available, removes generated theme
files, and disables the theme-specific external plugins. It does not remove
system packages, NVIDIA configuration, or unrelated user plugins.

## Theme lifecycle

When `virtual-paradise` is selected, the hook:

1. restores the Virtual☆Paradise shell layout;
2. enables `crmne.hyprmoncfg` and disables the old display widgets;
3. enables the notification center and leaves the notification backend active;
4. applies the theme's GTK/Fastfetch configuration;
5. starts the live wallpaper if it is not already running.

When another theme is selected, it stops `mpvpaper`, restores the default bar
and GTK configuration, disables Virtual☆Paradise-only display integration and
re-enables the cloned display widget.

## Repository layout

```text
assets/       Preview and lockscreen artwork
backgrounds/  Video, GIF and static wallpaper assets
bin/          Launchers, wallpaper engine and Paradise Agent
config/       GTK and terminal configuration
fastfetch/    Fastfetch profiles and logos
hypr/         Hyprland Lua configuration and keybindings
plugins/      Quickshell widgets cloned into the active user namespace
shell/        Omarchy shell layout and shell configuration
theme/        Shared colors and application themes
plymouth/     Boot/shutdown animation files
sddm/         Login screen theme
install.sh    Idempotent installer and lifecycle setup
uninstall.sh  Conservative cleanup and configuration restore
```

## Requirements

- Omarchy Linux 4.0+ on Arch Linux;
- Hyprland and Quickshell;
- internet access for the initial package/plugin install;
- `yay` or `paru` for AUR packages;
- Ollama and a Qwen Coder model for Paradise Agent.

The installer adds the required packages where possible, including `ghostty`,
`nautilus`, `visual-studio-code-bin`, `github-copilot-cli`, `hyprmoncfg`,
`mpvpaper`, `jq`, `socat` and hardware-specific fan tooling.

## Validation

Safe local checks used by the project:

```bash
bash -n install.sh bin/*.sh
python3 -m py_compile bin/paradise_agent.py
jq empty shell/shell.json
./install.sh --hook
```

`--hook` exercises plugin synchronization and theme configuration without
installing packages or rebuilding the boot image.

## License

[MIT](LICENSE) · Made with love for the Omarchy and Arch Linux community.
