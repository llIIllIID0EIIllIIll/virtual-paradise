# Changelog

All notable changes to Virtual☆Paradise are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com); commit messages follow
Conventional Commits.

---

## [Unreleased]

### Added
- **A settings/health view inside the Tools dropdown.** The gear switches the
  panel to the custom theme editor, accent variants, live wallpaper, UI sound,
  weather consent, and system actions (diagnose, verify pins, repair bar,
  logs). It shows the current variant and labels the variants honestly: they
  recolor the chrome, terminals and bar widgets; the wallpaper/Plymouth/SDDM
  artwork remains cyberpunk.
- **Custom theme editor.** The Appearance toggles are gone; the settings panel
  now exposes eight roles (Accent, Secondary, Tertiary, Warm, Pink, Urgent,
  Background, Text). Pick a role, then click a swatch on the visual color board
  (or type a hex). Every click applies live: `vp-palette.sh` writes
  `palette.json` immediately and the bar recolors without an Apply button or a
  shell restart. The terminal/GTK theme files are rewritten after a short
  debounce through `theme-switcher.sh custom`.
- **`vp-palette.sh`**, the atomic live-palette writer. It validates the eight
  hex colors, replaces `palette.json` under `flock` with a temp file, records
  the `custom` variant, and leaves no temp files behind. The bar polls the
  tiny file so an atomic replacement still recolors it within a tick.
- **Live palette plumbing for bar widgets.** `VpPluginBarApi` now forwards
  Accent, Secondary, Tertiary, Warm, Pink, Urgent and Foreground to every
  widget, and the bar only re-applies a palette when the JSON text changed, so
  a swatch click does not restart the color animations.
- **`vp-setting.sh`**, the atomic settings writer behind the panel. `get`/`set`
  support the bar booleans and weather auto-location; writes use `flock` and a
  same-directory replace so a shell reload cannot see a truncated `shell.json`.
- **Vietnamese quick-start guide** (`README.vi.md`), linked from the English
  README.
- **Release automation.** A `v*` tag now validates VERSION/CHANGELOG and
  publishes a GitHub release; `workflow_dispatch` runs the validation only.
- `vp-sound.sh toggle` mutes or unmutes every UI sound without touching the
  other sound events.

### Removed
- **Sakura and Cozy variants.** Their chrome clashed with the cyberpunk widget
  accents and neither had matching artwork; the Omarchy-derived palettes above
  replace them.

### Fixed
- **The power-manager no longer floods the journal.** Its idle poll logs an
  `IDLE DEBUG` line every five seconds; the tracked override layer now removes
  the log while keeping the status poll, and restores the line on theme leave.
- **Settings switches actually write.** The replacement bar's host facade
  refuses bar-level mutations, so the first panel implementation silently did
  nothing. The panel now calls `vp-setting.sh`; `omarchy-shell doe.tools setBar`
  works even with the panel closed.
- **Two quick variant switches could leave two bars.** `omarchy restart
  shell` spawned two supervisors when two calls raced the `quickshell -n`
  duplicate check. The settings panel now single-flights variant changes and
  calls `vp-restart-shell.sh`, a flocked wrapper; a second restart exits
  instead of spawning another shell.
- **Theme refresh no longer throws null-bar errors.** The audio-control panel
  binds every foreground/font read through a guarded fallback, and the
  Bluetooth panel's Connections target is coerced to null while the bar is
  rebuilt.
- **CI is stable again.** The Arch layout assertion derives the user prefix
  from the installed `shell.json` instead of an empty `USER`, the lint job
  skips `qmllint` when the Omarchy modules are absent (it looped on
  `network/Panel.qml`), and the shell-default assertion no longer races
  `pipefail` against `grep -q`.
- **Phase 2 editor tools.** Undo/Redo/Reset with `Ctrl+Z` / `Ctrl+Shift+Z`,
  WCAG contrast feedback for Text/Background, keyboard navigation on the role
  boxes and color board, and per-panel error reporting for palette writes.
- **Seed-based generation and vision preview.** A seed field plus
  Analogous/Complement/Triad buttons fill the companion roles, **BG / Text**
  derives a dark background and readable foreground, a live bar/terminal
  preview card shows the result, and Normal/Deutan/Protan modes preview all
  eight roles with simulated color-vision deficiencies.
- **Live terminal palettes.** `vp-terminal-palette.sh` sends OSC 4/10/11/12
  to writable pseudo-terminals; the panel passes `--terminals` after each live
  write, with a **Live terminal palette** toggle (default on) stored as
  `bar.liveTerminals`. `--dry-run` and `--list` make it testable without
  touching a real terminal.
- **Portable custom themes.** `vp-theme.sh save|list|load|export|import|delete`
  stores validated, versioned JSON under
  `~/.local/state/virtual-paradise/themes/`; the panel can save, load and
  import them without a shell restart.
- **Phase 1 stabilization.** Swatch writes are coalesced over 60 ms so rapid
  clicks cannot finish out of order, a variant switch cancels pending custom
  writes, palette input is validated per role, and `vp-palette.sh` skips an
  identical rewrite. Its state path now matches `theme-switcher.sh` even when
  `XDG_STATE_HOME` points elsewhere. See `ROADMAP.md` for the audit and the
  Phase 2 plan.

### Changed
- **The palette pipeline is ordered and shared.** `vp-palette.sh --seq` drops a
  write that lost the race to a newer one, `theme-switcher.sh` uses the same
  `palette.lock`, and the panel defers the shell-wide theme refresh until it
  closes so Undo/Redo is not torn down mid-edit. During editing the panel owns
  `palette.json`; the theme pass only rewrites text files.
- **The bar defaults are fixed:** gap effects on, hover glow off, reduced
  motion off. The three Appearance toggles were removed; the halo remains
  available through `"bar": {"hoverGlow": true}` for anyone who wants it.
- **Accent variants now mirror real palettes.** Catppuccin, Tokyo Night,
  Gruvbox, Nord, Everforest, Kanagawa, Rosé Pine Moon, Hackerman and Dracula
  replace the old Sakura/Cozy experiments. The semantic roles (`green`,
  `magenta`, `yellow`, `bg`, `blue`…) and the QML bar widgets follow the
  palette instead of keeping the cyberpunk accents.
- **The night timer uses Tokyo Night**, replacing the removed Sakura variant.
- Tests: 567 assertions; TC-12 covers the Omarchy palettes, multi-role custom themes and `palette.json`,
  TC-30 covers the settings panel, `vp-setting.sh` and the UI sound toggle.
- **Repository moved to `github.com/vuhuudo/virtual-paradise`.** Clone URLs,
  issue/discussion links, the license notice and the security-advisory link
  now use the new account name.

## [1.4.0] - 2026-11-10

### Added
- **Reduced motion.** `"bar": {"reducedMotion": true}` in `shell.json` (or
  `VP_REDUCED_MOTION=1`) keeps every effect and colour but stops the rim spin,
  both gap canvases and the hover pulse. An explicit `false` keeps the current
  motion, so the key is opt-in.
- **One shared bar frame clock.** The rim scanner and the gap stream used to
  own a 16 ms timer each, waking the event loop twice per frame for the same
  picture. Both now take the bar's single `frameTick`, and a component used
  outside the bar still runs standalone.
- **Weather location consent.** Auto-detection sends a request wttr.in turns
  into an approximate location, so it is now opt-in: with no city set the panel
  asks once ("Use my location" or "Set city") and the answer is stored as
  `"autoLocation": true` on the weather entry. The bar shows `—` until a
  location is chosen instead of the old placeholder `27°C`.
- **Screen-reader labels.** The six theme bar widgets expose a name, role and
  description; the clock and weather fields, the consent buttons and the SDDM
  password field are labelled too.
