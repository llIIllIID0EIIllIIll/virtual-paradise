<div align="center">

```
██╗   ██╗██╗██████╗ ████████╗██╗   ██╗ █████╗ ██╗         ██████╗  █████╗ ██████╗  █████╗ ██████╗ ██╗███████╗███████╗
██║   ██║██║██╔══██╗╚══██╔══╝██║   ██║██╔══██║██║         ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║██╔════╝██╔════╝
██║   ██║██║██████╔╝   ██║   ██║   ██║███████║██║         ██████╔╝███████║██████╔╝███████║██║  ██║██║█████╗  █████╗  
╚██╗ ██╔╝██║██╔══██╗   ██║   ██║   ██║██╔══██║██║         ██╔═══╝ ██╔══██║██╔══██║██╔══██║██║  ██║██║╚════██║██╔══╝  
 ╚████╔╝ ██║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗    ██║     ██║  ██║██║  ██║██║  ██║██████╔╝██║███████║███████╗
  ╚═══╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚══════╝╚══════╝
```

### 🌸 A neon cyberpunk rice for Omarchy

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Omarchy 4.0+](https://img.shields.io/badge/Omarchy-4.0+-8A2BE2?style=flat-square)](https://omarchy.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00ffdd?style=flat-square)](https://hyprland.org)
[![Tests](https://img.shields.io/badge/tests-198%20passed-00ff88?style=flat-square)](tests/)
[![License](https://img.shields.io/badge/license-MIT-ffe066?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.2.2-ff00ff?style=flat-square)](VERSION)

*A complete desktop experience: floating island bar, animated wallpapers, Plymouth boot splash, and every widget restyled in Miku cyan.*

<br/>

**[Features](#-features)** • **[Screenshots](#-screenshots)** • **[Install](#-install)** • **[Configuration](#-configuration)** • **[Uninstall](#-uninstall)**

</div>

---

## ✨ Features

### 🏝️ Floating Island Bar

Three transparent pills with a neon hex backplate, animated gap glow, and live telemetry. Built as a first-party Quickshell plugin so `serviceFor()` works correctly — third-party bars get a scoped shell where services resolve to null.

- **Left island**: quick menu, Japanese workspace numerals, active window
- **Center island**: waveform visualizer, weather, clock, vitals (CPU/GPU/RAM/disk/net)
- **Right island**: system tray, network, audio, battery, power

### 🎬 Animated Wallpapers

Live video wallpapers with cyberpunk glitch transitions. Cycle through 7 animated backgrounds with `SUPER + ALT + ←` / `SUPER + ALT + →` (or `SUPER + ALT + N` / `SUPER + ALT + SHIFT + N`), or toggle between live and static with `SUPER + ALT + W`.

Wallpapers are H.264 MP4 (not GIF) for better performance and smaller file size. Plymouth extracts its animation frames with ffmpeg during install; the SDDM login theme plays the GIF directly.

### 🎨 Complete Theme Coverage

Every surface follows the same neon pastel palette:

- **Hyprland**: cyberSpring animations, frosted glass blur, multi-stop gradient borders
- **Terminal**: Ghostty, Alacritty, Foot, Kitty all themed identically
- **GTK**: CSS overrides for Nautilus, dialogs, and Libadwaita apps
- **Boot**: Plymouth splash with Miku animation, SDDM login theme
- **Editors**: Micro, VS Code, btop all follow the palette

### 🎭 Theme Menu

`SUPER + SHIFT + T` opens Omarchy's theme menu (the same menu as
`SUPER + SHIFT + CTRL + SPACE`), where Virtual☆Paradise can be selected
alongside any other installed theme. Switching themes does not require a
restart.

The repository also ships `theme-switcher.sh` for changing the Virtual☆Paradise
palette from a terminal (`theme-switcher.sh list` shows the variants,
`theme-switcher.sh reset` restores the original palette). It is a terminal
tool, not bound to a key.

### ✨ Visual Effects

Optional effects are available as scripts:

- **Rainbow Borders** — `effects.sh rainbow`
- **Glow Effect** — `effects.sh glow`
- **Toggle Blur** — `effects.sh toggle-blur`
- **Window Shake** — `effects.sh shake`

They run in the foreground or background as you choose; the theme does not bind
them to keys of their own. Every effect writes its setting through
`hyprctl eval`, because Hyprland 0.5x loads a Lua config and the legacy
`hyprctl keyword` subcommand is silently ignored there.

### 🔧 Smart Installer

Idempotent, XDG-compliant, and respects your existing config:

- Backs up files before overwriting
- Prunes old backups to prevent clutter
- Detects hardware and installs vendor-specific drivers (MSI, ASUS, Acer, Lenovo)
- Supports `--user-only` for sudo-free installs
- Supports `--no-boot` to skip Plymouth/SDDM
- Supports `--sddm-only` to reinstall just the login theme

### 🛡️ Override Layer

Third-party plugins are patched in-place to follow the theme palette. The override layer:

- Records every file it touches in a state file
- Reverts cleanly with `git checkout` or deletion
- Reapplies after every plugin update
- Resolves versioned `runtime/<hash>/` paths from `manifest.json`

This means your theme survives `omarchy plugin update` without manual intervention.

---

## 📸 Screenshots

> **Coming soon.** The previous screenshot showed a live session and was removed from the repository to reduce size. New screenshots will showcase the floating island bar, live wallpaper transitions, and terminal rice layout.

---

## 📦 Install

### Requirements

- **Arch Linux** (Omarchy 4.0+)
- **Hyprland** (Wayland compositor)
- **Quickshell** (status bar framework)

Optional:
- **NVIDIA GPU** (for nvidia-smi in Vitals widget)
- **Sudo access** (for Plymouth/SDDM, hardware drivers)

### Quick Install

```bash
git clone https://github.com/llIIllIID0EIIllIIll/virtual-paradise.git
cd virtual-paradise
./install.sh
```

The installer will:
1. Detect your hardware (MSI/ASUS/Acer/Lenovo/etc.)
2. Install vendor-specific drivers and fan control
3. Install 12+ Omarchy plugins (wavebar, vitals, audio-control, etc.)
4. Install the floating island bar as a first-party plugin
5. Apply theme overrides to all plugins
6. Install the Plymouth splash and the SDDM login theme (if sudo available)
7. Set up systemd timers for plugin updates and audio watchdog
8. Restart the shell to apply changes

### Install Modes

| Command | Description |
|---------|-------------|
| `./install.sh` | Full install with Plymouth/SDDM (requires sudo) |
| `./install.sh --user-only` | Skip Plymouth/SDDM, no sudo needed |
| `./install.sh --no-boot` | Skip Plymouth/SDDM even with sudo |
| `./install.sh --sddm-only` | Install only the SDDM login theme (requires sudo) |
| `./install.sh --hook` | Re-apply overrides only (for scripts) |

The installer is **idempotent**: run it as many times as you want. It will only update what changed.

### What Gets Installed

| Component | Location | Description |
|-----------|----------|-------------|
| Theme | `~/.config/omarchy/themes/virtual-paradise/` | Colors, icons, GTK CSS |
| Bar | `/usr/share/omarchy/shell/plugins/__USER__.island-bar/` | Floating island bar (first-party) |
| Plugins | `~/.config/omarchy/plugins/` | 12+ themed widgets |
| Hyprland | `~/.config/hypr/` | Animations, window rules, keybindings |
| Terminal | `~/.config/ghostty/`, `~/.config/alacritty/`, etc. | Terminal themes |
| Plymouth | `/usr/share/plymouth/themes/virtual-paradise/` | Boot splash; selected in `/etc/plymouth/plymouthd.conf` (if sudo) |
| SDDM | `/usr/share/sddm/themes/virtual-paradise/` | Login theme; selected in `/etc/sddm.conf.d/zz-virtual-paradise-theme.conf` (if sudo) |
| Systemd | `~/.config/systemd/user/` | Plugin update timer, audio watchdog |

---

## ⚙️ Configuration

### Keybindings

| Shortcut | Action |
|----------|--------|
| `SUPER + Q` | Launch rice layout (btop, cava, matrix, fastfetch) |
| `SUPER + N` | Next static wallpaper |
| `SUPER + ALT + W` | Toggle live/static wallpaper |
| `SUPER + ALT + N` | Next live wallpaper |
| `SUPER + ALT + RIGHT` | Next live wallpaper (arrow) |
| `SUPER + ALT + LEFT` | Previous live wallpaper (arrow) |
| `SUPER + ALT + SHIFT + N` | Previous live wallpaper |
| `SUPER + ALT + C` | Toggle cooler boost (laptop fan) |
| `SUPER + SHIFT + T` | Omarchy theme menu |
| `SUPER + E` | File manager |
| `SUPER + B` | Web browser |
| `SUPER + SHIFT + K` | Cast screen (wireless display) |
| `SUPER + SHIFT + L` | Lock screen |
| `SUPER + SHIFT + V` | VS Code |
| `SUPER + PERIOD` | Emoji picker |
| `SUPER + SHIFT + R` | Reload Hyprland config |
| `SUPER + R` | Resize mode (H/J/K/L or arrows, ESC/RETURN to exit) |
| `SUPER + BACKSLASH` | Matrix screensaver |

Omarchy's own bindings are unchanged: `SUPER + RETURN` opens the terminal,
`SUPER + K` lists keybindings, `SUPER + F` is fullscreen, and so on. The theme
only adds bindings on free chords, because Hyprland runs *every* bind for a
chord — a duplicate performs both actions.

The one deliberate exception is `SUPER + ALT + ←` / `→`: Omarchy binds those to
"move window into the group on the left/right", and the theme uses them for
the live wallpaper. The theme removes Omarchy's two binds with `hl.unbind()`
first, so only one action runs, and the group move moves to
`SUPER + ALT + CTRL + ←` / `→`.

### Text Size & Display Layout

The theme deliberately leaves both to you and to the tools that do them well:

- **Font size** is never set by the theme. Ghostty applies a `config-file`
  include *after* the file that pulls it in, so a size in the theme's config
  would override your own — that is how a fresh install turned 9pt text into
  12pt text. Change the size in your terminal's own config
  (`~/.config/ghostty/config`, `~/.config/foot/foot.ini`, …) and every
  terminal scales it with the display's DPI.
- **Monitor layout** is not touched either. hyprmoncfg applies a profile per
  setup and switches between them on hotplug, lid open and suspend; the
  theme only ships the toolkit environment variables, so the scale follows
  the panel instead of being pinned to 1.

### Changing Colors

Edit `theme/colors.toml` to adjust the palette. The installer will reapply overrides on next run.

Key colors:
- `accent` — Miku cyan (`#00ffdd`)
- `background` — Deep purple (`#0f081d`)
- `foreground` — Soft white (`#eafbfa`)
- `red` — Neon magenta (`#ff00ff`)
- `green` — Hacker green (`#00ff88`)
- `yellow` — Cyber yellow (`#ffe066`)

### Adding Wallpapers

Drop MP4 or GIF files into `backgrounds/` and re-run the installer. The wallpaper picker will automatically detect them.

To convert GIF to MP4 (smaller file size):
```bash
ffmpeg -i input.gif -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -preset slow -crf 23 output.mp4
```

### Updating Plugins

The theme includes a systemd timer that checks for plugin updates daily. To update manually:

```bash
omarchy plugin update
paradise-plugin-update --apply  # Reapply theme overrides
```

The `paradise-plugin-update` wrapper:
1. Reverts all theme overrides
2. Runs `omarchy plugin update`
3. Reapplies overrides from the theme
4. Records the new state

This ensures your theme survives upstream changes.

### Disabling Components

**Disable live wallpapers:**
```bash
systemctl --user stop live-wallpaper.service
systemctl --user disable live-wallpaper.service
```

**Disable plugin update timer:**
```bash
systemctl --user stop paradise-plugin-update.timer
systemctl --user disable paradise-plugin-update.timer
```

**Disable audio watchdog:**
```bash
systemctl --user stop paradise-audio-watchdog.timer
systemctl --user disable paradise-audio-watchdog.timer
```

---

## 🗑️ Uninstall

```bash
./uninstall.sh
```

The uninstaller will:
1. Switch to the default Omarchy theme
2. Remove all Virtual Paradise files
3. Restore backups of your original configs
4. Remove the SDDM login theme and restore the previous theme selection (if sudo available)
5. Disable systemd timers
6. Leave a snapshot in `~/.local/share/virtual-paradise/uninstall-snapshots/`

### Uninstall Flags

| Flag | Description |
|------|-------------|
| `--keep-backups` | Keep `shell-default.json` and the snapshot dir |
| `--purge-defaults` | Also delete `shell-default.json` (irreversible) |

---

## 🔧 Development

### Running Tests

The test suite has fourteen test cases and 198 assertions; optional tools
(`shellcheck`, `qmllint`, `hyprctl`) enable extra checks when present, so the
exact count varies between machines (171 with `shellcheck`, 170 without). It
runs in a sandbox and never touches your real system.

```bash
./tests/run.sh          # Run all tests
./tests/run.sh tc1 tc12 # Run specific test cases
```

Test cases:
- **TC-1**: Static analysis (shellcheck, bash -n, JSON/TOML validation)
- **TC-2**: Override layer (entry point resolution, state tracking)
- **TC-3**: Installer idempotency (no drift on repeated runs)
- **TC-4**: Uninstaller (restores backups, removes files)
- **TC-5**: XDG compliance (respects `XDG_CONFIG_HOME`)
- **TC-6**: shell-default.json (never fakes pristine snapshot)
- **TC-7**: User config restoration (zshrc, ghostty, fcitx5, micro)
- **TC-8**: Theme-set hook (both directions, plugin state)
- **TC-9**: Wallpaper playlist (all files detected)
- **TC-10**: SDDM theme (standalone install, selection, legacy repair, uninstall)
- **TC-11**: Plymouth theme (standalone install, selection, legacy repair, uninstall)
- **TC-12**: Theme variants (every palette-carrying file stays in sync, reset)
- **TC-13**: Responsive typography and display layout (no pinned font size, no monitor rules)
- **TC-14**: Omarchy environment (the installer works with a reset environment)

### Project Structure

```
virtual-paradise/
├── assets/               # Unlock artwork, preview images
├── backgrounds/          # Live wallpapers (MP4/GIF)
├── bars/
│   └── island-bar/       # Floating island bar (first-party plugin)
├── bin/                  # Helper scripts (rice layout, wallpaper picker, etc.)
├── cava/                 # Cava visualizer config
├── config/
│   ├── editor/           # VS Code theme
│   └── terminal/         # Ghostty, Alacritty, Foot, Kitty configs
├── fastfetch/            # Fastfetch config and anime logo
├── hypr/                 # Hyprland config (animations, keybindings, rules)
├── lib/
│   ├── plugin-overrides.sh    # Override layer implementation
│   ├── plymouth.sh             # Plymouth theme install/remove/legacy repair
│   ├── sddm.sh                # SDDM theme install/remove/legacy repair
│   ├── system.sh              # Hardware detection
│   └── theme-set-hook.sh      # Theme-set hook (extracted from install.sh)
├── micro/                # Micro editor theme
├── overrides/            # Plugin overrides (QML patches)
├── plymouth/             # Plymouth boot splash (standalone, self-contained)
├── sddm/                 # SDDM login theme (standalone, self-contained)
├── shell/                # shell.json template, zshrc
├── systemd/              # Systemd unit files
├── tests/                # Test suite
├── theme/                # colors.toml, shell.toml, GTK CSS
├── tools/
│   ├── shrink-history.sh        # Git history cleanup
│   └── convert-gifs-to-mp4.sh   # Wallpaper compression
├── install.sh            # Installer
├── uninstall.sh          # Uninstaller
├── VERSION               # Semantic version (1.2.2)
└── README.md             # This file
```

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Quick summary:

- Follow conventional commits (`feat:`, `fix:`, `refactor:`, etc.)
- Run `./tests/run.sh` before committing
- Run `shellcheck` on all shell scripts
- Test on a clean Omarchy install before PR

### Reducing Repository Size

The repository is ~90 MB due to live wallpapers. To reduce size:

```bash
# Convert GIFs to MP4 (saves ~40 MB)
./tools/convert-gifs-to-mp4.sh

# Rewrite git history to remove old blobs (requires force-push)
./tools/shrink-history.sh --dry-run
./tools/shrink-history.sh --apply
```

**Warning**: `shrink-history.sh` rewrites history. Coordinate with collaborators before force-pushing.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Credits

- **Omarchy** — The Hyprland rice framework
- **Hyprland** — Wayland compositor
- **Quickshell** — Status bar and widgets
- **mpvpaper** — Video wallpaper player
- **Cava** — Audio visualizer
- **btop** — Resource monitor
- **Fastfetch** — System info

Special thanks to the Omarchy community and r/unixporn for inspiration.

---

<div align="center">

**Made with 💜 for the Omarchy community**

[Report Bug](https://github.com/llIIllIID0EIIllIIll/virtual-paradise/issues) • [Request Feature](https://github.com/llIIllIID0EIIllIIll/virtual-paradise/issues) • [Discussions](https://github.com/llIIllIID0EIIllIIll/virtual-paradise/discussions)

</div>
