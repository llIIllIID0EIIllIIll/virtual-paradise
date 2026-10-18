# Virtual☆Paradise Keybindings (New Features)

## Theme Variants
- `SUPER + SHIFT + T` — Open theme variant switcher (interactive menu)
- Switch between: cyberpunk, cozy, monochrome, neon, sakura

## Floating Widgets
- `SUPER + W` — Toggle all floating widgets
- `SUPER + SHIFT + W` — Widget menu (select individual widgets)
  - Clock widget (large time/date)
  - System stats (CPU, RAM, temp)
  - Weather widget

## Visual Effects
- `SUPER + SHIFT + E` — Toggle blur (performance vs aesthetic)
- `SUPER + ALT + E` — Shake active window (error feedback)

## Usage Examples

### Theme Switcher
```bash
# Interactive menu (requires fzf for best experience)
theme-switcher.sh

# Direct switch
theme-switcher.sh cyberpunk
theme-switcher.sh cozy
theme-switcher.sh monochrome

# List available variants
theme-switcher.sh list
```

### Floating Widgets
```bash
# Toggle all widgets
widgets.sh all

# Toggle individual widgets
widgets.sh clock
widgets.sh stats
widgets.sh weather

# Stop all widgets
widgets.sh stop
```

### Visual Effects
```bash
# Toggle blur
effects.sh toggle-blur

# Shake window (error feedback)
effects.sh shake

# Start rainbow borders (continuous)
effects.sh rainbow

# Start glow effect (continuous)
effects.sh glow

# Flash border on focus
effects.sh focus-pulse
```

## Requirements

### For Theme Switcher
- `fzf` (optional, for interactive menu)
- `omarchy-shell` (for live reload)

### For Floating Widgets
- `eww` (Elkowar's Wacky Widgets)
- Widget configs auto-generated on first run

### For Visual Effects
- `hyprctl` (included with Hyprland)
- `jq` (for JSON parsing)

## Customization

### Add Custom Theme Variants
Edit `bin/theme-switcher.sh` and add to `VARIANTS` array:
```bash
VARIANTS["mytheme"]="ff0000:00ff00:0000ff:000000"
# Format: accent:secondary:tertiary:background
```

### Add Custom Widgets
Create new widget config in `~/.config/virtual-paradise/widgets/`:
```bash
# Example: custom.yuck
(defwindow custom
  :geometry (geometry :x "100px" :y "100px" :width "200px" :height "100px")
  :stacking "fg"
  :window-type "dock"
  (box :class "custom-widget"
    (label :text "Hello World")))
```

Then add toggle function in `widgets.sh`.

## Notes

- Widgets use `eww` for rendering (lightweight, fast)
- Theme variants update `colors.toml` and reload automatically
- Effects are non-blocking (run in background)
- All scripts support `--help` for usage info