- **Multi-user login.** The SDDM greeter lists every account as a chip above
  the password panel, preselects the last login and clears a typed password
  when the account changes.

### Changed
- Tests: 508 assertions, including a new TC-29 for motion, privacy,
  accessibility and the multi-user greeter.

## [1.3.7] - 2026-11-10

### Added
- **`./install.sh diagnose`.** A read-only support report (system, git
  revision, XDG paths, theme/plugin state, plugin pin drift, boot time, recent
  shell errors) that needs no sudo and writes nothing. `--output FILE` saves it;
  `--upload` asks first, then sends it to `0x0.st`.
- **`paradise-plugin-update --verify`.** Compares each plugin checkout against
  the pinned lockfile and exits non-zero on drift, so a timer or CI job can
  catch an unreviewed plugin move.
- `qmllint` now covers every QML file in `bars/`, `plugins/`, `bin/` and
  `sddm/`, both locally and in CI, instead of the island bar only.

### Fixed
- **`./install.sh --hook` no longer performs a full install.** It used to skip
  only some steps: it still created directories, copied helper scripts, edited
  shell rc files and could prompt. It now applies the override layer and the
  bar layout, then exits.
- **`--boot-only` reports failure.** When neither the SDDM nor the Plymouth
  theme could be installed the script printed success and exited 0; it now
  warns and returns 1. A boot image that cannot be located after the rebuild is
  no longer reported as rebuilt.

### Changed
- Tests: 490 assertions, including the light `--hook` path, `--verify` drift,
  `--boot-only` failure and the diagnose report.

## [1.3.6] - 2026-11-10

### Fixed
- **Switching away from the theme gives the user their Fastfetch and GTK
  files back.** The theme-set hook overwrote `fastfetch/config.jsonc` and both
  `gtk.css` files without a backup and then deleted them on leave. It now backs
  up a non-theme copy before writing and restores it on leave; it only removes
  a file that still carries the theme's own styling.
- **A reinstall no longer deletes files the user added to the theme and
  wallpaper directories.** `rsync --delete` (and `rm -f *.gif`) treated the
  whole directory as theme-owned. A manifest (`.vp-files`) now records the
  files the theme shipped, so a user's wallpaper or theme file survives while
  a theme file removed upstream is still pruned. Only the theme's own GIFs are
  removed from the wallpaper directory.
- **The legacy monitor cleanup no longer matches a plain user rule.** It now
  requires the theme's full legacy signature (eDP-1 with `scale 1.0`,
  `transform 0`, `position 0x0`; an external output with `scale 1.0` and
  `auto-right`).
- **Uninstall restores `~/.bashrc`.** `configure_shell_file` edits it but only
  `~/.zshrc` had a backup path; the pre-theme `.bashrc` is now saved and put
  back.

### Changed
- **`shell.json` is written atomically.** The layout writers now emit to a
  same-directory temp file and rename it into place, so a crash or a full disk
  cannot leave a truncated shell layout.
- **One lock across install, theme switch and the plugin updater.** The
  override layer and the shell-layout writer share a reentrant `flock`, so a
  theme switch cannot revert the layer while an install applies it.
- Tests: 481 assertions.

## [1.3.5] - 2026-11-10

### Changed
- **The installer monolith is split into modules.** `install.sh` is now a thin
  orchestrator: logging, privilege and backup helpers live in
  `lib/install-helpers.sh`; the SDDM/Plymouth/UKI step in
  `lib/step-boot.sh`; the plugin sync/enable step in `lib/step-plugins.sh`;
  and the shell-rc/window-rule/fcitx helpers in `lib/step-shell.sh`.
  `install.sh` dropped from 2172 to 1324 lines with no behaviour change; the
  test suite follows the moved code and shellcheck still passes across the
  whole installer.

### Fixed
- **`sudo ./install.sh` now patches the user's plugins, not `/root`'s.** The
  override layer caches its config/state paths when it is sourced; it was
  sourced before the target user's home was resolved, so a plain sudo run sent
  every colour/null-bar/audio patch to `/root/.config` and left the real
  plugins untouched. The layer is now initialised after the user and
  `VP_CONFIG_DIR`/`VP_STATE_DIR` are known.
- **The installed uninstaller is self-contained.** `~/.local/bin/uninstall-virtual-paradise`
  was a lone copy of `uninstall.sh` that could not find `lib/sddm.sh` or
  `lib/plymouth.sh` (so the boot/login themes stayed installed) and, without
  `lib/shell-layout.sh`, overwrote a custom `shell.json` with a guessed
  default. The installer now mirrors the libs and the payload it needs into
  `$XDG_DATA_HOME/virtual-paradise`, installs a small wrapper, keeps a custom
  layout instead of guessing, and removes its payload only after the run has
  finished using it.
- **One bad package name can no longer drop the whole package transaction.**
  `visual-studio-code-bin` is AUR-only and sat in the official list, so a
  single `pacman -S` could fail and leave `rsync`, `ffmpeg`, `jq`, `fcitx5`
  and every other dependency uninstalled. Packages are now validated against
  the official repos, AUR-only names are moved to the AUR list, and a failed
  batch is retried one package at a time.
- **State/data paths honour `XDG_STATE_HOME` and `XDG_DATA_HOME`.** The override
  state and the uninstaller payload now follow the same XDG roots as the theme
  hook and updater; the sandbox tests set all three XDG variables so a run can
  no longer write into the real home.

### Tests
- Added regression checks for the override init order, the self-contained
  uninstaller payload/wrapper, custom-layout preservation, and XDG state
  handling (475 assertions).

## [1.3.4] - 2026-11-08

### Added
- **The session splash now keeps its picture centred.** The framed Miku still
  was positioned off to the bottom-right inside `session_base.png`; the asset
  is recomposed so the frame sits dead centre with the cyber backdrop around
  it, and the curtain tears it horizontally across the screen instead of
  sliding it into a corner.
- **The session glitch is built from nested signal blocks.** Three flat
  squares - black, cyan and violet - nest inside each other, and every hop
  re-rolls which corner the child sits in, how much it covers, whether it is
  tilted and the neon edge colour. Three clusters roam the screen for the
  whole splash, joined by thin neon scanlines and scattered data fragments,
  for a modern cyber look. The wallpaper-switch curtain keeps its old style;
  the session style is selected with `VP_TRANSITION_STYLE=session`.

### Changed
- **Plymouth fades in over ~0.2s instead of ~0.75s**, so the splash appears
  almost at once after the bootloader instead of leaving a dark screen.
- **Boot follow-ups keep the Limine menu selectable for 3 seconds** (the
  pre-4.5 value) while the theme's boot artwork matches the Plymouth backdrop.

### Performance
- **The CPU-temperature widget stopped polling the whole sensor tree and the
  fan detector every 1.5s.** The thermal zone is resolved once and read with a
  single cheap file read; the fan state is asked from the hardware every 30s
  and reconciled immediately on click. This was the heaviest recurring poll
  on the bar.
- **The pointer glow and edge flash unmap their fullscreen surfaces while
  invisible**, instead of holding one transparent layer surface per monitor
  for the whole session.
- **The shared cursor server idles down when the pointer is still**: it polls
  at cursor rate while moving and drops to a slow cadence after ~2s, snapping
  back the instant it moves. The broadcast is unchanged.
- **The transition curtains poll at 120ms instead of 30ms**, which removes
  hundreds of short-lived process spawns at login and on every wallpaper
  switch. The minimum-visible floor makes the cadence invisible.

## [1.3.3] - 2026-11-06

