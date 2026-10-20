-- ==============================================================================
--  Virtual☆Paradise — Toolkit Environment & Display Handover
-- ==============================================================================
--
--  This file deliberately contains NO monitor rules.
--
--  Omarchy's display manager (hyprmoncfg) owns the layout: it applies a
--  profile per monitor setup, switches between them on hotplug, lid and
--  suspend, and writes the result to hyprmoncfg-monitors.lua, which is loaded
--  after everything else. Static rules here fought that: a hardcoded eDP-1
--  rule kept the laptop panel alive with scale 1 even when hyprmoncfg wanted
--  it off, and a fixed scale of 1.0 made every external display unreadable
--  on a HiDPI panel.
--
--  Leaving the layout alone is also what makes the theme work on any screen:
--  Hyprland picks the preferred mode, the position and the scale (including
--  the DPI-based automatic scale) on its own, and hyprmoncfg remembers the
--  arrangement per setup.
--
--  The one rule below only says "no special handling": any output that
--  hyprmoncfg does not manage still gets its preferred mode and the automatic
--  scale.
-- ==============================================================================

-- 1. TOOLKIT & WAYLAND ENVIRONMENT VARIABLES
--------------------------------------------------------------------------------
-- GDK_SCALE / QT_AUTO_SCREEN_SCALE_FACTOR are deliberately NOT pinned to 1.
-- Forcing them overrides Hyprland's per-monitor scale, which makes everything
-- tiny on HiDPI panels. Let the compositor decide.
hl.env("SHELL", "/usr/bin/zsh")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto") -- Crisp native Wayland for Electron apps (VS Code, Discord, Obsidian, Chrome)
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- 2. GENERIC OUTPUT FALLBACK
--------------------------------------------------------------------------------
-- No output is named, so this never pins a display to a port or a scale.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})

-- 3. XWAYLAND SCALING
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
