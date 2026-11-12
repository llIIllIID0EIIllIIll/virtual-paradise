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
[![Omarchy 4.5+](https://img.shields.io/badge/Omarchy-4.5+-8A2BE2?style=flat-square)](https://omarchy.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00ffdd?style=flat-square)](https://hyprland.org)
[![Tests](https://img.shields.io/badge/tests-533%20passed-00ff88?style=flat-square)](tests/)
[![License](https://img.shields.io/badge/license-MIT-ffe066?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.4.0-ff00ff?style=flat-square)](VERSION)

*A complete desktop experience: floating island bar, animated wallpapers, Plymouth boot splash, and every widget restyled in Miku cyan.*

**English** • [Tiếng Việt](README.vi.md)

<br/>

**[Features](#-features)** • **[Screenshots](#-screenshots)** • **[Install](#-install)** • **[Configuration](#-configuration)** • **[Uninstall](#-uninstall)**

</div>

---

## ✨ Features

### 🏝️ Floating Island Bar

Three floating glass pills over a faint hex underlay, a sparse comet stream in the gaps, a scanner spark orbiting the bar's rim, and a lit hover pill on every widget - all riding the same rotating gradient as the window borders. Built as a first-party Quickshell plugin so `serviceFor()` works correctly — third-party bars get a scoped shell where services resolve to null.

- **Left island**: quick menu, Japanese workspace numerals, active window
- **Center island**: waveform visualizer, weather, clock, vitals (CPU/GPU/RAM/disk/net), CPU temperature, microphone, indicator dots
- **Right island**: system tray, network, audio, power, updates, tools
- **Ambient overlays**: a neon glow trails the pointer over terminals (it stays out of the way on games, browsers and the bar), and the screen edges flash cyan on a workspace change and magenta when a notification arrives

The gap stream, the rim scanner and the hover chrome are opt-out in `~/.config/omarchy/shell.json`; see [Bar Effects](#bar-effects).

The theme keeps its effects without a second Quickshell: the window-close burst
is an overlay plugin inside the main shell, the lock preview loads on demand,
and the terminal hex grid exists only inside the cursor spotlight's small
canvas, so no terminal decodes a background texture at all. See
[Memory](#memory) for the details.

### 🎬 Animated Wallpapers

Live video wallpapers with cyberpunk glitch transitions. Cycle through 7 animated backgrounds with `SUPER + ALT + N` / `SUPER + ALT + SHIFT + N`, or toggle between live and static with `SUPER + ALT + W`.

Wallpapers are H.264 MP4 (not GIF) for better performance and smaller file size. Plymouth extracts its animation frames with ffmpeg during install; the SDDM login theme plays the GIF directly.

### 🎨 Complete Theme Coverage

Every surface follows the same neon pastel palette:

- **Hyprland**: cyberSpring animations, frosted glass blur (windows *and* the shell's bar/menu/popup layers), rotating multi-stop gradient borders and shadows
- **Terminal**: Ghostty, Alacritty, Foot, Kitty all themed identically, with a hex grid the pointer lights up in a hazy pool of light (the terminal stays plain glass at rest), plus matching Yazi, Bat and tmux themes
- **GTK**: CSS overrides for Nautilus, dialogs, and Libadwaita apps
- **Boot**: Plymouth splash with Miku animation, SDDM login theme
- **Editors**: Micro, VS Code, btop all follow the palette

### 🎭 Theme Menu

`SUPER + CTRL + T` opens Omarchy's theme menu (the same menu as
`SUPER + SHIFT + CTRL + SPACE`), where Virtual☆Paradise can be selected
alongside any other installed theme. Switching themes does not require a
restart.

The repository also ships `theme-switcher.sh` for changing the Virtual☆Paradise
palette from a terminal (`theme-switcher.sh list` shows the variants,
`theme-switcher.sh reset` restores the original palette). These are **accent
variants**: they recolor the theme chrome, terminals and GTK, but the bar
widget accents, wallpaper, Plymouth and SDDM art stay cyberpunk until a full
variant pack lands. Switching from the settings panel also restarts the shell
so the QML surfaces pick up the new accent immediately. `theme-switcher.sh
wallpaper` derives the accent and its two companions from the current
background image instead of a fixed variant.
It is a terminal tool, not bound to a key. Two opt-in timers are installed but
left disabled:
`paradise-variant-by-time.timer` switches cyberpunk in the morning and
tokyo-night in the evening, and `paradise-wallpaper-rotate.timer` rotates the
live wallpaper hourly. Enable either with `systemctl --user enable --now <timer>`;
they do nothing until then.

### ✨ Visual Effects

The rotating gradient border, window shadow and glow ship enabled by default:
`borderangle`, `shadowangle` and `glowangle` in `hypr/looknfeel.lua` spin the
theme's cyan/green/pink ramp around every window edge and its spill. The
shell's own surfaces - bar, menu, popups, notifications, OSD and the lock
screen's password field - are frosted or rimmed by the same ramp, so their
translucent fills show the wallpaper as soft light instead of flat colour.
The scripts below are optional extras on top of that:

- **Rainbow Borders** — `effects.sh rainbow`
- **Glow Effect** — `effects.sh glow`
- **Toggle Blur** — `effects.sh toggle-blur`
- **Window Shake** — `effects.sh shake`
- **Screensaver modes** — `screensaver.sh matrix|starfield|miku`

The theme also has a voice: `vp-sound.sh` plays five short synth blips on
login, lock, unlock, an error shake and a notification. One flag file mutes
them all (`touch ~/.local/state/virtual-paradise/sound-off`).

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
- Preserves a customised `shell.json` unless `--force-shell-layout` is passed

### 🛡️ Override Layer

Third-party plugins are patched in-place to follow the theme palette. The override layer:

- Records every file it touches in a state file
- Reverts cleanly with `git checkout`, a pristine backup for non-git plugins, or deletion
- Reapplies after every plugin update
- Resolves versioned `runtime/<hash>/` paths from `manifest.json`
- Leaves the theme automatically when you switch away, restoring the stock plugins

A user-owned post-update hook verifies the island bar, repairs it from a
user-owned copy when possible, re-applies overrides and the bar layout, and
checks the theme timers. If repair is impossible, Omarchy's built-in
`activeBarId` fallback uses the stock bar instead of leaving you with none.

This means your theme survives `omarchy update` and `omarchy plugin update`
without manual intervention.

---

## 📸 Screenshots

> **Coming soon.** The previous screenshot showed a live session and was removed from the repository to reduce size. New screenshots will showcase the floating island bar, live wallpaper transitions, and terminal rice layout.

---

## 📦 Install

### Requirements

- **Arch Linux** (Omarchy 4.5+)
- **Hyprland** (Wayland compositor)
- **Quickshell** (status bar framework)

Optional:
- **NVIDIA GPU** (for nvidia-smi in Vitals widget)
- **Sudo access** (for Plymouth/SDDM, hardware drivers)

### Quick Install

```bash
git clone https://github.com/vuhuudo/virtual-paradise.git
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
| `./install.sh --boot-only` | Install only the Plymouth/SDDM boot themes (requires sudo) |
| `./install.sh --no-autologin` | Show the SDDM login screen instead of auto-login |
| `./install.sh --hook` | Re-apply overrides and the bar layout (for scripts) |

The installer is **idempotent**: run it as many times as you want. It will only update what changed.

### What Gets Installed

| Component | Location | Description |
|-----------|----------|-------------|
| Theme | `~/.config/omarchy/themes/virtual-paradise/` | Colors, icons, GTK CSS |
| Bar | `/usr/share/omarchy/shell/plugins/__USER__.island-bar/` | Floating island bar (first-party) |
| Plugins | `~/.config/omarchy/plugins/` | 12+ themed widgets |
| Hyprland | `~/.config/hypr/` | Animations, window rules, keybindings |
| Terminal | `~/.config/ghostty/`, `~/.config/alacritty/`, etc. | Terminal themes plus the hex spotlight |
| Tool themes | `~/.config/yazi/`, `~/.config/bat/themes/`, `~/.config/tmux/` | Yazi, Bat and tmux palettes (restored on uninstall) |
| Plymouth | `/usr/share/plymouth/themes/virtual-paradise/` | Boot splash; selected in `/etc/plymouth/plymouthd.conf` (if sudo) |
| SDDM | `/usr/share/sddm/themes/virtual-paradise/` | Login theme; selected in `/etc/sddm.conf.d/zz-virtual-paradise-theme.conf` (if sudo) |
| Systemd | `~/.config/systemd/user/` | Plugin update timer, audio watchdog |

---

## ⚙️ Configuration

### Keybindings

| Shortcut | Action |
|----------|--------|
| `SUPER + ALT + Q` | Launch rice layout (btop, cava, matrix, fastfetch) |
| `SUPER + ALT + W` | Toggle live/static wallpaper |
| `SUPER + ALT + N` | Next live wallpaper |
| `SUPER + ALT + SHIFT + N` | Previous live wallpaper |
| `SUPER + ALT + C` | Toggle cooler boost (laptop fan) |
| `SUPER + SHIFT + K` | Cast screen (wireless display) |
| `SUPER + Q` / `SUPER + W` | Close the window with the red glitch death |
| `SUPER + SHIFT + R` | Reload Hyprland config |
| `SUPER + R` | Resize mode (H/J/K/L or arrows, ESC/RETURN to exit) |
| `SUPER + BACKSLASH` | Matrix screensaver |

Omarchy's own bindings are used as-is, with one deliberate exception:
`SUPER + Q` / `SUPER + W` keep Omarchy's close mapping but run the theme's red
glitch death. `SUPER + CTRL + T` opens the theme menu, `SUPER + SHIFT + F` is the file
manager, `SUPER + SHIFT + B` the browser, `SUPER + CTRL + L` locks the system,
`SUPER + CTRL + E` opens the emoji picker, and `SUPER + CTRL + SPACE` / `W`
opens the background switcher. `SUPER + RETURN` opens the terminal, `SUPER + K`
lists keybindings, `SUPER + F` is fullscreen, and so on.

The theme only adds bindings on free chords, because Hyprland runs *every* bind
for a chord — a duplicate performs both actions. Apart from the close pair, it
no longer unbinds or shadows an Omarchy default, including the
`SUPER + ALT + ←` / `→` group move.

### The Login Screen and the Boot Splash

The SDDM greeter continues the Plymouth splash: the same cyber backdrop, the
same centred still of the animation and the same neon frame, with a wide neon
password panel in front of it. Plymouth plays the same artwork while booting
and while shutting down, and the whole picture fades in, so the handover is a
transition rather than a cut.

The same artwork is used for the **session splash**: between the greeter
handing the screen to the session and the desktop having something to show
(about three seconds), the glitch curtain - the same one the live wallpaper
switch plays - runs over the theme's picture and fades out as soon as the
shell is up, instead of a black screen. The frame stays centred while the
curtain tears it horizontally across the screen, and three nested signal
blocks (black, cyan, violet) roam the screen with thin neon scanlines and
scattered data fragments. Every hop re-rolls the nesting, tilt and edge
colour, so the blocks read as fresh signal damage instead of one repeating
cascade.

The password prompt in Plymouth sits *below* the picture, in the bar under the
neon frame, so it never covers the animation.

Switching the live wallpaper plays a glitch curtain, and the same curtain is
available for the way out:

```bash
transition.sh logout      # curtain, then the login screen
transition.sh reboot      # curtain, then Plymouth
transition.sh shutdown    # curtain, then Plymouth
```

The three actions are in the Omarchy menu under the theme's Quick Actions
("Log out with transition", "Reboot with transition", "Shut down with
transition").

Two things are worth knowing:

- **Omarchy logs in automatically**, so the greeter is on screen for less than
  a second. `./install.sh --sddm-only --no-autologin` (or
  `sudo ./install.sh --no-autologin`) turns that off so the login screen is
  really shown; `uninstall.sh` puts the automatic login back. With more than
  one account the greeter adds a chip per user above the password panel and
  preselects the last login; picking another account clears the typed
  password before it can be sent.
- **The splash only changes after the boot image is rebuilt.** The installer
  rebuilds it (both `limine-mkinitcpio` and `mkinitcpio -P` are tried, the
  output is shown and the result is checked), but a machine that boots a
  unified kernel image from Limine needs the UKI rebuilt - if the installer
  says the boot image was not updated, run `sudo limine-mkinitcpio` by hand
  and reboot.

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

### Speed

The theme is tuned so that logging in and switching themes stay snappy:

| What | Where it lives | Why it is fast |
|------|-----------------|----------------|
| Wallpapers (~95 MB of video) | `~/.config/omarchy/backgrounds/virtual-paradise/` | Omarchy stages the whole theme on every switch, so the videos stay out of the theme directory |
| Wallpaper previews | still images only | ImageMagick picks the bar's text colour from the wallpaper — an animated GIF meant 250 frames per switch |
| Terminal banner | `~/.cache/virtual-paradise/banner.txt` | Rendered once per theme, printed from the shell instead of starting Python |
| Plugin state | read once per theme change | Only the plugins whose state actually differs are touched |
| Boot animation | 1600×900 palette PNGs | A third of the image data in the initramfs, same picture on screen |

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
paradise-plugin-update --apply  # Revert, update, reapply, pin
```

The `paradise-plugin-update` wrapper:
1. Reverts all theme overrides
2. Runs `omarchy plugin update`
3. Reapplies overrides from the theme
4. Records the new state

This ensures your theme survives upstream changes.

`paradise-plugin-update --verify` compares every plugin checkout with the
recorded revision and exits non-zero on drift, so a timer or CI job can catch a
plugin that moved without a recorded review.

### Diagnostics

When something is wrong, the built-in report collects the system, repository,
XDG paths, theme and plugin state, boot time and recent shell errors. It is
read-only, needs no sudo, and never changes your configuration:

```bash
./install.sh diagnose             # print the report
./install.sh diagnose --output ~/vp-report.txt
./install.sh diagnose --upload    # review, then upload to 0x0.st
```

### Bar Effects

The gap stream, the rim scanner and the hover chrome are opt-out. Add the keys
under `bar` in `~/.config/omarchy/shell.json`; the installer and theme hooks
preserve a file you have edited.

```json
{
  "bar": {
    "gapEffects": false,
    "hoverGlow": false,
    "reducedMotion": true
  }
}
```

`gapEffects` controls the comet stream that crosses the gaps, freezes the hex
underlay's drift and stops the scanner spark that laps the bar's outer rim.
`hoverGlow` controls the lit hover pill: the rotating ramp rim, the hex
shimmer, the ramp-sampled bloom and the scale pop. Setting `gapEffects` to
`false` also turns off the hover chrome, so the bar can be made completely
still with one key.

`reducedMotion` keeps the same colours and chrome but stops cosmetic travel:
the rim gradient and the two gap canvases become still, and the hover pulse
and pop are skipped. The two gap effects also share one 16 ms frame clock
instead of running a timer each, so an idle bar wakes the shell once per frame
rather than twice. `VP_REDUCED_MOTION=1` in the shell's environment does the
same when a key cannot be added.

The shipped layout keeps the islands balanced: indicators only take space
while one is active, the active-window label is capped at 180px, and the right
island carries the five essentials (tray, network, audio, power, updates) plus
the Tools button. Clicking the clock opens the calendar; the world clock sits
in the same dropdown - one zone per city, probed with its own TZ so DST follows
the system - and the cities come from `worldZones` on the clock entry
(defaults: Tokyo, London, New York).

The Tools dropdown is the home of the specialized plugins: X-Ray,
OmaProton VPN, webcam controls, display config, projector cast and Bluetooth
audio. Voice dictation stays on the centre bar's Dictation indicator (and
`ALT + SPACE`). The plugin widgets stay enabled and mounted with
`"hidden": true`, so
their services keep running and their panels open from the bar when selected;
the hidden entries take no space in the row. Move one back into the visible
row by removing `"hidden": true` from its entry in `shell.json` (or via
`omarchy bar put`).

### Settings Panel

Open **Tools** on the bar and press the gear to switch the dropdown to settings.
The panel writes every change through `vp-setting.sh` (flock + same-directory
atomic replace) to `~/.config/omarchy/shell.json`, and the shell reloads it
live:

- **Appearance**: gap effects, hover glow, reduced motion, accent variant
  (Cyberpunk, Catppuccin, Tokyo Night, Gruvbox, Nord, Everforest, Kanagawa,
  Rosé Pine, Hackerman, Dracula, Mono, Neon), live wallpaper, UI sound. The
  variants recolor the chrome, terminals and GTK; the bar widget accents and
  artwork stay cyberpunk for now.
- **Weather**: automatic location consent, with the same privacy default as the
  weather panel.
- **System**: run `diagnose`, verify pinned plugins, repair the island bar from
  the post-update hook, and follow the user journal.

The panel is also reachable from scripts:

```bash
omarchy-shell doe.tools settings
omarchy-shell doe.tools close

# Scriptable toggles (open settings first for the verify action)
omarchy-shell doe.tools setBar gapEffects false
omarchy-shell doe.tools verify

# The same write path, without the panel
vp-setting.sh get bar.gapEffects
vp-setting.sh set weather.autoLocation true
```

### Weather Location

The weather panel never guesses your location on its own. With no city set, it
shows a one-time choice instead of a forecast:

- **Use my location** lets wttr.in approximate the location from the request
  IP and remembers the choice as `"autoLocation": true` on the weather entry.
- **Set city** opens the search field and stores the name plus coordinates;
  that request carries coordinates, not a guess, so it works without the
  consent.

Both paths stay in the same panel and the bar shows `—` until one is chosen.
A city you set always wins over auto-detection.

### Accessibility

The six theme bar widgets expose a screen-reader name, role and description
(clock, weather, CPU temperature, microphone, menu, tools), and the panels
name their fields and buttons. `reducedMotion` above removes cosmetic travel
without removing the effects, and the SDDM greeter labels the password field
for the selected account.

### Memory

Every effect is still here; the memory cost was moved off the always-resident
path instead:

- The window-close burst lives in a `doe.window-death` overlay inside the main
  shell. It used to be a second `quickshell` process kept warm (~180 MB PSS).
- The lock screen preview and its Sleeping Miku GIF are created only while the
  lock or preview is visible.
- The terminal ships no background image: the hex grid exists only inside the
  cursor spotlight, whose lattice is painted once into an offscreen canvas and
  blitted per frame (~0.3ms), so a terminal decodes nothing and the spotlight
  costs a texture blit per cursor frame.
- The pointer feed is shared: `vp_cursor_track.py` and `vp_window_track.py`
  are one server each per session (the second plugin to start one finds its
  socket taken and exits) and both overlays read the broadcasts, so the
  pointer glow and the hex spotlight cost two Python processes instead of
  four. The cursor feed also idles down to a slow poll after ~2s of stillness
  and snaps back the instant the pointer moves.
- The pointer glow and the edge flash only map their fullscreen layer
  surfaces while they are actually visible; between flashes they hold no
  buffer at all.
- The CPU-temperature widget resolves its thermal zone once and reads one
  file per tick, and asks the fan detector every 30s instead of every 1.5s,
  so the bar no longer spawns a sensor sweep and a vendor probe four times a
  second.
- The transition curtains poll at 120ms instead of 30ms. The curtain holds
  for its minimum-visible floor regardless, so this is invisible; it removes
  hundreds of short-lived process spawns at login and on each wallpaper
  switch.
- The clock's calendar popup is built the first time it is asked for; a
  session that never opens it never pays for the month grid.
- The wallpaper rides Omarchy's own background engine (it renders video
  itself since 4.5) instead of a second `mpvpaper` decoder - the two engines
  together held ~360 MB of RSS for the same frames.
- The third-party notification bell is retired. Omarchy 4.5's own service
  (grouped stacks, inline actions, DND, history, keybinds) owns notifications
  now; the old watcher leaked one `inotifywait` process per shell reload - 121
  orphans holding ~285 MB of RSS before the cleanup.
- The theme's overlay plugins are disabled when the theme is left and removed
  on uninstall, so they do not linger in another theme.

On the development machine the theme's resident PSS dropped from ~836 MB to
~490 MB at login, settling around ~450 MB once the caches warm, with the same
bar, effects, terminals and lock screen. The two shared Python servers (the
cursor feed and the window feed) add ~9 MB together. Check the live number
with:

```bash
ps -o pid,rss,args -C quickshell
```

### Disabling Components

**Disable live wallpapers:**
```bash
~/.local/bin/toggle_live_wallpaper.sh stop
```
To stop it starting at login, remove the `toggle_live_wallpaper.sh init` line
from `~/.config/hypr/autostart.lua`.

**Disable plugin update timer:**
```bash
systemctl --user stop paradise-plugin-check.timer
systemctl --user disable paradise-plugin-check.timer
```

**Enable or disable wallpaper rotation / day-night variant:**
```bash
systemctl --user enable --now paradise-wallpaper-rotate.timer
systemctl --user enable --now paradise-variant-by-time.timer
systemctl --user disable --now paradise-wallpaper-rotate.timer
systemctl --user disable --now paradise-variant-by-time.timer
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
6. Leave a snapshot in `~/.local/state/virtual-paradise/uninstall-backup-<timestamp>/`

The installer also places a self-contained copy at
`~/.local/bin/uninstall-virtual-paradise`. It runs the libs and payload
mirrored under `$XDG_DATA_HOME/virtual-paradise`, so it can remove the SDDM and
Plymouth themes and restore the shell config even after the repository is gone.
A custom `shell.json` is preserved instead of being replaced by a guessed
default.

### Uninstall Flags

| Flag | Description |
|------|-------------|
| `--keep-backups` | Keep `shell-default.json` and the snapshot dir |
| `--purge-defaults` | Also delete `shell-default.json` (irreversible) |

---

## 🔧 Development

### Running Tests

The test suite has thirty test cases and 533 assertions; optional tools
(`shellcheck`, `qmllint`, `hyprctl`) enable extra checks when present, so the
exact count varies between machines (533 with `shellcheck` and `qmllint`). It
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
- **TC-15**: Hyprland config permissions (the compositor can read every file)
- **TC-16**: Boot and login performance (no wallpapers in the theme, cached banner)
- **TC-17**: Shell layout ownership (custom `shell.json` survives a round-trip)
- **TC-18**: Post-update repair hook (bar repair, host fallback, no layout rewrite)
- **TC-19**: Stability guards (no tray patch, unit conditions, plugin fallback)
- **TC-20**: Hover glow (effect ships, follows the toggle, hides while dragging)
- **TC-21**: Island chrome and gap effects (hex underlay, glass fill, comet stream)
- **TC-22**: Rotating gradient chrome (bar rim, bloom and menu border share one spin)
- **TC-23**: Hover chrome (rotating rim, ramp bloom, hex shimmer, lazy loader)
- **TC-24**: Bar border chrome (scanner spark, inner hairline, ramp aura, no spacer)
- **TC-25**: Terminal hex spotlight (plain glass, cached lattice blit, grid anchoring)
- **TC-26**: Cooler Boost state (hardware read, file fallback, stale-state toggle)
- **TC-27**: Shared cursor server (one process for both overlays, socket handoff)
- **TC-28**: Fork drift, 4.5 parity (indicators, WallClock, titlebar colour, retired bell) and the documented tree
- **TC-29**: Motion, privacy, accessibility and multi-user login (shared frame clock, reduced motion, weather consent, screen-reader labels, SDDM account chips)
- **TC-30**: Settings panel and UI sound (bar options, weather consent, diagnose/verify/repair/logs, `vp-sound.sh toggle`)

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
│   ├── bat/              # Bat syntax theme (VirtualParadise.tmTheme)
│   ├── editor/           # VS Code theme
│   ├── terminal/         # Ghostty, Alacritty, Foot, Kitty configs
│   ├── tmux/             # tmux status bar palette
│   └── yazi/             # Yazi file manager palette
├── fastfetch/            # Fastfetch config and anime logo
├── hypr/                 # Hyprland config (animations, keybindings, rules)
├── lib/
│   ├── file-ops.sh            # Backup/restore helpers
│   ├── install-helpers.sh     # Logging, privilege, sync and backup helpers
│   ├── omarchy-env.sh         # Omarchy environment resolution
│   ├── plugin-overrides.sh    # Override layer implementation
│   ├── shell-layout.sh        # Three-way shell.json ownership rules
│   ├── post-update-hook.sh    # Bar repair and override re-apply after updates
│   ├── plymouth.sh             # Plymouth theme install/remove/legacy repair
│   ├── sddm.sh                # SDDM theme install/remove/legacy repair
│   ├── step-boot.sh           # SDDM/Plymouth/UKI install step
│   ├── step-plugins.sh        # Plugin sync/enable/override step
│   ├── step-shell.sh          # Shell rc, window rules and fcitx step
│   ├── system.sh              # Hardware detection
│   └── theme-set-hook.sh      # Theme-set hook (extracted from install.sh)
├── micro/                # Micro editor theme
├── overrides/            # Plugin overrides (QML patches)
├── plugins/              # Theme plugins (widgets, panels, overlays, services)
├── plymouth/             # Plymouth boot splash (standalone, self-contained)
├── sddm/                 # SDDM login theme (standalone, self-contained)
├── shell/                # shell.json template, zshrc
├── sounds/               # Login/lock/unlock/notify/error blips
├── systemd/              # Systemd unit files
├── tests/                # Test suite
├── theme/                # colors.toml, shell.toml, GTK CSS
├── tools/
│   ├── check-bindings.py        # Duplicate/shadowed binding check
│   ├── check-upstream-drift.py  # Fork-vs-upstream hash check
│   ├── shrink-history.sh        # Git history cleanup
│   └── convert-gifs-to-mp4.sh   # Wallpaper compression
├── install.sh            # Installer
├── uninstall.sh          # Uninstaller
├── VERSION               # Semantic version (1.4.0)
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
- **Cava** — Audio visualizer
- **btop** — Resource monitor
- **Fastfetch** — System info

Special thanks to the Omarchy community and r/unixporn for inspiration.

---

<div align="center">

**Made with 💜 for the Omarchy community**

[Report Bug](https://github.com/vuhuudo/virtual-paradise/issues) • [Request Feature](https://github.com/vuhuudo/virtual-paradise/issues) • [Discussions](https://github.com/vuhuudo/virtual-paradise/discussions)

</div>