### Fixed
- **The third-party panels stop logging null-bar errors.** The bluetooth
  panel and its device rows read `bar`/`controller` colours before those
  objects are injected; the override layer now falls back to the palette,
  so a session no longer collects hundreds of type errors while the panels
  load. The lockfile revisions are unchanged.

## [1.3.2] - 2026-11-06

### Fixed
- **A plugin-enable pass can no longer shatter the bar layout.** Enabling a
  bar widget inserts it into its manifest's default section
  (`centerBegin`/`centerEnd`/`tray`); the theme layout only uses
  `left`/`center`/`right`, so after an install the sections were mixed and
  the bar rendered broken. The layout apply now recognises that signature as
  a scrambled bar rather than a user edit and re-applies the theme layout;
  TC-17 covers the repair.

## [1.3.1] - 2026-11-06

### Fixed
- **The panels no longer flood the journal with null-bar errors.** Theme
  panels and widgets that load before the bar injects itself read
  `bar.foreground` / `bar.fontFamily` / `bar.urgent` directly; the type
  errors fired thousands of times across a session. Every read now falls
  back to the palette (`Color.foreground`, `Style.font.family`,
  `Color.urgent`).
- **The indicator service bindings stopped looping.** Creating the service
  proxy while the `idleService` / `notificationService` binding evaluated made
  QML re-enter the binding; the indicators now fetch the proxy imperatively
  when the bar is injected. The active-window label is measured with
  `TextMetrics` instead of reading the elided label's own width.
- **The system transitions use the 4.5 command.** Omarchy 4.5 folded
  `omarchy-system-logout/reboot/shutdown` into
  `omarchy system <logout|reboot|shutdown>`; `transition.sh` was calling the
  removed binaries.
- **The stock Bluetooth widget stays off the theme bar.** Enabling
  `ssupt.bluetooth-audio` left `omarchy.bluetooth` enabled, and its entry kept
  reappearing in `centerEnd`; the hook disables it and the layout cleanup
  drops stale entries.
- **audio-control 0.9.1 loads again.** The update assigns `defaultSetBusy`
  on its row delegates without declaring the property, so the whole widget
  failed with "Cannot assign to non-existent property". The override layer
  declares it on both rows; the backend reader's destroyed-root guard and
  the bluetooth refresh guard are tracked overrides too.
- **The indicator toggles reach their services again.** The package bar
  facade gates the first-party service proxies (idle, nightlight,
  notifications, media, remote session) on the widget manifest carrying the
  "bar" kind, which no widget does, so Stay Awake, Night Light and Do Not
  Disturb did nothing when clicked. The theme bar resolves the narrow proxies
  itself (`VpPluginBarApi.firstPartyService`) and the indicators read state
  and toggle through it. The dictation indicator falls back to
  `voxtype status` when Omarchy's status wrapper is not installed.

### Changed
- **Third-party plugins updated to their latest revisions.** hyprmoncfg,
  voxtype-aura, omaproton, webcam, xray, audio-control, bluetooth-audio and
  harshith.system-monitor fast-forwarded with the override layer re-applied,
  and the lockfile pins the new revisions. Voxtype Aura stays off until the
  `omarchy-voxtype` package provides `omarchy-voxtype-status`; the theme hook
  turns it back on automatically once the helper exists.
- **The world clock moved into the clock's calendar dropdown.** Elsewhen's
  standalone panel - a sideways panel hanging off the right island - is
  retired. The clock dropdown now carries a world clock row under the
  calendar, one zone per city, each probed with its own TZ so DST follows the
  system clock. The default cities are Tokyo, London and New York; configure
  them with `worldZones` on the clock entry. The right island drops to the
  five essentials.
- **The bar is minimal again.** The overflow pager from the previous revision
  is gone: the crowded right island was mostly the centre island's eight
  always-on indicator slots, so indicators now take space only while one is
  active, the active-window label is capped at 180px, and the right island
  keeps the five essentials (tray, network, audio, power, updates) plus the
  Tools button. The specialized widgets - X-Ray, VPN, webcam, monitor config,
  projector cast and Bluetooth audio - stay enabled and mounted with
  `"hidden": true`, so their services keep running and their panels open from
  the bar, but they take no space in the row. The Tools dropdown gathers them
  into one button, with no horizontal stretch; voice dictation stays on the
  centre bar's Dictation indicator and on `ALT + SPACE`.
- **The third-party notification bell is retired.** Omarchy 4.5 ships its own
  notification service (grouped stacks, inline actions, DND, history and
  keybinds), and the third-party watcher leaked one `inotifywait` process per
  shell reload - 121 orphans holding ~285 MB of RSS. The installer, the
  theme-set hook and the uninstaller now remove the plugin and its stray
  watchers, and the stock service keeps the themed toasts, the DND indicator
  and the history keybinds.
- **The 4.5 indicators and clock land in the forks.** `doe.indicators` gains
  `PasswordlessSudo` and `RemoteSession` (and the layout its missing `Dnd`
  entry), and `doe.clock` swaps Quickshell's `SystemClock` for the DST-safe
  `WallClock`, which re-arms on epoch milliseconds instead of a wall time that
  repeats when daylight saving ends.
- **Floating windows get a raised titlebar surface.** `lighter_background` is
  now in `colors.toml`, so the new `omarchy-hyprland-titlebars` bar reads a
  deep purple raised surface instead of falling back to the accent `selection`
  colour.
- **Theme keybindings defer to Omarchy.** The theme no longer aliases or
  shadows Omarchy defaults: `SUPER + CTRL + T` opens the theme menu,
  `SUPER + SHIFT + F` / `B` open the file manager and browser,
  `SUPER + CTRL + L` locks, `SUPER + CTRL + E` opens emojis,
  `SUPER + SHIFT + N` opens the configured editor, and
  `SUPER + CTRL + SPACE` / `W` swaps the background. The theme keeps only its
  own actions on free chords: rice layout (`SUPER + ALT + Q`), live wallpaper
  (`SUPER + ALT + W` / `N` / `SHIFT + N`), cooler boost, cast screen, resize
  mode, config reload, and Matrix screensaver. The one deliberate exception is
  close: `SUPER + Q` / `SUPER + W` keep Omarchy's mapping but run the theme's
  red glitch death, as before. Omarchy's `SUPER + ALT + arrows` group move is
  restored too.
- **The wallpaper rides Omarchy's own engine.** Omarchy 4.5 renders video
  wallpapers itself (`owe`), so the theme's mpvpaper engine is retired: the
  wallpaper keys and the glitch curtain stay, but the script now picks the
  file and hands it to `omarchy theme bg set` instead of starting a second
  decoder. Both engines used to decode the same frames (~360 MB of RSS
  between them). The old autostart line is removed on update, and the ready
  flag the curtain waits on is now raised by the engine's own state.
- **Omarchy 4.5 compatibility.** The update took `SUPER + Q` for "close window"
  and `SUPER + SHIFT + T` for "activity" (btop): `Q` / `W` keep Omarchy's close
  mapping but run the theme's glitch death, and the rice layout moved to the
  free `SUPER + ALT + Q`. The background service clone is retired too -
  Omarchy 4.5 renders video wallpapers itself, and the leftover copy kept a
  second IPC handler on the `background` target. The installer and uninstaller
  remove the stale plugin, the theme-set hook keeps the stock service in place
  in both directions, and `tools/check-upstream-drift.py` re-recorded its
  baseline against 4.5.0.
- **The pointer glow only shows over terminals.** It used to trail the
  pointer everywhere, which read as a bright spot with nothing to light up on
  games, browsers and the bar. It is now gated on the pointer being inside a
  focused terminal, and the window feed behind that gate is shared with the
  hex spotlight (`vp_window_track.py`, one server per session), so the two
  overlays cost two Python processes together instead of four.
