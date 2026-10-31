# Virtual☆Paradise Keybindings

Omarchy already ships a full set of default bindings. Hyprland does **not**
replace a binding when the same chord is bound again — it runs every matching
bind. The theme therefore only adds bindings on chords Omarchy leaves free.

If a default really has to be replaced, call `hl.unbind("...")` on the line
before the new bind. `tools/check-bindings.py` fails when a chord is repeated or
shadows an Omarchy default.

See every active binding with `SUPER + K` (or
`omarchy-menu-keybindings --print`).

## Theme additions

| Shortcut | Action |
|----------|--------|
| `SUPER + Q` | Rice layout (fastfetch → btop → cava → unimatrix) |
| `SUPER + N` | Next static wallpaper |
| `SUPER + ALT + W` | Toggle live video wallpaper |
| `SUPER + ALT + N` | Next live wallpaper |
| `SUPER + ALT + SHIFT + N` | Previous live wallpaper |
| `SUPER + ALT + RIGHT` | Next live wallpaper (arrow) |
| `SUPER + ALT + LEFT` | Previous live wallpaper (arrow) |
| `SUPER + ALT + C` | Toggle cooler boost |
| `SUPER + SHIFT + T` | Open the Omarchy theme menu |
| `SUPER + E` | File manager (default app) |
| `SUPER + B` | Web browser (default app) |
| `SUPER + SHIFT + K` | Cast screen (wireless display) |
| `SUPER + SHIFT + L` | Lock screen |
| `SUPER + SHIFT + V` | VS Code |
| `SUPER + PERIOD` | Emoji picker |
| `SUPER + SHIFT + R` | Reload the Hyprland config |
| `SUPER + BACKSLASH` | Matrix screensaver |

### Resize mode

Press `SUPER + R`, then use `H`/`J`/`K`/`L` or the arrow keys. `ESC` or `RETURN`
leaves the mode.

## Omarchy defaults

These are intentionally **not** rebound by the theme:

- `SUPER + RETURN` — terminal
- `SUPER + K` — keybindings menu
- `SUPER + SPACE` — Omarchy menu (the card's border rides the theme's rotating
  gradient, same as the window borders)
- `SUPER + F` — fullscreen, `SUPER + T` — toggle floating
- `SUPER + P` — pseudo window, `SUPER + O` — pop window out (float & pin)
- `SUPER + TAB` / `SUPER + SHIFT + TAB` — next/previous workspace
- `SUPER + SHIFT + SPACE` — toggle the top bar
- `SUPER + ALT + CTRL + arrows` — move the window into the group on the left/right
  (Omarchy binds this on `SUPER + ALT + arrows`; the theme takes those two
  chords for the live wallpaper and moves the group action here, so exactly
  one action runs per press)
- `SUPER + V` — universal paste, `SUPER + CTRL + V` — clipboard history
- `SUPER + SHIFT + B` — browser, `SUPER + SHIFT + F` — file manager
- `SUPER + SHIFT + S` — Google Maps web app, `SUPER + SHIFT + W` — Omawrite
- `SUPER + SHIFT + E` — email web app (system menu is `SUPER + ESCAPE`)
- `SUPER + CTRL + L` — lock screen
- `PRINT`, `SUPER + PRINT`, `SUPER + CTRL + C` — screenshots

## Scripts (not bound)

These live in `~/.local/bin` after installation and are run from a terminal:

- `theme-switcher.sh` — switch the Virtual☆Paradise palette variant (`list`, `reset`)
- `effects.sh` — `rainbow`, `glow`, `toggle-blur`, `shake`, `focus-pulse`
- `toggle_live_wallpaper.sh` — `init`, `next`, `prev` (also used by the keys above)

The rotating gradient window borders, shadows and glow are part of the theme
itself (`borderangle` / `shadowangle` / `glowangle` in `hypr/looknfeel.lua`),
not one of these scripts.
