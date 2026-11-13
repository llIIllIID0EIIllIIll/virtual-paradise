# Virtual☆Paradise — Roadmap

This file separates what is shipped, what the Phase 1 audit found, and what
Phase 2 should deliver. It is intentionally concrete so each item can become a
test or a release note.

---

## Phase 1 — Settings and custom theme (shipped)

**Goal:** a visual, live theme editor inside the Tools panel, without adding a
second settings application or restarting the shell for every color change.

### Shipped

- Settings gear in the Tools panel with appearance, palette, health and system
  actions.
- Eight custom roles: Accent, Secondary, Tertiary, Warm, Pink, Urgent,
  Background and Text.
- Visual swatch board (13 hues × 7 tones) plus a neutral ramp; no hex knowledge
  required. The hex field remains for precision.
- Every swatch click writes `palette.json` through `vp-palette.sh`; the bar
  recolors as soon as the file watcher fires, with no Apply button and no
  shell restart.
- Terminal/GTK/theme text files are debounced through
  `theme-switcher.sh custom`.
- `VpPluginBarApi` forwards all palette roles to every bar widget.
- Built-in palettes remain available and still use the single-flight shell
  restart.

### Verification

- 550 assertions green; TC-12 covers palettes, custom roles, live writes,
  idempotence and concurrent writers; TC-30 covers the panel contract.
- CI green on Ubuntu and Arch; release dry-run green.
- Live check: one shell, one bar, variant `cyberpunk`, defaults gap on /
  hover off / reduced motion off, zero runtime QML errors.

---

## Phase 1 audit — fixes made after the first release candidate

| Finding | Fix |
| --- | --- |
| Rapid swatch clicks spawned one writer per click; an older process could finish last and revert the newest color. | Coalesce palette writes over 60 ms; only the latest state is written. |
| A pending custom write could land after a named palette and undo it. | `setVariant` stops both debounce timers and clears the dirty flags. |
| Closing the panel with a pending theme edit lost the text-file update. | `Component.onDestruction` flushes both paths, guarded by dirty flags so merely opening settings does not create a custom variant. |
| A malformed or partially written palette could put invalid strings into the editor. | `loadPalette` validates `#RRGGBB` per role and keeps the last good/default value. |
| `vp-palette.sh` honored `XDG_STATE_HOME` while the rest of the theme used `$HOME/.local/state`; a custom XDG path split the state. | Align `vp-palette.sh` with `theme-switcher.sh` and the QML readers. |
| Rewriting an identical palette caused pointless watcher work and color-animation churn. | Skip identical palette/variant content; preserve the inode. |
| Concurrent writes were not covered by tests. | Add an 8-writer flock test that requires a complete, valid palette at the end. |

---

## Known limits after Phase 2.1

- Wallpaper, Plymouth and SDDM artwork stay cyberpunk for every palette.
- Existing terminal sessions may need a reload to see the deferred text-file
  refresh; the bar itself is live.
- A long-lived palette writer daemon and automated UI screenshots are not in
  2.2 yet.
- UI automation and golden screenshots are not in the suite yet.

---

## Phase 2.1 — Portable, accessible live theming (shipped in Unreleased)

**Theme:** “make the palette something a user can own, share and trust.”

### P0 — Reliability and reach (done)

- [x] `theme-switcher.sh` and `vp-palette.sh` share `palette.lock`.
- [x] `vp-palette.sh --seq N` drops an older write that lost the race; the
      panel sends `Date.now()` and serializes its own writers.
- [x] Palette write failures appear inline in the panel instead of failing
      silently.
- [x] State stays under `$HOME/.local/state/virtual-paradise` everywhere.
- [x] The panel owns `palette.json` while editing; the theme pass only writes
      text files, so a slower theme pass cannot overwrite a newer color.

### P1 — Editor UX and accessibility (done)

- [x] Undo/Redo/Reset, including `Ctrl+Z` and `Ctrl+Shift+Z`, with a 50-step
      history.