- **The pointer stays where it is when you switch workspaces.** The theme
  used to set `cursor:warp_on_change_workspace = 1`, which warped the cursor
  to the focused window on every workspace change - and with `follow_mouse`
  on, the focus jumped with it. It is now `0`: the pointer is left alone, and
  a test guards the setting so it cannot come back by accident.
- **The bar's hex underlay drifts smoothly now.** A full lattice repaint is
  ~15ms - one path per hex across the whole bar - which is the entire 60fps
  frame budget, so the drift could only be painted every other frame and read
  as stepping. The pattern is painted once into an offscreen canvas and the
  visible canvas blits it at the drift offset (~0.22ms per frame), so the
  motion runs at the display rate and the fractional offset resamples the
  lines instead of jumping whole pixels.
- **One cursor poller serves both overlays.** The pointer glow and the hex
  spotlight each ran their own Python poller; `vp_cursor_track.py` is now a
  single server that broadcasts the pointer on
  `$XDG_RUNTIME_DIR/vp-cursor.sock` (the second plugin to start it finds the
  socket taken and exits at once), so two cursor effects cost one process
  instead of two. The server answers a new client with the current position
  immediately, so an overlay that loads while the pointer is still does not
  wait for the next move.
- **The clock's calendar popup is built on demand.** It is a month grid with
  its own timers and most sessions never open it, so it is created the first
  time the clock is clicked instead of at startup.

## [1.3.0] — 2026-11-01

### Added
- **The island bar marks the widget under the pointer.** A lit pill follows
  the hovered widget - a rotating ramp rim, a hex shimmer clipped inside it, a
  bloom sampled from the ramp and a soft scale pop. It is disabled by
  `"bar": { "hoverGlow": false }` in `shell.json`, and turning off
  `gapEffects` disables every ambient bar effect so the bar can be made
  completely still.
- **Frosted glass reaches the shell surfaces.** Hyprland's layer blur now
  covers the bar, menu, bar panels, notifications and OSD, and the fills on
  those surfaces dropped a few points of alpha, so the wallpaper shows
  through as soft light instead of flat colour.
- **The lock screen joins the rotating chrome.** The password field's border
  spins on the same `hyprland.active-border` ramp as the windows and the bar,
  with a ramp-sampled bloom behind it; the animated Miku still sits behind the
  field.
- **The terminal gets a hex glow the cursor paints.** The terminal itself
  stays plain glass - no background image - and a click-through overlay
  (`doe.hex-spotlight`) draws a hex grid in a soft, hazy pool of light that
  follows the pointer, but only while a terminal window is focused. The grid
  is anchored to the terminal window at one fixed cell size (`s = 7`), and
  its phase comes from where the canvas actually sits, so the lit hexes stay
  put in the window while the pool animates towards the pointer - the
  terminal reads as clean glass until the cursor lights a piece of it. The
  lattice is painted once into an offscreen canvas and each frame blits it
  (~0.3ms instead of a ~37ms thousand-hex repaint), so the pool canvas can
  paint synchronously and never lag the grid behind the moving pool. The
  glow is kept low (pool 0.06, haze 0.055, line 0.15), so text under the
  pointer stays readable and selecting it is not a fight with the effect.
- **Yazi, Bat and tmux are themed too.** The file manager gets a palette
  theme, Bat gets a `VirtualParadise` syntax theme plus `BAT_THEME`, and tmux
  gets a truecolor status bar sourced from a marker block in `tmux.conf` -
  each installed with a pre-theme backup and restored on uninstall or when
  the theme is left.
- **The pointer carries a neon glow.** A click-through overlay
  (`doe.cursor-glow`) trails a soft cyan core and a sakura halo behind the
  cursor; it reads the position from Hyprland's command socket at ~30Hz
  without spawning a process per frame.
- **The screen edges flash with the desktop.** A second click-through overlay
  (`doe.edge-glow`) lights the screen border cyan when the workspace changes
  and magenta when a notification layer opens.
- **Wallpaper rotation and a day/night variant.** `paradise-wallpaper-rotate.timer`
  advances the live wallpaper every hour, and `paradise-variant-by-time.timer`
  switches cyberpunk in the morning and sakura in the evening. Both are
  installed as opt-in timers and left disabled, so neither changes the
  desktop without being asked for.
- **`theme-switcher.sh wallpaper` derives the palette from the current
  background.** It samples the most vivid colour of the image (or a video
  frame), rotates two companion hues and applies them through the same
  pristine-backup machinery as the named variants, so `reset` still restores
  the original.
- **The bar widgets breathe.** The weather glyph pulses and tints by
  temperature, the clock's seconds heartbeat, the CPU temperature has an amber
  warning tier between normal and overheating, the vitals percentages turn
  amber then red as they climb, the microphone glyph pulses while an app is
  recording, active indicators glow, and the workspace underline grows
  between workspaces instead of blinking.
- **The theme has a voice.** Five short synth blips - login, lock, unlock,
  error and notification - ship with the theme and play through `vp-sound.sh`;
  one flag file mutes them all.
- **More screensaver modes.** `screensaver.sh` picks the matrix, a neon
  starfield or the Miku animation fullscreen.
- **GTK polish and an optional qt6ct scheme.** Headerbars, tabs, progress
  bars, popovers, selection and switches follow the palette, and
  `config/qt6ct/colors/VirtualParadise.conf` is installed for machines that
  use qt6ct instead of Omarchy's GTK platform theme.
- **`install.sh --force-shell-layout`** replaces a customised `shell.json`
  when that is what the user actually wants. Without it, the installer, the
  theme hook and the post-update hook preserve the user's layout.
- **A user-owned post-update hook** (`post-update.d/virtual-paradise.sh`)
  verifies the island bar, repairs it from the copy under
  `~/.local/share/virtual-paradise/island-bar`, re-applies plugin overrides and
  the bar layout while the theme is active, and re-enables the theme timers if
  an update left them disabled.

### Changed
- **The theme uses far less RAM for the same features.** The window-close
  burst moved out of a second resident Quickshell (`~180 MB` PSS) into a
  `doe.window-death` overlay plugin inside the main shell, so the burst still
  maps in a couple of frames but there is no second QML engine. The lock
  preview and its Sleeping Miku GIF now load only while the lock or preview is
  actually shown, the terminal backdrop is 960×540 (the cursor spotlight draws
  the detailed hex), and mpvpaper's demuxer cache is capped at 16 MiB. Measured
  on the development machine: theme PSS fell from ~836 MB to ~488 MB, and the
  layout/effects are unchanged.
- **The island bar now reads as three floating glass pills instead of one
  outlined plate.** The hex layer is a borderless underlay that only shows in
  the gaps, each island carries the sole rim plus a top-lit gradient and a
  softer shadow, and the centre island gets a faint accent bloom. Gap motion
  was reduced to a fixed stream of comets with short trails over an
  edge-faded rail, and the centre widgets got more breathing room. The stream
  is deliberately sparse and slow - 260px apart at 40px/s, painted at 60fps -
  so the gaps read as air with an occasional spark.
- **The window shadow now rotates with the border gradient.** `shadowangle`
  spins the shadow's gradient on the same `linearSpin` loop as `borderangle`,
  and `glowangle` does the same for `decoration:glow` if it is ever enabled,
  so the neon spill travels around the edge instead of sitting still while
  the border moves.
- **The bar rim and the Super+Space menu border ride the window gradient.**
  The islands read their rim colours from the same `hyprland.active-border`
  token the compositor paints on windows and spin the gradient once every
  15s; the centre bloom samples the same ramp so it cycles with the rim. The
  menu is a package-owned plugin, so the first-party bar swaps the loaded
  menu item's border spec at runtime instead of patching a package file, and
  every step is guarded so an upstream rename disables the effect rather than
  breaking the menu.
