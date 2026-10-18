# Changelog

All notable changes to Virtual☆Paradise are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com); commit messages follow
Conventional Commits.

---

## [Unreleased]

### Changed
- `.gitignore` expanded: editor swap files, shell bytecode, test sandboxes
- CI workflow name corrected to reflect the full TC-1..TC-9 matrix (was TC-1..TC-5)

### Added
- `CHANGELOG.md` — this file
- `SECURITY.md` — vulnerability reporting policy
- `tools/convert-gifs-to-mp4.sh` — optional background compression (~60 MB savings)

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