- [x] WCAG contrast feedback for Text/Background.
- [x] Keyboard navigation: Tab to a role or the board, arrows move, Enter picks.
- [x] Write status and errors shown under the board.
- [x] Shell-wide refresh deferred until the panel closes, so the panel does not
      disappear mid-edit.

### P1 — Portable themes (done)

- [x] `vp-theme.sh save|list|load|export|import|delete`.
- [x] Schema-versioned JSON with all eight roles under
      `~/.local/state/virtual-paradise/themes/`.
- [x] Panel Save / Load / Import controls, refreshed when settings opens.

### Verification

- 580 assertions green; TC-12 covers live writes, ordering, reader/writer
  locking, terminal OSC output, Cava palette sync, wallpaper/login/Plymouth
  art and portable themes; TC-30 covers history, keyboard, contrast,
  generation, color vision, preview, terminal toggle, artwork controls, the UI
  smoke/diff tools and deferred refresh contracts.
- Live checks: swatch click, undo, redo and reset through the panel and IPC;
  one shell, one bar, zero runtime QML errors.

---

## Phase 2.2 — Editor depth and artwork (shipped through 1.7.0)

### Editor depth (done)

- [x] Seed-color generation: one Accent → analogous/complementary/triadic
      companions and derived neutral Background/Text.
- [x] Color-vision preview (deuteranopia/protanopia) for the eight roles.
- [x] Live preview card showing bar chrome and a terminal sample.
- [ ] Optional long-lived palette writer instead of one short Python process
      per settled click (current behavior is already ordered and serialized).

### Deeper live apply

- [x] Notify running terminals with OSC 4/10/11/12, gated by
      `bar.liveTerminals` and tested with `--dry-run`/`--list`.
- [x] Cava reloads its gradient from the active `colors.toml` (SIGUSR1/2 via
      `sync_cava_theme.py`) on each debounced edit.
- [x] Document live vs next-launch behavior for GTK, browser, VS Code,
      btop and fastfetch; terminals and Cava are the reliable live consumers.
- [ ] Add a generic consumer reload hook if upstream apps expose one.

### Artwork

- [x] Wallpaper duotone from the current video frame or image using the live
      Background/Accent, with restore.
- [x] SDDM login artwork (backdrop/still/frame) from the live palette, with
      backup and restore.
- [x] Plymouth boot artwork, opt-in, with backup/restore and an initramfs
      rebuild.
- [x] Keep cyberpunk artwork as the default and as the fallback.
- [ ] Never leave a boot entry pointing at a deleted image (covered by the
      existing boot theme installer; validate with Plymouth art in 1.7.0).

### Release gates

- [x] Run Ubuntu and Arch CI plus the release dry-run.
- [x] Version 1.5.0 with the palette/editor/terminal/Cava work.
- [x] Version 1.6.0 with the wallpaper and SDDM login artwork.
- [x] Version 1.7.0 with Plymouth artwork, the watcher optimization and the
      manual UI smoke.
- [x] Version 1.7.1 with shared reader locks and the pixel-diff helper.
- [x] Version 1.7.2 with redundant-write caching.
- [x] Add a manual UI smoke for the palette workflow
      (`tools/ui-smoke.sh`, with optional screenshots).
- [x] Add 100-write ordering and concurrent-writer coverage (TC-12).
- [x] Add a manual pixel-diff helper for UI smoke captures
      (`tools/ui-diff.sh`, optional crop for the live bar clock).
- [ ] Add committed golden baselines at 100%, 125% and 150% scale
      (environment-specific; capture with `ui-smoke.sh --screenshots`).
- [x] Artwork palette for wallpaper, SDDM login art and Plymouth boot art.
- Keep `README.md`, `README.vi.md`, `CHANGELOG.md`, `KEYBINDINGS.md` and this
  file in the same commit as any behavior change.

---

## Decisions taken before Phase 2

- The editor stays inside the Tools panel (no separate Appearance window).
- Artwork theming is deferred to 1.6.0; 1.5.0 is the palette/editor release.
- `$HOME/.local/state/virtual-paradise` is the project state convention;
  `XDG_STATE_HOME` is not consulted by these writers.
