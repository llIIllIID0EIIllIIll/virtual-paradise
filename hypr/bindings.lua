-- ==============================================================================
--  Virtual☆Paradise — Optimized Keybindings Configuration
-- ==============================================================================
--  Documentation: https://wiki.hypr.land/Configuring/Binds/
--  View all active bindings anytime: omarchy menu keybindings --print
-- ==============================================================================

-- 1. HARDWARE CONTROLS
--------------------------------------------------------------------------------
-- Unbind default Universal Copy on SUPER+C before binding Cooler Boost
hl.unbind("SUPER + C")
o.bind("SUPER + C", "Toggle Cooler Boost", "~/.local/bin/toggle_cooler_boost.sh")

-- 2. RICE & THEME CONTROLS
--------------------------------------------------------------------------------
-- Sequential Rice Layout: Fastfetch -> btop -> cava -> unimatrix
o.bind("SUPER + Q", "Rice Layout", "~/.local/bin/rice_layout.sh")

-- Cycle to next wallpaper in Virtual☆Paradise theme
o.bind("SUPER + N", "Next Wallpaper", "omarchy theme bg next")

-- Toggle Live Video Wallpaper (mpvpaper GPU playback)
o.bind("SUPER + ALT + UP", "Toggle Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh")
o.bind("SUPER + ALT + RIGHT", "Next Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh next")
o.bind("SUPER + ALT + LEFT", "Prev Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh prev")

-- Quick theme picker menu
o.bind("SUPER + SHIFT + T", "Theme Switcher", "omarchy-menu toggle theme")

-- Launch Matrix screensaver in terminal
o.bind("SUPER + BACKSLASH", "Matrix Screensaver", "omarchy launch screensaver")

-- 3. ERGONOMIC APP LAUNCHERS
--------------------------------------------------------------------------------
-- Default File Manager (Auto-detects Nautilus, Dolphin, Thunar, Nemo, Yazi, etc.)
o.bind("SUPER + E", "File Manager", "setsid uwsm-app -- xdg-open ~")

-- Default Web Browser (Auto-detects default browser)
o.bind("SUPER + B", "Web Browser", "omarchy launch browser")

-- Color Picker (Magnifier + Hex Copy)
o.bind("SUPER + SHIFT + C", "Color Picker", "omarchy-capture-color")