- **The hover halo became a miniature window.** Hovering a widget now draws a
  gradient rim that rides the shared `hyprland.active-border` ramp and spins
  with the bar, a bloom whose colour is sampled from that ramp at the current
  angle, and a faint hex shimmer clipped inside the pill. The whole chrome is
  created by a loader only while the halo is visible, so a bar full of idle
  widgets pays nothing for the effect. The halo runs hotter than the bar
  border - full-strength ramp rim, a 0.10 wash, a 0.22 hex shimmer and a
  lit-glass sheen - so it reads as a pressed button rather than a smaller
  copy of the island rim.
- **The bar grew to 40px so widget pills clear the island rim.** The widgets
  are sized off the bar height, and at 34px the weather, temperature and mic
  capsules sat within a pixel of the island rim. The taller bar leaves a
  visible gutter between a widget's own border and the island's two-pixel
  gradient line.
- **The bar border got its own language.** Beyond the rotating ramp rim - now
  a two-pixel gradient line like the window borders - every island carries a
  dim inner hairline that rides the same ramp and a faint ramp aura, and a
  single scanner spark with a short trail laps the whole bar's outer contour,
  crossing the gaps along the top and bottom edges so the three islands read
  as one circuit. That is deliberately different from the hover chrome - hex
  shimmer, scale pop and a stronger bloom - so the bar and the hovered widget
  never read as the same effect.

### Fixed
- **The Cooler Boost toggle tells the truth after a reboot.** The bar read a
  `/tmp` state file, and a reboot wipes it, so a machine that came back still
  in boost showed "off" until the toggle was pressed again. The script now
  reads the fan profile from the embedded controller (`pwm1_enable`: 0 =
  boost, 2 = auto) and only falls back to the state file for backends without
  a queryable boost bit; the file moved to `~/.local/state/virtual-paradise/`
  and is re-synced whenever the hardware disagrees. The bar widget asks the
  script (`toggle_cooler_boost.sh state`) instead of reading the file, so the
  pill always mirrors the fans.
- **The hex glow no longer fades in late.** Focus was polled with `hyprctl`
  every 500ms, so the glow could appear half a second after a terminal was
  focused, and the compositor's default `layersIn` slidefade animated the
  panel in as if it were a dialog. Focus and geometry now stream from
  Hyprland's event socket (`window_track.py`), and `vp-hex-spotlight` joined
  the theme's no-animation layer rule, so the pool appears in the same frame
  as the focus change.
- **The cursor spotlight actually appears now.** The hex reveal panel was
  gated on `root.onThisScreen`, but `onThisScreen` is a property of the
  delegate (the `PanelWindow`), not of the plugin root, so the condition was
  always `undefined` and the overlay stayed invisible - the "reveal" seen in
  testing was the ghost tile plus the separate cursor glow. The gate now uses
  the delegate's own `onThisScreen`, and the lit hexes sit on the ghost ones
  (verified pixel-aligned in a live window).
- **The window-close burst leads the close again.** Moving the burst into the
  shell left the death script looking for the old daemon's pidfile, so it took
  the slow one-shot path and the glitch trailed the close. The overlay now
  announces itself with a `vp_death_ready` pid file, and the script takes the
  instant trigger path whenever that shell is alive; the close timing itself is
  unchanged.
- **The empty `omarchy.spacer` between the waveform and the weather is gone.**
  It rendered as an invisible but hoverable hole in the centre island; the
  theme layout no longer ships it.
- **The gap comet no longer jerks when the window focus changes.** Switching
  focus rewrites the active-window title, the left island resizes, and the
  comet used to be re-rolled by the new gap width. The comets are now a
  fixed-speed stream in bar coordinates, and the gaps are windows onto it: a
  resizing island changes how much of the stream shows, never where it is or
  how fast it moves.
- **A customised `shell.json` survives a theme round-trip.** Re-applying the
  theme used to overwrite any layout change on every login, and leaving it
  overwrote the file again with the stock layout. All three entry points now
  use the same three-way ownership check: missing, stock, the previous theme
  layout, or the last layout this theme applied may be replaced; anything else
  is a user edit and is preserved.
- **Leaving Virtual Paradise restores the stock plugins and reverts the
  overrides.** The old hook copied overrides without recording them, so a
  switch away left the plugins patched and `omarchy plugin update` could no
  longer fast-forward. It now uses the same tracked layer as the installer and
  updater.
- **Omarchy's `activeBarId` fallback is no longer mistaken for a user edit.**
  While the island bar is temporarily unavailable, Omarchy rewrites the live
  bar id to `omarchy.bar`. The installer now recognises that transient state,
  replaces it with the theme layout, and still preserves a layout the user
  actually changed.
- **A missing replacement plugin no longer removes its stock widget.** The
  theme hook enables a stock widget whenever its external replacement is not
  installed, instead of disabling it unconditionally and leaving an empty slot.
- **Non-git plugin overrides are reversible.** The layer now keeps a pristine
  copy of every existing file it modifies, so a plugin that is not a git
  checkout can be restored when the theme is left or uninstalled.
- **An update cannot leave you without a bar.** If the first-party bar is
  missing or half-copied, the post-update hook repairs it from the user-owned
  copy. If it cannot, it leaves `shell.json` alone and lets Omarchy's
  `activeBarId` fall back to the bundled bar, with a single notification
  instead of an empty bar or a failed update.
- **The audio watchdog treats a stale-socket cleanup as success.** It used to
  exit 2 after removing a socket with no daemon behind it, which showed a
  healthy repair as a failed systemd unit.
- **`ConditionPathExists` is in `[Unit]`, not `[Service]`.** Both theme units
  now verify cleanly with `systemd-analyze verify`; an update cannot make them
  look like a configuration error.
- **The stock system tray is untouched.** The disabled drawer-reveal patch and
  its uninstaller repair path are gone; the island bar uses the upstream tray
  unchanged.
- **Switching themes (and logging in) is several times faster.** Three
  things were costing seconds on every login and every theme switch:
  - The wallpapers (~95 MB of video) lived *inside* the theme directory.
    Omarchy stages the whole theme into
    `~/.local/state/omarchy/current/theme` on every switch, so copying them
    took about 15 seconds. They now live in
    `~/.config/omarchy/backgrounds/virtual-paradise/`, which Omarchy scans
    for wallpapers as well. The theme directory shrank from 96 MB to 1 MB.
  - The animated GIFs were wallpapers too. Omarchy picks the bar's text
    colour with ImageMagick, and rendering 250 animation frames of a GIF took
    over a minute per switch. The GIFs are the SDDM login animation and are
    read from the repository; as wallpapers only their first frame is kept.
  - The theme-set hook made about thirty `omarchy plugin` calls, each of
    which walks the whole plugin catalogue, to assert a state that was
    already correct. It now reads the state once and only touches the
    difference: 19.5 s became 2.8 s.
- **The terminal banner no longer costs a Python start-up per shell.** The
  art is static and its colors follow the theme, so it is rendered once and
  cached; the shell prints the cached copy in about 6 ms instead of paying
  ~30 ms of interpreter start-up in every interactive shell.
- **The boot image carries a third less.** The Plymouth animation was
  encoded as 1920x1080 PNGs - ~97 MB of frames inside the initramfs, which
  the kernel has to read and Plymouth has to decode. The frames are now
  1600x900 with a 256 colour palette: the same picture once Plymouth
  stretches it over the screen (Plymouth converts palette PNGs through
  `png_set_palette_to_rgb`), about a third of the data.
