# Changelog

All notable changes to Virtual☆Paradise are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com); commit messages follow
Conventional Commits.

---

## [Unreleased]

## [1.2.1] — 2026-10-19

### Fixed
- **The installer no longer aborts when `rsync` is missing.** `rsync` is in the
  package list, but a `--user-only` run, a container or a non-Omarchy distro may
  not have it. The theme, `bin/` and plugin copies now fall back to `cp -a`
  (the theme copy used to fail and still print the success banner).
- **The test suite now runs as root.** `systemd-analyze verify --user` prints
  "Failed to lookup RuntimeDirectory path" / "Failed to initialize manager" when
  there is no user systemd manager (systemd 262; systemd 255 stays quiet), and
  TC-2 called `po_apply_all`/`update-plugins.sh` without the shim `PATH`, so it
  needed a real `/usr/bin/omarchy` on the host. Both are environment noise, not
  theme defects.
- **The Arch CI job installs `rsync` and `diffutils`**, and every failing
  assertion is now published as a check-run annotation, so a red run can be
  diagnosed through the public API without a repository token.
- **`install.sh --user-only` is now honoured even when running as root.**
  `EUID == 0` used to imply "sudo is available", so the flag was ignored and a
  user-space install wrote real `/etc/udev` rules, `/usr/lib/systemd` units and
  SDDM/Plymouth themes. The Arch CI job runs the suite as root inside a
  container, which is why Ubuntu passed and Arch failed the same tests.
  `run_privileged` now refuses immediately when `--user-only` was requested.
- **CI was red on every push since v1.2.0** (all three jobs). The lint job
  failed on `install.sh`, and the Ubuntu and Arch jobs failed because TC-1 runs
  shellcheck too:
  - `bin/effects.sh` was a shell script with twelve hyprlang lines (`bezier = …`,
    `animation = …`) pasted at the top and no shebang, so running
    `effects.sh rainbow` printed a dozen "command not found" errors first.
    The animations now live only in `hypr/looknfeel.lua`.
  - `bin/theme-switcher.sh`: `echo "Available: ${!VARIANTS[@]}"` mixed a string
    with an array (SC2145) plus three masked `local x=$(…)` assignments.
  - `install.sh`: the `--dry-run` flag set a variable nothing read, and a retry
    loop's counter was unused. `--dry-run` is gone — it now says so and exits 2
    rather than looking like a preview while installing for real.
- The lint job no longer tolerates `bin/*.sh` with `|| true` (it hid real
  errors), and lints `tests/*.sh` as well; TC-1 checks the same file list.
- The Arch CI job installs `foot` and `lua` so the `foot --check-config` and
  `luac -p` validators run on a second machine instead of self-skipping — that
  is what would have caught the foot 1.28 rename before a user did.
- **Hyprland config errors** (`hyprctl configerrors` is now empty):
  - `hypr/bindings.lua`: the resize submap used the retired hyprlang strings
    (`"submap, resize"`), which the Lua config executes as a shell command, so
    the submap never opened. Rewritten with `hl.dsp.submap` /
    `hl.define_submap` and native `hl.dsp.window.resize` dispatchers.
  - `hypr/looknfeel.lua`: `floating` is not a window-rule matcher (it is
    `float`), `shadow_offset` / `shadow_range` are decoration options rather
    than rule fields, `dim_around` is a boolean rule, and `windowsResize` is
    not a valid animation leaf. All four produced entries in Hyprland's
    config-error overlay.
- **Terminal configs**: `ghostty.conf` declared three fields Ghostty does not
  have (`cursor-click-to-place`, `letter-spacing`, `line-height`) — Ghostty
  showed its "Configuration Errors" dialog on every start. `foot.ini` used the
  pre-1.28 `[colors]` section (now `[colors-dark]`/`[colors-light]`), plus the
  removed `protocols`/`uri-characters` options and a non-existent `center`.
- **Installer**: `po_apply_repo_overrides()` ended on a `grep -q … && po_log`
  list, so a correctly patched (or absent) file returned 1 and `set -e` aborted
  `install.sh` in the middle of the plugin step.
- **Installer**: plugin enablement right after `omarchy restart shell` could
  race plugin discovery and fail with "omarchy-shell is not responding" —
  including the Paradise Island Bar itself and the whole post-layout plugin
  block. All of them now retry for up to ~15s and report the underlying error
  when they finally give up.
- **Installer**: the Island Bar bundle now deploys *every* file under
  `bars/island-bar/` instead of a hard-coded four-file subset, so a component
  added to the bar cannot be left behind.
- `bars/island-bar/Bar.qml`: annotated the `PopupAnchor` flag-enum assignments
  so qmllint no longer flags valid runtime code.

### Added
- Test coverage for the above: `luac -p` on every Lua file, `ghostty
  +validate-config`, `foot --check-config` and `hyprctl configerrors` (each
  skipped when the tool/instance is unavailable). 89 checks with the optional
  linters installed, 88 without `shellcheck`.
