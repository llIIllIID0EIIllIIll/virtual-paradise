# Virtual☆Paradise Keybindings

Omarchy already ships a full set of default bindings. Hyprland does **not**
replace a binding when the same chord is bound again — it runs every matching
bind. The theme therefore only adds bindings on chords Omarchy leaves free, and
it does not shadow an Omarchy default - with one deliberate exception: the two
close chords keep Omarchy's mapping but run the theme's red glitch death.

`tools/check-bindings.py` fails when a chord is repeated or shadows an Omarchy
default. See every active binding with `SUPER + K` (or
`omarchy-menu-keybindings --print`).

## Theme additions

These are the features Omarchy does not have a default for:

| Shortcut | Action |
|----------|--------|
| `SUPER + ALT + Q` | Rice layout (fastfetch → btop → cava → unimatrix) |
| `SUPER + ALT + W` | Toggle live video wallpaper |
| `SUPER + ALT + N` | Next live wallpaper |
| `SUPER + ALT + SHIFT + N` | Previous live wallpaper |
| `SUPER + ALT + C` | Toggle cooler boost |
| `SUPER + SHIFT + K` | Cast screen (wireless display) |
| `SUPER + SHIFT + R` | Reload the Hyprland config |
| `SUPER + BACKSLASH` | Matrix screensaver |

### Resize mode

Press `SUPER + R`, then use `H`/`J`/`K`/`L` or `LEFT`/`RIGHT`/`UP`/`DOWN`.
`ESC` or `RETURN` leaves the mode.

## Omarchy defaults

The theme leaves these to Omarchy — there are no theme aliases to remember:

- `SUPER + Q` / `SUPER + W` — close window, with the theme's red glitch death
  (the only deliberate exception: the chord is Omarchy's, the effect is ours)
- `SUPER + RETURN` — terminal
- `SUPER + K` — keybindings menu
- `SUPER + SPACE` — Omarchy menu (the card's border rides the theme's rotating
  gradient, same as the window borders)
- `SUPER + CTRL + T` / `SUPER + SHIFT + CTRL + SPACE` — theme menu
- `SUPER + CTRL + SPACE` / `SUPER + CTRL + W` — background switcher
- `SUPER + SHIFT + F` — file manager, `SUPER + SHIFT + B` — browser
- `SUPER + SHIFT + N` — editor (the editor selected in Omarchy defaults)
- `SUPER + CTRL + L` — lock screen
- `SUPER + CTRL + E` — emoji picker
- `SUPER + F` — fullscreen, `SUPER + T` — toggle floating
- `SUPER + P` — pseudo window, `SUPER + O` — pop window out (float & pin)
- `SUPER + TAB` / `SUPER + SHIFT + TAB` — next/previous workspace
- `SUPER + SHIFT + SPACE` — toggle the top bar
- `SUPER + ALT + arrows` — move the window into the group on that side
- `SUPER + V` — universal paste, `SUPER + CTRL + V` — clipboard history
- `SUPER + SHIFT + S` — Google Maps web app, `SUPER + SHIFT + W` — Omawrite
- `SUPER + SHIFT + E` — email web app (system menu is `SUPER + ESCAPE`)
- `SUPER + SHIFT + T` — activity (btop)
- `PRINT`, `SUPER + PRINT`, `SUPER + CTRL + C` — screenshots

## Scripts (not bound)

These live in `~/.local/bin` after installation and are run from a terminal:

- `theme-switcher.sh` — switch the Virtual☆Paradise palette variant (`list`, `reset`, `wallpaper`)
- `effects.sh` — `rainbow`, `glow`, `toggle-blur`, `shake`, `focus-pulse`
- `screensaver.sh` — `matrix`, `starfield`, `miku`
- `toggle_live_wallpaper.sh` — `init`, `next`, `prev` (also used by the keys above)

The rotating gradient window borders, shadows and glow are part of the theme
itself (`borderangle` / `shadowangle` / `glowangle` in `hypr/looknfeel.lua`),
not one of these scripts.
