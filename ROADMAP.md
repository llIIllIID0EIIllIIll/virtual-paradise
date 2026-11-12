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
  recolors on its next 300 ms poll with no Apply button and no shell restart.
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

## Known limits after Phase 1

- The editor has no undo/redo or one-click reset to the active palette.
- No contrast check: a light Background with light Text is allowed.
- Swatches are mouse/touch only; keyboard and screen-reader navigation of the
  board needs work.
- Wallpaper, Plymouth and SDDM artwork stay cyberpunk for every palette.
- Existing terminal sessions may need a reload to see the debounced text-file
  changes; the bar itself is live.
- The bar polls the small palette file every 300 ms rather than using a
  reliable cross-inode watch. It is cheap, but a shared watcher would be
  cleaner.
- `theme-switcher.sh` and `vp-palette.sh` do not share one lock. The panel
  avoids the race, but two CLI writers could still overlap.

---

## Phase 2 — Portable, accessible, deeper live theming

**Theme:** “make the palette something a user can own, share and trust.”

### P0 — Reliability and reach

1. **One palette pipeline**
   - Share a single `flock` between `vp-palette.sh`, `theme-switcher.sh` and any
     future writer.
   - Add a small long-lived writer/daemon so a swatch click does not spawn
     Python, and expose a `palette revision` counter.
   - Acceptance: 100 rapid writes finish with the newest color, valid JSON, no
     temp files, one process.
2. **Consistent state and errors**
   - Decide once whether the theme uses `XDG_STATE_HOME` or `$HOME`; apply it to
     every script and QML reader.
   - Surface write failures in the panel (small inline status instead of a
     silent no-op).
   - Acceptance: a read-only state directory produces a visible error and the
     bar keeps its last good palette.

### P1 — Editor UX and accessibility

3. **Undo, redo, reset, preview**
   - Keep an in-memory history of palette states.
   - Reset to the active named palette (without switching variants).
   - Show a tiny live preview card (bar chrome + terminal sample) before commit.
4. **Contrast and color-vision checks**
   - Compute WCAG contrast for Text/Background and warn below 4.5:1.
   - Optional deuteranopia/protanopia preview of the eight roles.
   - Acceptance: a low-contrast pair shows a warning and a suggested Text
     color.
5. **Keyboard and screen-reader support**
   - Tab/arrow navigation across roles and swatches, Enter/Space to pick,
     visible focus ring, `Accessible.description` with the role name and hex.
   - Acceptance: the whole editor works without a pointer.

### P1 — Portable themes

6. **Save, export, import**
   - Named user palettes stored as `~/.local/state/virtual-paradise/themes/*.json`
     with a schema version and optional author/name metadata.
   - Copy-paste/export JSON and import with validation.
   - Acceptance: round-trip export → reset → import restores all eight roles.
7. **Seed-color generation**
   - From one Accent, offer harmony modes (analogous, complementary, triadic)
     and neutral Background/Text derivation.
   - Keep manual override for every derived role.

### P2 — Artwork and deeper live apply

8. **Artwork palettes**
   - Optional wallpaper/SDDM/Plymouth artwork selection per custom theme, or a
     curated artwork pack that matches the chrome palette.
   - Keep the current cyberpunk artwork as the default and as a fallback.
   - Acceptance: selecting artwork never leaves a missing file or a boot entry
     pointing at a deleted image.
9. **Live consumers**
   - Notify running terminals (OSC 4/10/11), GTK apps, VS Code, Cava, btop,
     fastfetch and the shell from the same palette revision.
   - Acceptance: changing Accent updates a running terminal and the bar without
     a restart; app support is documented per consumer.

### Release and test gates

- Keep the suite sandboxed; add UI automation for role selection, one swatch
  click, reset and import.
- Add golden screenshots for the board at 100%, 125% and 150% scale.
- Run Ubuntu and Arch CI; run the release dry-run.
- Version 1.5.0 when P0/P1 are green; keep artwork work allowed to ship in
  1.6.0.
- Update `README.md`, `README.vi.md`, `CHANGELOG.md`, `KEYBINDINGS.md` and this
  file in the same commit as the behavior change.

---

## Decisions needed before Phase 2 starts

- Is the editor staying inside the Tools panel, or should Appearance become its
  own panel with more room?
- Should custom themes include artwork in 1.5.0, or keep artwork for 1.6.0?
- Is `XDG_STATE_HOME` support required, or is `$HOME/.local/state` the project
  convention?
