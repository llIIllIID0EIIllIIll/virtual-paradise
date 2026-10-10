<div align="center">

```
██╗   ██╗██╗██████╗ ████████╗██╗   ██╗ █████╗ ██╗         ██████╗  █████╗ ██████╗  █████╗ ██████╗ ██╗███████╗███████╗
██║   ██║██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██║         ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║██╔════╝██╔════╝
██║   ██║██║██████╔╝   ██║   ██║   ██║███████║██║         ██████╔╝███████║██████╔╝███████║██║  ██║██║███████╗█████╗  
╚██╗ ██╔╝██║██╔══██╗   ██║   ██║   ██║██╔══██║██║         ██╔═══╝ ██╔══██║██╔══██╗██╔══██║██║  ██║██║╚════██║██╔══╝  
 ╚████╔╝ ██║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗    ██║     ██║  ██║██║  ██║██║  ██║██████╔╝██║███████║███████╗
  ╚═══╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚══════╝╚══════╝
```

### 🌸 Virtual☆Paradise
**A neon cyber-purple Omarchy desktop rice, with an in-repo floating island bar.**

*Built for Omarchy on Arch Linux · Hyprland · Quickshell · Wayland*

<br/>

[![Platform](https://img.shields.io/badge/Arch_Linux-Omarchy_4.0+-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Compositor](https://img.shields.io/badge/Hyprland-Wayland-00f5d4?style=for-the-badge&logo=wayland&logoColor=black)](https://hyprland.org)
[![Palette](https://img.shields.io/badge/Palette-%230f081d_deep_violet-ff5287?style=for-the-badge)](#-palette)
[![License](https://img.shields.io/badge/License-MIT-ffe066?style=for-the-badge)](LICENSE)

<br/>

<p><em>Preview coming soon — the previous screenshot showed a live session and
was removed from the repository.</em></p>

</div>

---

## Contents

- [What this is](#what-this-is)
- [The bar](#the-bar)
- [Palette](#palette)
- [Plugins](#plugins)
- [Keybindings](#keybindings)
- [Install](#install)
- [Uninstall](#uninstall)
- [Updating plugins](#updating-plugins)
- [Repository layout](#repository-layout)
- [How the override layer works](#how-the-override-layer-works)
- [Tests](#tests)
- [Troubleshooting](#troubleshooting)

---

## What this is

A themed desktop configuration for [Omarchy](https://omarchy.org): a Hyprland
session on Arch with a Quickshell status bar. It installs a theme, a set of bar
widgets, Hyprland configuration, live video wallpapers, and an optional
Plymouth/SDDM boot splash.

Two pieces are maintained **in this repository** rather than pulled from
upstream, because upstream could not do what they needed:

| In-repo | Why |
| :--- | :--- |
| `bars/island-bar/` | A floating three-island bar. Third-party bars get a scoped plugin shell where `serviceFor()` only resolves the bar's own id, so every service-backed widget silently reported "unavailable" over a healthy backend. Installing it as a **first-party** plugin in `/usr/share/omarchy/shell/plugins` hands it the real `ShellRoot`. |
| `overrides/` | QML patches for third-party widgets, reapplied after every plugin update. See [How the override layer works](#how-the-override-layer-works). |

Everything else is an existing Omarchy or community plugin, coordinated from
`install.sh`.

---

## The bar

```
┌─ left ─────────────┬──────────── center ────────────┬───────────── right ─────────────┐
│ quick menu         │  ╭─ waveform ─╮  weather        │ tray      bell      camera       │
│ 日本語 workspaces  │  │  clock      │  ╭─ Vitals ─╮    │ display   cast      bluetooth    │
│ active window      │  ╰─────────────╯  │ C 12% G 8%│   │ wifi      volume    battery 100% │
│                    │   temp  mic  indicators         │ projector audio     power       │
└────────────────────┴───────────────────────────────┴─────────────────────────────────┘
```

- **Islands** — left, center and right sit in their own rounded surfaces. The
  bar window itself is transparent, so the gaps between islands show the
  desktop. `bar.transparent` in `shell/shell.json` must stay `true`; setting it
  `false` paints an opaque strip through those gaps.
- **Icon colour** comes from `omarchy-bar-text-color`, which samples the
  wallpaper so icons stay legible against it.
- **Vitals** shows CPU and GPU inside its capsule. CPU is differenced from
  `/proc/stat`; GPU is polled from `nvidia-smi` every two seconds, because a
  proprietary NVIDIA driver publishes nothing through sysfs. The GPU label hides
  itself when no usable GPU is present.

---

## Palette

Defined in `theme/colors.toml` and `theme/shell.toml`. The gradient runs
**Miku cyan → hacker green → sakura pink** on a deep violet canvas.

| Colour | Hex | Used for |
| :--- | :---: | :--- |
| Cyber Dark Purple | `#0f081d` | Canvas: terminals, shell, panels, btop, editors |
| Miku Cyan | `#00f5d4` | Accent: active borders, focus rings, visualizer peaks |
| Sakura Pink | `#ff5287` | Urgent state, secondary gradients |
| Hacker Green | `#00ff88` | Cooler Boost active, success badges |
| Cyber Yellow | `#ffe066` | Charging, warnings, weather temperature |
| Sakura Pastel | `#ffb7d5` | Inactive widget text, open-panel ring |
| Warning Red | `#ff0055` | CPU overheat |

Widgets draw from this palette by literal hex, so re-theming means editing
`theme/colors.toml` **and** the `plugins/` widgets together.

---

## Plugins

| Plugin | Role | Source |
| :--- | :--- | :--- |
| `<user>.island-bar` | Floating three-island bar | **in-repo** `bars/island-bar/` |
| `io.github.erikburdett.wavebar` | CAVA waveform + MPRIS transport | [upstream](https://github.com/ErikBurdett/omarchy-wavebar) |
| `io.github.woogy7.vitals` | CPU/RAM/disk/net/**GPU**/sensors/processes panel | [upstream](https://github.com/Woogy7/omarchy-vitals) |
| `io.github.adamcbrewer.voxtype-aura` | Voice dictation HUD | [upstream](https://github.com/adamcbrewer/voxtype-aura) |
| `crmne.hyprmoncfg` | Multi-monitor layout and scaling | [upstream](https://github.com/crmne/omarchy-hyprmoncfg) |
| `ssupt.audio-control` | PipeWire mixer, device and volume curves | [upstream](https://github.com/ssupt/omarchy-audio-control) |
| `ssupt.bluetooth-audio` | Bluetooth routing and codec selection | [upstream](https://github.com/ssupt/omarchy-bluetooth-audio) |
| `io.github.jeffcortez23.omarchy-projector-cast` | Wireless display and presentation mode | [upstream](https://github.com/JeffCortez23/omarchy-projector-cast) |
| `jankeesvw.notification-center` | Notification drawer and DND | [upstream](https://github.com/jankeesvw/omarchy-notification-center) |
| `io.github.randazraik.xray` | System inspector: trace a window, process, service, container, port, file or device to the process behind it | [upstream](https://github.com/RandaZraik/omarchy-xray) |
| `io.github.grichard99.omaproton-vpn` | Proton VPN: one-click connect, world map, Kill Switch. Needs a Proton account; installs the `protonvpn` CLI on first use | [upstream](https://github.com/grichard99/omaproton-vpn) |

### In-repo bar widgets

Thirteen widgets under `plugins/` and `bars/` are authored here rather than
pulled from upstream, because the theme restyles the bar's own widgets and
Omarchy's copies read their colours from the host API:

| Widget | Replaces | Why it exists |
| :--- | :--- | :--- |
| `island-bar` | `omarchy.bar` | floating three-island layout, first-party so `serviceFor()` works |
| `workspaces` | `omarchy.workspaces` | Japanese numeral workspace switcher |
| `clock` | `omarchy.clock` | themed clock + date, panel |
| `weather` | `omarchy.weather` | themed weather pill |
| `network` | `omarchy.network` | themed network panel |
| `microphone` | `omarchy.microphone` | themed mic pill with dictation config |
| `menu` | `omarchy.menu` | themed launcher |
| `indicators` | `omarchy.indicators` | themed status indicators |
| `active-window` | `omarchy.active-window` | themed window title |
| `system-update` | `omarchy.system-update` | themed update indicator |
| `bluetooth` | `omarchy.bluetooth` | themed Bluetooth panel |
| `lock` | `omarchy.lock` | themed lock screen |
| `background` | `omarchy.background` | themed wallpaper picker |
| `power` | `omarchy.power` | battery level, charge state and profile switcher |
| `cputemp` | — | CPU temperature/fan pill, reads `cooler_boost_state` |

**Maintenance cost, stated plainly:** each is a fork of an Omarchy widget. When
Omarchy changes a widget's API or panel protocol, its copy here does not follow
automatically and must be updated by hand. The larger ones (`network` at ~2000
lines, `bluetooth` at ~1060) are the most exposed. There is no test that would
catch an Omarchy-side protocol change — only a visual one.

`install.sh` disables the stock widgets that these replace (`omarchy.bar`,
`omarchy.audio`, `omarchy.bluetooth`, `omarchy.workspaces`, `omarchy.power`,
`omarchy.memory`, `omarchy.monitor`) and re-enables them on uninstall.

---

## Keybindings

Defined in `hypr/bindings.lua`. Anything not listed here is an Omarchy or
Hyprland default.

| Shortcut | Action |
| :--- | :--- |
| `SUPER + Q` | Five-pane development layout |
| `SUPER + E` | File manager |
| `SUPER + B` | Web browser |
| `SUPER + N` | Next static background |
| `SUPER + ALT + UP` | Toggle live video wallpaper |
| `SUPER + ALT + LEFT` / `RIGHT` | Previous / next live wallpaper |
| `SUPER + ALT + C` | Toggle Cooler Boost |
| `SUPER + SHIFT + K` | Wireless display / cast |
| `SUPER + SHIFT + T` | Theme switcher |
| `SUPER + SHIFT + C` | Colour picker with hex copy |
| `SUPER + \` | Matrix screensaver |

Right-click the microphone widget to open the Voxtype dictation settings.

---

## Install

```bash
git clone https://github.com/llIIllIID0EIIllIIll/virtual-paradise.git
cd virtual-paradise
./install.sh
```

### Modes

| Command | Effect |
| :--- | :--- |
| `./install.sh` | Everything, including SDDM and Plymouth. Those need sudo; without it they are skipped with a warning rather than failing. |
| `./install.sh --user-only` | Everything except the privileged steps. No sudo needed. |
| `./install.sh --no-boot` | Skip Plymouth and SDDM, keep the rest |
| `./install.sh --boot-only` | Only Plymouth/SDDM. Exits non-zero if it could not write them. |
| `./install.sh --hook` | Re-sync overrides and assets only. Silent; for scripted use. |

The installer is **idempotent** — run it as often as you like. It converges
after the first run: repeated runs produce no diff other than timestamped
backups, which are capped at the newest five plus your original pre-install
copy.

### What it needs

`sudo` is required for SDDM/Plymouth, fan-control udev rules and NVIDIA
persistence. Without it the installer skips those steps with a warning rather
than failing partway. `--user-only` never asks.

A custom `XDG_CONFIG_HOME` is honoured throughout.

---

## Uninstall

```bash
./uninstall.sh              # or: uninstall-virtual-paradise
```

| Flag | Effect |
| :--- | :--- |
| `--keep-backups` | Also keep `shell-default.json`. Implies you may want to reinstall later. |
| `--purge-defaults` | Delete `shell-default.json`. Irreversible. |

It switches to a fallback theme, restores `shell.json` from
`shell-default.json`, reverts every patched plugin file, removes the theme,
stops and deletes the systemd units, and removes the first-party bar from
`/usr/share` (needs sudo; it prints the command if it cannot).

Everything it deletes is snapshotted first, and it prints the path:

```
Uninstalled Virtual☆Paradise. Backup snapshot: ~/.local/state/virtual-paradise/uninstall-backup-<timestamp>
```

---

## Updating plugins

Third-party plugins are git checkouts, and patching them in place leaves every
checkout dirty — which a plain `omarchy plugin update` cannot fast-forward. Use
the wrapper instead:

```bash
paradise-plugin-update --check       # report only, touches nothing
paradise-plugin-update --apply       # revert overrides, update, re-apply, pin
paradise-plugin-update --status      # installed vs locked revisions
paradise-plugin-update --rollback    # return every plugin to its pinned SHA
paradise-plugin-update --revert-only # drop the override layer, for bisecting
```

`--apply` only rewrites the lockfile when every plugin updated successfully. A
partial failure keeps the previous pin and copies it to
`plugin-versions.lock.last-good`, so `--rollback` still has somewhere known-good
to go.

`--check` also warns when an upstream change touches a file the override layer
patches, since that override will need re-basing.

### Two timers

| Unit | Schedule | Does |
| :--- | :--- | :--- |
| `paradise-plugin-check.timer` | daily, 10:17 + up to 45 min jitter | Read-only update check; notifies only if something changed |
| `paradise-audio-watchdog.timer` | every 5 min | Restarts the audio-control backend if its socket stops answering |

The audio watchdog exists because the mixer panel cannot recover on its own: the
relay probes the socket only at startup, so once the daemon accepts a connection
and then wedges, every later panel load reconnects to the same dead socket and
reports "Audio service is unavailable" until the process is killed.

---

## Repository layout

```text
virtual-paradise/
├── assets/          Preview and unlock artwork
├── backgrounds/     Video loops and wallpapers
├── bars/island-bar/ In-repo floating bar, installed first-party to /usr/share
├── bin/             Helper scripts: rice layout, wallpaper, cooler boost, updater
├── cava/            Visualiser configuration
├── config/          GTK 3/4 CSS and terminal configs
├── fastfetch/       fastfetch profile and logo art
├── hypr/            Hyprland config: look'n'feel, input, keybindings, monitors
├── lib/             Sourced modules: plugin-overrides.sh (the override
│                    layer), system.sh (hardware detection and vendor setup)
├── tools/           Maintenance scripts (shrink-history.sh)
├── micro/           Micro editor theme
├── overrides/       QML patches applied to third-party plugin widgets
├── plugins/         First-party bar widgets cloned into the user namespace
├── plymouth/        Boot and shutdown splash assets
├── sddm/            Login theme
├── shell/           shell.json layout template
├── systemd/         User units for the update check and audio watchdog
├── tests/           Test suite (./tests/run.sh)
├── theme/           colors.toml, shell.toml and per-app theme config
├── install.sh
└── uninstall.sh
```

---

## How the override layer works

Omarchy themes cannot restyle a third-party bar widget, because widget QML
reads its colours from the host theme API rather than from CSS. So this repo
carries a small patch layer instead.

1. `lib/plugin-overrides.sh` writes our QML over the plugin's real files.
2. Files it touches are recorded in `~/.local/state/virtual-paradise/overrides.state`
   as either `modified` (tracked upstream, restore with `git checkout`) or
   `created` (our file, delete on revert).
3. `po_revert_all` walks that file and puts everything back.

Entry points are resolved through each plugin's `manifest.json`, not hardcoded.
This matters: `ssupt.audio-control` ships its QML inside a versioned
`runtime/<hash>/` tree, so an override copied to the plugin root would load
nothing at all and fail silently.

The layer is applied after every plugin add, because `omarchy plugin add` writes
fresh upstream files over anything already patched. That is why `install.sh`
calls it repeatedly rather than once at the end.

Because these are edits to upstream files, an override can bit-rotate when its
plugin updates. `--check` flags the overlap; re-basing means replaying your
change onto the new upstream file.

---

## Repository size

The wallpapers are large, and some early ones were committed and later
replaced. Git keeps every version forever, so `.git` carries roughly 146 MB of
media that no checkout can reach — a clone pays for all of it.

`tools/shrink-history.sh` reclaims it:

```bash
./tools/shrink-history.sh            # dry run, reports what would go
./tools/shrink-history.sh --apply    # rewrite history
```

It removes only blobs reachable from some commit but absent from the `HEAD`
tree, so **file contents at `HEAD` are untouched** — afterwards `git ls-tree -r
HEAD` is byte-identical, only the SHAs change. Measured on a clone: `.git` goes
from 266 MB to 134 MB.

Rewriting history changes every commit SHA. It is deliberately not part of
`install.sh`: it writes a safety bundle first, and publishing the result needs
a force-push. Everyone else must re-clone.

The remaining 134 MB is the current media itself. Converting the animated GIFs
to MP4 (`mpvpaper` plays both, and video is smaller) would cut roughly another
60 MB, but it changes the artwork, so it is left as a manual decision.

## Tests

```bash
./tests/run.sh              # everything
./tests/run.sh tc2 tc4      # selected cases
```

Runs against a throwaway `HOME` with a `PATH` shim directory, so it never
touches your real config, `/usr/share`, `systemctl` or `pacman`.

| Case | Covers |
| :--- | :--- |
| **TC-1** | Static checks: `bash -n` on every script, `py_compile`, JSON and TOML parse, `systemd-analyze verify` |
| **TC-2** | Override layer: entry-point resolution, versioned `runtime/<hash>/` targets, state file shape, revert |
| **TC-3** | Installer idempotency: three consecutive runs, no drift, capped backups, no unsubstituted `__USER__` |
| **TC-4** | Uninstaller: `shell.json` restored, theme and units gone, backup snapshot non-empty, flag precedence |
| **TC-5** | Custom `XDG_CONFIG_HOME`: every path follows XDG, nothing leaks into `~/.config` |
| **TC-6** | No pristine Omarchy layout: the default snapshot is never faked from our own theme |

CI runs the same suite on every push and pull request, and fails on any residue
the tests leave behind.

> TC-6 exists because of a bug it caught. With
> `/usr/share/omarchy/config/omarchy/shell.json` missing, the installer fell back
> to copying whatever `shell.json` it found — by then its own Paradise layout.
> `shell-default.json` ended up holding the rice, so `uninstall.sh` "restored"
> it. Every machine with a complete Omarchy install was immune; only CI saw it.

---

## Troubleshooting

**The bar is opaque and the islands look wrong.**
`bar.transparent` must be `true` in `~/.config/omarchy/shell.json`. A
reinstall restores it from the template.

**A widget says "Audio service is unavailable" but audio works.**
The bar is probably not running as a first-party plugin, so `serviceFor()` is
gated to the bar's own id. Check that
`/usr/share/omarchy/shell/plugins/<user>.island-bar/manifest.json` exists and
that `omarchy plugin list --json` reports it with `firstParty: true`. Requires
sudo to reinstall:

```bash
sudo ./install.sh --user-only
```

**The GPU label is missing from Vitals.**
It needs `nvidia-smi` on `PATH`. The label hides itself rather than showing a
dash when no GPU can be read. AMD and Intel are not wired up.

**Audio wedges after a few hours.**
That is what `paradise-audio-watchdog.timer` is for. Check it is running:

```bash
systemctl --user status paradise-audio-watchdog.timer
```

**A plugin update broke a patched widget.**

```bash
paradise-plugin-update --status     # find what drifted
paradise-plugin-update --rollback   # go back to the last good pin
```

**I changed `theme/colors.toml` and the bar widgets did not follow.**
They use literal hex from `plugins/*/`. Change both.

---

<div align="center">

Made with 💜 for the **Omarchy**, **Arch Linux** and **r/unixporn** communities.

[Back to top ↑](#-virtualparadise)

</div>