- **The screen is no longer black after logging in.** The greeter hands the
  screen to the session, and the session needs about three seconds before the
  desktop has anything to show: the compositor starts, then the shell loads
  its plugins. That gap was a black screen. A session splash now plays the
  same glitch curtain as the live wallpaper switch - over the theme's cyber
  artwork - and fades out as soon as the shell answers, so the whole way from
  the firmware to the desktop is one picture instead of a black screen.
- **The glitch effect breaks up like a bad TV.** The curtain now has a
  crawling static layer, rolling scanlines, colour separation that wanders and
  slices that jump to a new random offset every tick, with dropout blocks and
  colour bars appearing at random. The picture stays readable through it, and
  the amount of noise is configurable: the wallpaper switch keeps it subtle,
  the session splash runs at full strength.
- **The session splash shows Miku_animated4** instead of Miku_animated_full.
- **The HUD is gone.** "VIRTUAL☆PARADISE // WALLPAPER LINK" sat in the middle
  of the picture and covered Miku's face.
- **The overlay does not vanish abruptly - but only the glitch lingers.**
  The picture and the static end at once, the way they always did. What
  stays for a moment afterwards is the glitch itself: the tearing, the
  dropout bands and the colour bars keep breaking up over the desktop and
  fade away.
- **The live wallpaper is visible right after logging in.** The video is
  drawn on the same layer as the shell's static background, and a layer
  created later ends up on top. The autostart hook started mpvpaper before
  the shell had put its background up, so the video ended up *under* the
  static picture: the login screen showed a static wallpaper with the
  shell's diamond transition. The live wallpaper now waits for the shell's
  background layer.
- **The static wallpaper is sharp again.** The installer turned the animated
  GIFs into still images to keep the wallpaper cycle short, but the GIF and
  the JPG have the same base name - the conversion overwrote the sharp
  1920x1080 picture with a 480x270 frame. The GIFs are now simply removed
  from the wallpaper directory and the repository's full resolution JPGs are
  used.
- **The Plymouth password row no longer covers the neon frame.** The prompt
  was placed near the bottom of the *screen*, which is inside the picture now
  that the splash is centred. It sits below the picture, in the bar under the
  frame, and falls back to the old place only on a screen too small for that.
- **The splash fades in.** The whole Plymouth picture fades up over the first
  second, so the handover into Plymouth - after the boot animation and on the
  way out for a reboot or a shutdown - is a transition instead of a cut. The
  login screen fades in the same way.
- **The wallpaper transition is actually visible.** The curtain appeared for
  half a second and was gone before it registered. It now holds for a moment
  before it opens, and the same curtain is available for the way out:
  `transition.sh logout|reboot|shutdown` plays it and then hands over. The
  three actions are in the Omarchy menu under the theme's Quick Actions.
- **The boot image is really rebuilt after installing the splash.** The
  installer picked one rebuild path with an `if/elif` and threw its output
  away: when `limine-mkinitcpio` failed, `mkinitcpio -P` was never tried and
  the machine kept the old splash - with the installer reporting success.
  Both paths are tried now, the output is shown, and the mtime of the boot
  image is checked so a skipped rebuild cannot pass as a success.
- **The login screen can be shown at all.** Omarchy logs in automatically, so
  the greeter is on screen for less than a second and the theme's password
  panel was never seen. `install.sh --no-autologin` turns the automatic login
  off, and `uninstall.sh` puts it back.
- **The login screen continues the boot splash.** The greeter showed a
  different picture than the boot animation: a blurry 480x268 GIF stretched
  over the whole screen. It now uses the same cyber backdrop, the same
  centred still of the animation at 1600x900 and the same neon frame, so the
  handover from Plymouth into the login screen keeps the picture. The screen
  fades in when the greeter appears and fades out when the login succeeds.
- **The password field stands out.** It was a one-pixel line with seven-pixel
  dots at the bottom of the screen. It is now a wide neon panel with an
  accent border and glow, the lock icon, the username above it, an
  "ENTER PASSWORD" label and a blinking neon caret.
- **The boot splash is centred and decorated.** The 1600x900 picture sits in
  the middle of the screen, a cyber backdrop fills the whole screen behind
  it - the blue circuitry on the left and the pink HUD on the right show
  through the bars around the picture - and a neon border with pink corner
  brackets marks the edge of the picture.
- **The compositor can read the Hyprland config the installer writes.** A
  `mktemp` file is created with mode 600 and `mv` keeps that mode, so moving
  a freshly built `hyprland.lua` into place turned it into `-rw-------`. In a
  `sudo ./install.sh` run the file was root-owned on top of that, and the
  compositor answered *"cannot open ~/.config/hypr/hyprland.lua: Permission
  denied"* in its error overlay - the whole session was blocked until the
  next reload. Replacing a file now keeps its mode and its owner, and every
  config the theme writes is made readable again.
- **`sudo ./install.sh` no longer fails with "OMARCHY_PATH is not set".**
  Omarchy sets `OMARCHY_PATH` in the user's shell, but sudo resets the
  environment, so every `omarchy ...` command the installer started ran
  without it: `omarchy plugin list` answered "OMARCHY_PATH is not set",
  `omarchy restart shell` looked for the shell config in "/shell", and
  `omarchy-shell shell rescanPlugins` failed the same way. The installer
  ignores those errors, so the run *looked* successful while no plugin was
  enabled, the theme was never applied and the shell never restarted. The
  path is now resolved the way Omarchy does (`/etc/omarchy.conf` for a dev
  checkout, otherwise `/usr/share/omarchy`) and handed to every command the
  installer, the uninstaller and the plugin updater start.
- **The daily plugin update check works again.** It runs from a systemd
  timer, and the user manager's environment carries no `OMARCHY_PATH` either,
  so the check answered "OMARCHY_PATH is not set" and reported nothing. The
  updater resolves the path itself now.
- **`sudo ./install.sh` can still reach the compositor.** sudo resets the
  Hyprland instance, the Wayland display and the session bus as well, so
  `hyprctl reload` found no compositor and the theme's Hyprland changes only
  landed at the next login. Those variables are now read back from the user's
  runtime directory.
- **`SUPER + ALT + ←` / `→` switch the live wallpaper again.** The theme
  bound those two chords to the live wallpaper while Omarchy bound them to
  "move window into the group on the left/right". Hyprland runs every bind of
  a chord, so a press switched the wallpaper *and* moved the window into a
  group; 1.2.2 removed the theme's pair to stop that, and the arrows stopped
  working. The pair is now replaced deliberately: `hl.unbind()` removes
  Omarchy's two binds first, so exactly one action runs, and the group move
  moves to `SUPER + ALT + CTRL + ←` / `→`, which Omarchy leaves free.
- **The terminal keeps the font size you chose.** The theme shipped
  `font-size = 12` (and `adjust-cell-height = 12%`) in its Ghostty, Kitty,
  Foot and Alacritty configs. Ghostty applies a `config-file` include *after*
  the file that pulls it in, so the theme's size beat the user's own config:
  a fresh install turned 9pt text into 12pt text, and the line box stayed
  inflated. The theme configs no longer pin a size or a line height, so the
  terminal uses the user's setting (or its own default) and scales with the
  display's DPI on every screen.
- **The display layout belongs to hyprmoncfg again.** The theme shipped static
  monitor rules for `eDP-1`, `HDMI-A-1`, `DP-1` and `DP-2` with a fixed scale
  of 1.0. That kept the laptop panel alive with the wrong scale even when
  hyprmoncfg wanted it off, and made every HiDPI display render at 1x — the
  automatic layout switching on hotplug, lid and suspend had nothing to work
  with. The theme now ships no rule for a named output, and the installer
  removes the old presets from machines that ran it.
