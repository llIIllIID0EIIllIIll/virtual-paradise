-- ==============================================================================
--  Virtual☆Paradise — Full-Topping Monitor & Display Configuration
-- ==============================================================================
--  Documentation: https://wiki.hypr.land/Configuring/Basics/Monitors/
--                 https://wiki.hypr.land/Configuring/Basics/Variables/#xwayland
--  List monitors & supported modes anytime: hyprctl monitors all
-- ==============================================================================

-- 1. TOOLKIT & WAYLAND ENVIRONMENT VARIABLES (Crisp HiDPI & Zero Blurriness)
--------------------------------------------------------------------------------
hl.env("GDK_SCALE", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto") -- Crisp native Wayland for Electron apps (VS Code, Discord, Obsidian, Chrome)
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XCURSOR_SIZE", "24")

-- 2. PRIMARY DISPLAY AUTO-DETECTION (Laptop eDP-1 or Desktop Primary)
--------------------------------------------------------------------------------
hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "0x0",
  scale = 1.0,
  transform = 0,
})

-- 3. EXTERNAL & PLUG-AND-PLAY DISPLAY PRESETS (HDMI / DisplayPort / USB-C)
--------------------------------------------------------------------------------
hl.monitor({
  output = "HDMI-A-1",
  mode = "preferred",
  position = "auto-right",
  scale = 1.0,
})

hl.monitor({
  output = "DP-1",
  mode = "preferred",
  position = "auto-right",
  scale = 1.0,
})

hl.monitor({
  output = "DP-2",
  mode = "preferred",
  position = "auto-right",
  scale = 1.0,
})

-- Universal Plug & Play Fallback for Any Monitor / Resolution / Refresh Rate
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})

-- 4. XWAYLAND CRISP RENDERING (Prevent blurry X11 apps)
--------------------------------------------------------------------------------
hl.config({
  xwayland = {
    force_zero_scaling = true,
  },
})

-- 5. WORKSPACE TO MONITOR ASSIGNMENTS (Optional Best Practice)
--------------------------------------------------------------------------------
-- Keep core workspaces on primary screen eDP-1
-- hl.workspace({ "1", monitor = "eDP-1", default = true })
-- hl.workspace({ "2", monitor = "eDP-1" })
-- hl.workspace({ "3", monitor = "eDP-1" })
-- Route secondary workspaces to external monitor when connected
-- hl.workspace({ "4", monitor = "HDMI-A-1" })
-- hl.workspace({ "5", monitor = "HDMI-A-1" })
