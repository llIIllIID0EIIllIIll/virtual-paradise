# Changelog

All notable changes to Virtual☆Paradise are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com); commit messages follow
Conventional Commits.

---

## [Unreleased]

### Added
- **The island bar marks the widget under the pointer.** A soft accent halo
  follows the rounded shape of the hovered widget and fades in and out instead
  of popping. It is disabled by `"bar": { "hoverGlow": false }` in
  `shell.json`, and turning off `gapEffects` disables both ambient effects so
  the bar can be made completely still.
- **`install.sh --force-shell-layout`** replaces a customised `shell.json`
  when that is what the user actually wants. Without it, the installer, the
  theme hook and the post-update hook preserve the user's layout.
- **A user-owned post-update hook** (`post-update.d/virtual-paradise.sh`)
  verifies the island bar, repairs it from the copy under
  `~/.local/share/virtual-paradise/island-bar`, re-applies plugin overrides and
  the bar layout while the theme is active, and re-enables the theme timers if
  an update left them disabled.

### Changed
- **The island bar now reads as three floating glass pills instead of one
  outlined plate.** The hex layer is a borderless underlay that only shows in
  the gaps, each island carries the sole rim plus a top-lit gradient and a
  softer shadow, and the centre island gets a faint accent bloom. Gap motion
  was reduced to a fixed stream of comets with short trails over an
  edge-faded rail, the centre widgets got more breathing room, and the hover
  halo became a soft lozenge that follows the widget's full height. The
  stream is deliberately sparse and slow - 260px apart at 40px/s, painted at
  60fps - so the gaps read as air with an occasional spark.
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

- [Unreleased]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.2.1...HEAD
- [1.2.1]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.2.0...v1.2.1
- [1.2.0]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.1.0...v1.2.0
- [1.1.0]: https://github.com/llIIllIID0EIIllIIll/virtual-paradise/compare/v1.0.0...v1.1.0
