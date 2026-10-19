-- ==============================================================================
--  Virtual☆Paradise — Full-Topping Keybindings Configuration
-- ==============================================================================
--  Documentation: https://wiki.hypr.land/Configuring/Binds/
--  View all active bindings anytime: omarchy menu keybindings --print
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

-- Toggle Live Video Wallpaper (mpvpaper GPU playback)
o.bind("SUPER + ALT + UP", "Toggle Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh")
o.bind("SUPER + ALT + RIGHT", "Next Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh next")
o.bind("SUPER + ALT + LEFT", "Prev Live Wallpaper", "~/.local/bin/toggle_live_wallpaper.sh prev")

-- Quick theme picker menu
o.bind("SUPER + SHIFT + T", "Theme Switcher", "omarchy-menu toggle theme")

-- Launch Matrix screensaver in terminal
o.bind("SUPER + backslash", "Matrix Screensaver", "omarchy launch screensaver")

-- 3. ERGONOMIC APP LAUNCHERS
--------------------------------------------------------------------------------
-- Default File Manager (Auto-detects Nautilus, Dolphin, Thunar, Nemo, Yazi, etc.)
o.bind("SUPER + E", "File Manager", "setsid uwsm-app -- xdg-open ~")

-- Default Web Browser (Auto-detects default browser)
o.bind("SUPER + B", "Web Browser", "omarchy launch browser")

-- Color Picker (Magnifier + Hex Copy)
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Color Picker", "omarchy-capture-color")

-- 4. WIRELESS PROJECTION / CAST SCREEN (Cast Screen)
--------------------------------------------------------------------------------
o.bind("SUPER + SHIFT + K", "Cast Screen (Wireless Display)", "~/.local/bin/cast_screen.sh")

-- 5. WINDOW MANAGEMENT ENHANCEMENTS
--------------------------------------------------------------------------------
-- Center floating window
o.bind("SUPER + SHIFT + SPACE", "Center Window", "hyprctl dispatch centerwindow")

-- Toggle floating
o.bind("SUPER + F", "Toggle Floating", "hyprctl dispatch togglefloating")

-- Toggle fullscreen (keep decorations)
o.bind("SUPER + SHIFT + F", "Fake Fullscreen", "hyprctl dispatch fakefullscreen")

-- Pin window (keep on all workspaces)
o.bind("SUPER + P", "Pin Window", "hyprctl dispatch pin")

-- Toggle opaque (force no transparency)
o.bind("SUPER + O", "Toggle Opaque", "hyprctl dispatch toggleopaque")

-- 6. WORKSPACE NAVIGATION
--------------------------------------------------------------------------------
-- Move to next/prev workspace with wrap
o.bind("SUPER + TAB", "Next Workspace", "hyprctl dispatch workspace +1")
o.bind("SUPER + SHIFT + TAB", "Prev Workspace", "hyprctl dispatch workspace -1")

-- Move window to next/prev workspace
o.bind("SUPER + ALT + TAB", "Move Window Next WS", "hyprctl dispatch movetoworkspace +1")
o.bind("SUPER + ALT + SHIFT + TAB", "Move Window Prev WS", "hyprctl dispatch movetoworkspace -1")

-- 7. WINDOW FOCUS & MOVEMENT
--------------------------------------------------------------------------------
-- Focus navigation (vim-style)
o.bind("SUPER + H", "Focus Left", "hyprctl dispatch movefocus l")
o.bind("SUPER + L", "Focus Right", "hyprctl dispatch movefocus r")
o.bind("SUPER + K", "Focus Up", "hyprctl dispatch movefocus u")
o.bind("SUPER + J", "Focus Down", "hyprctl dispatch movefocus d")

-- Move window (vim-style)
o.bind("SUPER + SHIFT + H", "Move Window Left", "hyprctl dispatch movewindow l")
o.bind("SUPER + SHIFT + L", "Move Window Right", "hyprctl dispatch movewindow r")
o.bind("SUPER + SHIFT + K", "Move Window Up", "hyprctl dispatch movewindow u")
o.bind("SUPER + SHIFT + J", "Move Window Down", "hyprctl dispatch movewindow d")

-- 8. WINDOW RESIZE
--------------------------------------------------------------------------------
-- Resize mode (press SUPER + R, then HJKL or arrows, ESC/RETURN to leave).
-- Submaps are first-class in the Lua config: entering one is a dispatcher
-- (hl.dsp.submap) and the binds live in hl.define_submap. The old hyprlang
-- strings ("submap, resize") are not dispatchers here — they were being
-- executed as shell commands, so the submap never actually opened.
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

-- 9. SCRATCHPAD & SPECIAL WORKSPACES
--------------------------------------------------------------------------------
-- Toggle scratchpad (special workspace)
o.bind("SUPER + MINUS", "Toggle Scratchpad", "hyprctl dispatch togglespecialworkspace scratchpad")

-- Move window to scratchpad
o.bind("SUPER + SHIFT + MINUS", "Move to Scratchpad", "hyprctl dispatch movetoworkspace special:scratchpad")

-- 10. SCREENSHOT & RECORDING
--------------------------------------------------------------------------------
-- Screenshot region
o.bind("SUPER + SHIFT + S", "Screenshot Region", "omarchy-capture-screen region")

-- Screenshot window
o.bind("SUPER + SHIFT + W", "Screenshot Window", "omarchy-capture-screen window")

-- Screenshot full screen
o.bind("SUPER + SHIFT + PRINT", "Screenshot Full", "omarchy-capture-screen full")

-- Screen recording
o.bind("SUPER + ALT + R", "Toggle Recording", "omarchy-capture-screen record")

-- 11. CLIPBOARD & HISTORY
--------------------------------------------------------------------------------
-- Clipboard manager
o.bind("SUPER + V", "Clipboard History", "omarchy-menu clipboard")

-- Emoji picker
o.bind("SUPER + PERIOD", "Emoji Picker", "omarchy-menu emojis")

-- 12. SYSTEM CONTROLS
--------------------------------------------------------------------------------
-- Lock screen
o.bind("SUPER + SHIFT + L", "Lock Screen", "omarchy lock")

-- Logout menu
o.bind("SUPER + SHIFT + E", "Logout Menu", "omarchy menu logout")

-- Reload Hyprland config
o.bind("SUPER + SHIFT + R", "Reload Config", "hyprctl reload")

-- 13. DEVELOPMENT TOOLS
--------------------------------------------------------------------------------
-- Launch terminal
o.bind("SUPER + RETURN", "Terminal", "omarchy launch terminal")

-- Launch editor (VS Code)
o.bind("SUPER + SHIFT + V", "VS Code", "setsid uwsm-app -- code")

-- Launch system monitor (btop)
o.bind("SUPER + SHIFT + B", "System Monitor", "omarchy launch terminal btop")