- **The window rules no longer sit behind hyprmoncfg's rules.** The installer
  appended them to the end of `hyprland.lua`, after the line that loads
  hyprmoncfg's generated monitor rules last. `hyprmoncfg doctor` reported the
  setup as broken ("anything loaded after it can override the layout") and the
  daemon had to repair it on every apply. The rules are now inserted in front
  of that line.
- **Plymouth: the boot theme is no longer patched into Omarchy's theme.**
  `install.sh` overwrote `/usr/share/plymouth/themes/omarchy/omarchy.script`
  with the theme's animation script and dropped ~330 generated PNGs into that
  package-owned directory. An Omarchy update reverted the animation, and
  `uninstall.sh` had no Plymouth handling at all: the patched script, the
  frames and the systemd drop-ins stayed behind forever. The theme now lives
  in `/usr/share/plymouth/themes/virtual-paradise` with its own descriptor and
  is selected by name in `/etc/plymouth/plymouthd.conf`
  (`lib/plymouth.sh`). Uninstall removes the theme, restores the previous
  selection and deletes the drop-ins; machines that ran the old installer get
  the stock script back and the stray frames deleted.
- **Every effect in `effects.sh` now actually does something.** Hyprland 0.5x
  loads a Lua config, and the `hyprctl keyword` subcommand refuses to work with
  it ("keyword can't work with non-legacy parsers. Use eval."), so the rainbow
  border, the glow, the blur toggle and the focus pulse were silent no-ops.
  They go through `hyprctl eval` with the same `hl.config()` shape the theme's
  own `hypr/*.lua` files use. The blur toggle also read `.int` from
  `hyprctl getoption`, which reports `.bool`, so it only ever enabled blur;
  the focus pulse read `.str` instead of `.gradient` and restored the border as
  the literal string `null`.
- **`effects.sh shake` uses the theme's window-error effect.** The old
  implementation drove `hyprctl dispatch movewindowpixel`, a dispatcher the
  Lua parser rejects; it now calls the shipped
  `hypr_window_error_shake.sh` / `hypr_window_error_restore.sh` pair. The
  dead `spawn_animation` helper, which used two more rejected dispatchers, was
  removed.
- **`effects.sh` workspace switching works again.** `hyprctl dispatch workspace
  e+1` is legacy syntax and is parsed as Lua (`hl.dispatch(workspace e+1)` →
  syntax error); the script now uses `hl.dsp.focus({ workspace = "e+1" })`,
  the same call Omarchy's own bindings use.
- **The focus pulse restores the border it found.** Hyprland reports a
  gradient stop as `AARRGGBB` while its config syntax wants `RRGGBBAA`, so
  the restored border came back with its red and blue channels swapped.
- **The theme switcher applies the palette it writes.** It edited
  `~/.config/hypr/hyprland.conf`, which Omarchy 4 does not read (the config is
  `hyprland.lua` now), so the variant only landed in `colors.toml` and never
  reached the terminal, the bar or the window border. The script now re-renders
  the theme through `omarchy theme refresh`, updates every color the accent
  derives from (cursor, tab highlight, selection), keeps the original palette
  once so `theme-switcher.sh reset` can restore it, and refuses to pretend it
  worked when the theme is not installed.
- **The legacy `hyprland.conf` is cleaned up.** Releases before 1.2 shipped
  their own `~/.config/hypr/hyprland.conf`. Hyprland ignores it while
  `hyprland.lua` exists, but it looks like a live config and hides the real
  one; install and uninstall now remove it when it is clearly the theme's.
- **`widgets.sh` was removed.** It only ever worked with `eww`, which the
  theme does not install, so it always failed with "is eww running?". The
  desktop widgets the theme ships are Quickshell bar plugins
  (`clock`, `weather`, `cputemp`, …). Uninstall removes the leftover script
  from older installs.
- **The live wallpaper keeps its socket in the runtime directory.** The
  mpvpaper socket and the flag the transition waits on used a fixed `/tmp`
  path. Both are world-writable on a multi-user machine: a socket that
  already exists keeps mpvpaper from starting, and a ready flag that is
  already there ends the transition before the wallpaper is up.
- **The window and workspace springs register on Hyprland 0.56.x.** The
  spring curve key is `dampening` on 0.56; the wiki's "Latest git" pages
  spell it `damping`. Copying the newer spelling made the config loader
  reject both curves and every animation leaf that referenced them, and
  the compositor silently fell back to its default curves.
- **The active shadow carries the border's three-stop gradient.** A flat
  cyan shadow halo read as a monochrome glow around every window and
  drowned the three-stop border gradient - the window edge lost its
  cyan-green-pink travel. The shadow now carries the same three stops at
  the same 135 degrees, at a lower alpha and a tighter range, so the glow
  reads as the border's own light spilling out.
- **Every window glows, not just the focused one.** The glow read as
  inconsistent - some windows had it, some did not - because only the
  focused window carried the palette: the inactive border was a flat grey
  and the inactive shadow was nearly invisible. Inactive windows now keep
  the same three stops at a low alpha on both the border and the shadow,
  so every window carries the gradient while the focused one still burns
  brightest.

### Changed
- **The glow is heavy and proud, and every gradient follows the theme's
  band layout.** Active shadows widened to range 30 at render power 4 with
  the border's three stops near full alpha. Gradients are built as four
  cyan, two green, four pink stops: Hyprland caps a gradient at ten
  colours and spaces stops evenly, and this is the closest the cap allows
  to the theme's cyan 45% / green 20% / pink 45% travel.
- **The focused border cycles its colours.** `borderangle` runs a linear
  loop - one full turn every three seconds - so cyan, green and pink
  travel around the focused edge rainbow-style. Inactive windows carry the
  same spin at their dim alpha: movement on a faint gradient reads as a
  shimmer, not a distraction.
- **The glitch now leads the close instead of chasing it.** Spawning a
  Quickshell per death cost a quarter of a second of startup, which either
  delayed the close or left the burst trailing behind it as an afterimage.
  A resident daemon (`vp_death_daemon.qml`, autostarted with the session)
  now keeps its burst surfaces mapped for the whole session, so a death
  costs no compositor roundtrip. The script announces the death first and
  the neon glitch is on screen in ~50 ms - before the window starts to
  close. It then grabs the window itself with `grim -T` (the foreign-
  toplevel capture excludes the overlay, so the corpse is the window, not
  the glitch), snaps the corpse into the burst, and closes at ~90 ms. The
  window's pop-out animation plays behind the glitch, never before it.
  Three things bought the speed: JPEG q70 capture (~20 ms instead of
  ~77 ms for PNG), a pidfile + `/proc` check instead of a ~30 ms `pgrep`
  per close, and one frame of head start between the trigger and the
  close. The daemon adds one resident Quickshell (~110 MB), the accepted
  price of a death that is both instant and synchronous. Its lifetime
  stays at 430 ms so the layout reflow stays visible under it.
- The Plymouth theme script is shipped as `plymouth/virtual-paradise.script`
  instead of `plymouth/omarchy.script`, so nothing in the repository is named
  after the package theme it no longer replaces.
- The installer removes helper scripts the theme no longer ships, so a file
  that was dropped from the repository does not keep answering to its old name
  in `~/.local/bin` forever.
- **The test suite no longer kills the live death daemon.** `uninstall.sh`
  stopped every `vp_death_daemon.qml` process of the user, and the suite runs
  the uninstaller in a sandbox with a different HOME - so a test run silently
  killed the resident daemon. It now only stops the daemon under the HOME it
  is uninstalling from.

