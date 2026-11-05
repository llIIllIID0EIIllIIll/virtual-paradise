-- ==============================================================================
--  Virtual☆Paradise — extra keybindings
-- ==============================================================================
--  Omarchy already ships a complete set of default bindings, and Hyprland does
--  not replace a binding when the same chord is bound again: every matching
--  bind runs. The theme therefore only adds bindings on chords Omarchy leaves
--  free. It does not unbind or shadow a default - if Omarchy owns an action,
--  that default is what runs.
--
--  Actions that used to have a theme alias (close, theme menu, file manager,
--  browser, lock, emoji, editor, wallpaper switcher) are now Omarchy's:
--
--    SUPER + Q / SUPER + W      close window
--    SUPER + CTRL + T           theme menu
--    SUPER + SHIFT + F          file manager
--    SUPER + SHIFT + B          browser
--    SUPER + CTRL + L           lock system
--    SUPER + CTRL + E           emojis
--    SUPER + SHIFT + N          editor (Omarchy's configured editor)
--    SUPER + CTRL + SPACE / W   background switcher
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
-- Sequential Rice Layout: Fastfetch -> btop -> cava -> unimatrix.
o.bind("SUPER + ALT + Q", "Rice Layout", "~/.local/bin/rice_layout.sh")

-- Live video wallpapers. These are theme-only actions (Omarchy's background
-- switcher picks a background; these cycle the theme's live playlist without
-- opening it), so they live on free SUPER + ALT chords.
o.bind("SUPER + ALT + W", "Toggle Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh")
o.bind("SUPER + ALT + N", "Next Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh next")
o.bind("SUPER + ALT + SHIFT + N", "Previous Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh prev")

-- Closing a window deserves a proper death: a red glitch burst burns where
-- the window was, then goes out half a second later. Omarchy's SUPER + Q and
-- SUPER + W close plainly now; the effect keeps its own free chord so the
-- default close stays exactly as Omarchy ships it.
o.bind("SUPER + CTRL + Q", "Close Window (Red Glitch Death)", "~/.local/bin/window_death.sh")

-- Launch Matrix screensaver in terminal
o.bind("SUPER + backslash", "Matrix Screensaver", "omarchy launch screensaver")

-- 3. WIRELESS PROJECTION / CAST SCREEN
--------------------------------------------------------------------------------
o.bind("SUPER + SHIFT + K", "Cast Screen (Wireless Display)", "~/.local/bin/cast_screen.sh")

-- 4. WINDOW RESIZE SUBMAP
--------------------------------------------------------------------------------
-- Resize mode (press SUPER + R, then HJKL or arrows, ESC/RETURN to leave).
-- Omarchy resizes with the mouse; this submap is the keyboard equivalent the
-- theme adds on a free chord.
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

-- 5. UTILITIES
--------------------------------------------------------------------------------
-- Reload Hyprland config. Omarchy has no default for this one.
o.bind("SUPER + SHIFT + R", "Reload Config", "hyprctl reload")
