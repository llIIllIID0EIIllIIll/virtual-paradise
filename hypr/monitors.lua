-- ==============================================================================
--  Virtual☆Paradise — Full-Topping Monitor & Display Configuration
-- ==============================================================================
--  Documentation: https://wiki.hypr.land/Configuring/Basics/Monitors/
--                 https://wiki.hypr.land/Configuring/Basics/Variables/#xwayland
--  List monitors & supported modes anytime: hyprctl monitors all
-- ==============================================================================

-- 1. TOOLKIT & WAYLAND ENVIRONMENT VARIABLES
--------------------------------------------------------------------------------
-- GDK_SCALE / QT_AUTO_SCREEN_SCALE_FACTOR are deliberately NOT pinned to 1.
-- Forcing them overrides Hyprland's per-monitor scale, which makes everything
-- tiny on HiDPI panels. Let the compositor decide; enable fractional scaling
-- with `hyprctl keyword misc:force_default_scale 2` or per-monitor `scale`.
hl.env("SHELL", "/usr/bin/zsh")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
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

-- 4. XWAYLAND SCALING
--------------------------------------------------------------------------------
-- force_zero_scaling pins Xwayland windows to scale 1 on scaled displays, which
-- is the opposite of the "prevent blurry X11 apps" claim: it makes X11 apps
-- render at 1x and upscale. Blur is controlled separately by
-- `xwayland.use_nearest_neighbor` (crisper) versus fractional scaling.
hl.config({
  xwayland = {
    force_zero_scaling = false,
  },
})

-- 5. WORKSPACE TO MONITOR ASSIGNMENTS (Optional Best Practice)
--------------------------------------------------------------------------------
-- The real API is hl.workspace_rule({ workspace = "1", monitor = "eDP-1" });
-- there is no hl.workspace() function, so uncommenting the lines below as-is
-- would raise a Lua error.
-- hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })
-- hl.workspace_rule({ workspace = "2", monitor = "eDP-1" })
-- hl.workspace_rule({ workspace = "3", monitor = "eDP-1" })
-- Route secondary workspaces to external monitor when connected
-- hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1" })
-- hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1" })