### Added
- **Windows die in a neon glitch burst.** SUPER + W - replacing Omarchy's
  plain close on purpose, unbind first - kills the window in three beats,
  glitch first: the burst's mapped surface turns the live window into
  violet, magenta and sakura static in ~50 ms, the window is captured frame
  and all with a toplevel grab (the overlay is not in the shot), and the
  capture is torn into jumping slices while the neon wash burns through -
  the slices and the corpse's own violet-to-sakura gradient border shiver,
  so the window reads as shaking itself apart. The shared `noise.jpg` is
  the same asset the login splash uses, so the close and the boot wear the
  same palette. The burst is in the no_anim layer rule, so it appears in a
  single frame instead of sliding in like a panel, and the window closes
  *under* it at ~90 ms. Click-through like every other overlay; closes
  with the 0.56 dispatcher spelling (`hl.dsp.window.close`), because
  `hyprctl dispatch closewindow address:...` is parsed as Lua on 0.56 and
  silently no-ops.
- **Ambient effect layers, and a switch for them.** `vp-effects.sh
  start|stop|status|enable|disable` runs optional fullscreen Quickshell
  overlays: `ambient_glitch` (a cyan or magenta tear flashes across the
  screen every 5-15 seconds) and `scanline_overlay` (faint CRT scanlines).
  Both are click-through everywhere - an empty input mask - and never take
  keyboard focus, so the desktop underneath stays fully usable.
- `install.sh --help` lists the supported options, and an unknown option is
  now an error instead of being ignored. A typo like `--user-onyl` used to
  run a full install with the wrong privileges.

### Tests
- TC-20 through TC-24 cover the bar work in this cycle: the hover glow, the
  island chrome and gap stream, the rotating gradient chrome (bar rim, menu
  border and window shadow), the hover chrome and the bar border chrome. The
  suite is now 396 assertions with `shellcheck` installed (395 without), and
  TC-7 also proves the Yazi, Bat and tmux themes are installed and restored.

---

## [1.2.2] — 2026-10-20

### Fixed
- **`SUPER + RETURN` no longer launches two terminals.** Hyprland runs every
  binding registered for a chord; it does not replace an earlier one. This theme
  re-bound many Omarchy defaults in `hypr/bindings.lua` (terminal, workspaces,
  floating/fullscreen, clipboard, browser, Email, screenshots, window groups,
  vim HJKL), so a single press ran both actions — and the file even bound
  `SUPER + SHIFT + K` and `SUPER + SHIFT + L` twice on its own. The theme now
  only binds chords Omarchy leaves free: the live-wallpaper controls moved to
  `SUPER + ALT + W` / `SUPER + ALT + N` / `SUPER + ALT + SHIFT + N`, and stale
  aliases that shadowed defaults (or called removed commands such as
  `omarchy-capture-screen`, `omarchy-capture-color` and `omarchy menu logout`)
  were dropped. `tools/check-bindings.py` fails on repeated chords and on any
  chord that shadows an Omarchy default, using the installed tree or a
  committed fixture in CI.
- **Uninstall restores the pre-install Hypr config after re-installs.** Each
  install snapshotted the already-themed files, and uninstall restored the
  newest snapshot — which was ours. `bindings.lua` and `looknfeel.lua` therefore
  survived an uninstall (the leftover bindings are what made `SUPER + RETURN`
  double up after the theme had been removed). Install now records the first
  snapshot of the cycle in `~/.local/state/virtual-paradise/hypr-backup-dir`;
  uninstall restores that, falls back to the oldest snapshot for machines
  installed before the state file existed, removes the state file, and no
  longer deletes a user-edited file just because no snapshot exists.
- **Uninstall removes the window rules and live-wallpaper autostart hook.** The
  installer appended its window rules under a “Virtual Paradise Add-on Window
  Rules” marker, but uninstall matched only the individual strings and missed
  `org.gnome.NetworkDisplays`, leaving one rule behind. The installer also
  guarded on the string “GNOME Network Displays”, so a user comment mentioning
  that app could suppress the whole block. The guard now uses the marker, and
  uninstall strips the exact rules, the autostart hook and the snapshot
  directory.
- **SDDM: the login theme is no longer patched into Omarchy's theme.**
  `install.sh` copied its `Main.qml` and a 13 MB GIF over
  `/usr/share/sddm/themes/omarchy/`, a directory owned by the
  `omarchy-settings` package. An Omarchy update silently replaced half of it,
  and `uninstall.sh` did not restore the theme at all, so the login screen
  could end up pointing at a theme that no longer worked. The theme is now
  installed self-contained in `/usr/share/sddm/themes/virtual-paradise/` and
  selected by `/etc/sddm.conf.d/zz-virtual-paradise-theme.conf`; install backs
  up a conflicting drop-in, uninstall restores the previous selection, and both
  repair machines that still carry the old in-place patch. A theme directory
  that was not installed by this project is never deleted.
- **SDDM: the installer no longer sets a login shell that PAM rejects.** It
  called `chsh -s "$(command -v zsh)"`; with `/usr/sbin` before `/usr/bin` in
  PATH that is `/usr/sbin/zsh`, while `pam_shells` compares the passwd field
  against `/etc/shells` as a string, so both password login and autologin failed
  with "Authentication error". The installer now resolves the canonical
  `/usr/bin/zsh`, registers it in `/etc/shells` when needed, refuses to change
  the shell otherwise, and records the old shell so uninstall can restore it.
- **`tools/shrink-history.sh` could delete commits.** It stripped *every* blob
  that is reachable from history but absent from the HEAD tree — which includes
  every previous revision of every text file, not just the dead wallpapers. Any
  commit whose changes were all such blobs became empty, and `git-filter-repo`
  prunes empty commits by default: a run on this repository dropped 51 of 111
  commits (including installer and CI fixes) while still reporting success. The
  strip list is now limited to blobs of at least 1 MB (`SHRINK_MIN_BYTES`
  overrides it), the rewrite runs with `--prune-empty=never`, and the script
  fails loudly if the commit count or the HEAD tree changes. It also tells you
  to force-push tags, which the previous instructions omitted.

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
- `install.sh --sddm-only` reinstalls just the login theme, without touching
  Plymouth or rebuilding the initramfs.
- Test coverage for the above: `luac -p` on every Lua file, `ghostty
  +validate-config`, `foot --check-config` and `hyprctl configerrors` (each
  skipped when the tool/instance is unavailable). 116 checks with the optional
  linters installed, 115 without `shellcheck`.
- **TC-10** exercises the SDDM code against a throwaway system root: standalone
  install, asset completeness, drop-in selection, legacy-patch repair, a second
  install that changes nothing, uninstall restoring the previous theme, foreign
  files left alone, and the login-shell resolver.
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

- [Unreleased]: https://github.com/vuhuudo/virtual-paradise/compare/v1.4.0...HEAD
- [1.4.0]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.7...v1.4.0
- [1.3.7]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.6...v1.3.7
- [1.3.6]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.5...v1.3.6
- [1.3.5]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.4...v1.3.5
- [1.3.4]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.3...v1.3.4
- [1.3.3]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.2...v1.3.3
- [1.3.2]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.1...v1.3.2
- [1.3.1]: https://github.com/vuhuudo/virtual-paradise/compare/v1.3.0...v1.3.1
- [1.3.0]: https://github.com/vuhuudo/virtual-paradise/compare/v1.2.2...v1.3.0
- [1.2.2]: https://github.com/vuhuudo/virtual-paradise/compare/v1.2.1...v1.2.2
- [1.2.1]: https://github.com/vuhuudo/virtual-paradise/compare/v1.2.0...v1.2.1
- [1.2.0]: https://github.com/vuhuudo/virtual-paradise/compare/v1.1.0...v1.2.0
- [1.1.0]: https://github.com/vuhuudo/virtual-paradise/compare/v1.0.0...v1.1.0
