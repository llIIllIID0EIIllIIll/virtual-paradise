-- ==============================================================================
--  Virtual☆Paradise — extra keybindings
-- ==============================================================================
--  Omarchy 4 already ships a complete set of default bindings. Binding a chord
--  that is already bound does not replace it: Hyprland runs both. SUPER + RETURN
--  used to launch two terminals that way, SUPER + SHIFT + K moved a window and
--  opened the cast dialog, and so on.
--
--  Keep this file to additions on chords Omarchy leaves free. If a default
--  really has to be replaced, call hl.unbind("...") first, on the line before
--  the new bind.
--
--  Check for conflicts before committing:
--    python3 tools/check-bindings.py
--  See every active binding:
--    omarchy-menu-keybindings --print   (SUPER + K)
-- ==============================================================================

-- 1. HARDWARE CONTROLS
--------------------------------------------------------------------------------
o.bind("SUPER + ALT + C", "Toggle Cooler Boost", "~/.local/bin/toggle_cooler_boost.sh")

-- 2. RICE & THEME CONTROLS
--------------------------------------------------------------------------------
-- Sequential Rice Layout: Fastfetch -> btop -> cava -> unimatrix
o.bind("SUPER + Q", "Rice Layout", "~/.local/bin/rice_layout.sh")

-- Cycle to next wallpaper in Virtual☆Paradise theme
o.bind("SUPER + N", "Next Wallpaper", "omarchy theme bg next")

-- Live video wallpapers.
--
-- The arrows live on SUPER + ALT, where they have always been. Omarchy binds
-- that pair to "move window to group", and Hyprland runs *every* bind of a
-- chord instead of replacing one, so binding the wallpaper there as well
-- switched the wallpaper and moved the window into a group at the same time.
-- That is why the arrows disappeared in 1.2.2.
--
-- This time the pair is replaced on purpose: hl.unbind() removes Omarchy's
-- two binds first, so exactly one action runs. The group move is not lost -
-- it moves to SUPER + ALT + CTRL + arrows, which Omarchy leaves free.
hl.unbind("SUPER + ALT + LEFT")
hl.unbind("SUPER + ALT + RIGHT")
o.bind("SUPER + ALT + RIGHT", "Next Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh next")
o.bind("SUPER + ALT + LEFT", "Previous Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh prev")
o.bind("SUPER + ALT + CTRL + RIGHT", "Move window to group on right", hl.dsp.window.move({ into_group = "r" }))
o.bind("SUPER + ALT + CTRL + LEFT", "Move window to group on left", hl.dsp.window.move({ into_group = "l" }))

-- The same actions without the arrows, for keyboards where they are easier
-- to reach: W toggles, N cycles forward, SHIFT + N backward.
o.bind("SUPER + ALT + W", "Toggle Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh")
o.bind("SUPER + ALT + N", "Next Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh next")
o.bind("SUPER + ALT + SHIFT + N", "Previous Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh prev")

-- Omarchy theme menu (the theme-variant script is a separate terminal tool)
o.bind("SUPER + SHIFT + T", "Theme Menu", "omarchy-menu toggle theme")

-- Launch Matrix screensaver in terminal
o.bind("SUPER + backslash", "Matrix Screensaver", "omarchy launch screensaver")

-- 3. ERGONOMIC APP LAUNCHERS
--------------------------------------------------------------------------------
-- Free chords: Omarchy uses SUPER + SHIFT + F / B / N for the same apps.
-- Default File Manager (Auto-detects Nautilus, Dolphin, Thunar, Nemo, Yazi, etc.)
o.bind("SUPER + E", "File Manager", "setsid uwsm-app -- xdg-open ~")

-- Default Web Browser (Auto-detects default browser)
o.bind("SUPER + B", "Web Browser", "omarchy launch browser")

-- 4. WIRELESS PROJECTION / CAST SCREEN
--------------------------------------------------------------------------------
o.bind("SUPER + SHIFT + K", "Cast Screen (Wireless Display)", "~/.local/bin/cast_screen.sh")

-- 5. WINDOW RESIZE SUBMAP
--------------------------------------------------------------------------------
-- Resize mode (press SUPER + R, then HJKL or arrows, ESC/RETURN to leave).
o.bind("SUPER + R", "Resize Mode", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
  o.bind("H", "Resize Left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
  o.bind("L", "Resize Right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
  o.bind("K", "Resize Up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
  o.bind("J", "Resize Down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })
  o.bind("LEFT", "Resize Left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
  o.bind("RIGHT", "Resize Right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
  o.bind("UP", "Resize Up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
  o.bind("DOWN", "Resize Down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })
  o.bind("ESCAPE", "Exit Resize", hl.dsp.submap("reset"))
  o.bind("RETURN", "Exit Resize", hl.dsp.submap("reset"))
end)

-- 6. UTILITIES
--------------------------------------------------------------------------------
-- Emoji picker (Omarchy's default is SUPER + CTRL + E; this is a shorter alias)
o.bind("SUPER + PERIOD", "Emoji Picker", "omarchy-shell shell toggle omarchy.emojis")

-- Launch editor (VS Code)
o.bind("SUPER + SHIFT + V", "VS Code", "setsid uwsm-app -- code")

-- Lock screen (Omarchy's default is SUPER + CTRL + L)
o.bind("SUPER + SHIFT + L", "Lock Screen", "omarchy-system-lock")

-- Reload Hyprland config
o.bind("SUPER + SHIFT + R", "Reload Config", "hyprctl reload")