- `CHANGELOG.md` — this file
- `SECURITY.md` — vulnerability reporting policy
- `tools/convert-gifs-to-mp4.sh` — optional background compression (~60 MB savings)

### Changed
- `.gitignore` expanded: editor swap files, shell bytecode, test sandboxes
- CI workflow name corrected to reflect the full TC-1..TC-9 matrix (was TC-1..TC-5)

---

## 1.2.0 — 2026-10-18

### Added
- **Theme Variants**: 5 color schemes with live switching (cyberpunk, cozy, monochrome, neon, sakura)
  - `bin/theme-switcher.sh` — interactive variant selector with fzf support
  - Automatic reload of Hyprland, terminals, GTK, and widgets
  - Custom variant support via `VARIANTS` array
- **Floating Desktop Widgets**: eww-based widgets with toggle controls
  - `bin/widgets.sh` — clock, system stats, weather widgets
  - Auto-generated configs on first run
  - Individual widget toggle or all-at-once
- **Visual Effects Suite**: enhanced animations and feedback
  - `bin/effects.sh` — rainbow borders, glow effect, blur toggle, shake animation
  - Focus pulse animation on window change
  - Non-blocking continuous effects support
- **KEYBINDINGS.md**: comprehensive keybinding documentation
  - New bindings: `SUPER + SHIFT + T` (theme switcher), `SUPER + W` (widgets), `SUPER + SHIFT + E` (blur toggle)
- **README.md**: updated with new features section and usage examples

### Changed
- Bumped version to 1.2.0 (minor release with new features)
- Enhanced README with visual effects and widget documentation

---

## 2026-10-12

### Fixed
- **Uninstall**: revert-then-uninstall is now lossless — every override the layer
  recorded is restored to its upstream content, and created files are removed
  (`fa41286`).
- **Wallpaper cycle**: `get_live_items` now emits one entry per line so `mapfile`
  sees all 7 wallpapers instead of just the last (`e9cfb2a`).

### Tests
- TC-4 widened to cover the uninstall cleanup path (`a829019`).
- Test matrix count corrected in docs (`5ba0568`).

---

## 2026-10-10

### Added
- **Theme palette**: Miku Cyan set to `#00ffdd`, Neon Magenta to `#ff00ff`
  (`da6121f`).
- **Override layer**: projector-cast `Style.radius(6)` compat fix and accent
  colour patch (`3f5cf6d`).

### Changed
- **Bar**: rewritten as a floating three-island layout with neon hex backplate,
  gap glow, and transparent pills (`a340699`..`5247792`).
- **Theme payload**: only ships what Omarchy reads — `theme/`, `backgrounds/`,
  `overrides/`, `config/`, `hypr/`, `assets/`. Everything else is installed to
  its own place by its own step (`a0f1a7c`).
- **README**: rewritten to document the bar as it now is (`826fe50`).

### Fixed
- **Install**: survives `getent` failure on machines with non-standard NSS
  (`eda5725`).
- **Network/Bluetooth**: dropped the `height` binding that caused an infinite
  layout loop (`d378f47`).

### Reverted
- In-repo `doe.workspaces` and `doe.power` plugins — the upstream plugins are
  more maintainable than maintaining forks (`07b327f`, `3fa7c98`).

---

## 2026-10-09

### Added
- **In-repo bar** (`bars/island-bar/`): floating three-island Quickshell bar
  installed as a first-party plugin so `serviceFor()` resolves correctly.
  Replaces `omarchy.bar` and `mscurtescu.island-bar`.
- **Test suite** (`tests/`): 85 assertions across 9 cases, sandbox-isolated.
- **Override layer** (`lib/plugin-overrides.sh`): theme colours, QML rice and
  API compat fixes with full revert support.
- **CI** (`.github/workflows/test.yml`): runs the test suite on every push.
- **CONTRIBUTING.md** and conventional commit enforcement (`.githooks/`).
- **Plugin updater** (`bin/update-plugins.sh`): `--check`, `--apply`,
  `--rollback`, `--status`, `--pin`.
- **Systemd timers**: daily update check and audio watchdog.

### Changed
- **Refactor**: hardware detection and vendor setup extracted from `install.sh`
  into `lib/system.sh` (`cc03721`).
- **Shell scripts**: made shellcheck-clean at the warning level (`e868a27`).

---

## 2026-10-06 — Initial release

First public release of Virtual☆Paradise: a neon cyberpunk Omarchy desktop rice
with animated wallpapers, themed bar widgets, Plymouth/SDDM boot splash, and
full installer/uninstaller.

---

## Links

- [Unreleased]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.2.1...HEAD
- [1.2.1]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.2.0...v1.2.1
- [1.2.0]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.1.0...v1.2.0
- [1.1.0]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.0.0...v1.1.0
