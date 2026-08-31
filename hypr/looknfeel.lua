-- ==============================================================================
--  Virtual☆Paradise — Full-Topping Look'n'Feel Configuration
-- ==============================================================================
--  Documentation: https://wiki.hypr.land/Configuring/Basics/Variables/
--                 https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- ==============================================================================

local activeBorderGradient = {
  colors = { "rgba(00f5d4ee)", "rgba(00f5d4ee)", "rgba(00ff88dd)", "rgba(ffb7d5ee)", "rgba(ffb7d5ee)" },
  angle = 45,
}
local inactiveBorderColor = "rgba(182833aa)"
local activeNeonGlow = "rgba(00f5d428)"
local inactiveShadow = "rgba(00000099)"

hl.config({
  -- 1. GENERAL WINDOW GEOMETRY & BORDERS
  ------------------------------------------------------------------------------
  general = {
    -- Golden ratio gaps: creates space to show off wallpaper & gradient borders
    gaps_in = 5,
    gaps_out = 10,
    gaps_workspaces = 0,
    float_gaps = 5,

    -- Multi-stop neon border
    border_size = 2,
    col = {
      active_border = activeBorderGradient,
      inactive_border = inactiveBorderColor,
    },

    -- Easy window edge grabbing & resizing
    resize_on_border = true,
    extend_border_grab_area = 20,
    hover_icon_on_border = true,

    -- Tiling Layout
    layout = "dwindle",
    allow_tearing = true,
  },

  -- 2. DECORATION: FROSTED GLASS ACRYLIC, SHADOWS & DIMMING
  ------------------------------------------------------------------------------
  decoration = {
    -- Modern soft squircle corners
    rounding = 12,
    rounding_power = 2,

    -- Opacity hierarchy (Clear focus & deep readability)
    active_opacity = 0.96,
    inactive_opacity = 0.85,
    fullscreen_opacity = 1.0,

    -- Multi-pass Frosted Glass Acrylic Blur
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      ignore_opacity = true,
      new_optimizations = true,
      xray = false,
      noise = 0.02,
      contrast = 0.95,
      brightness = 0.85,
      vibrancy = 0.35,
      vibrancy_darkness = 0.5,
      popups = true,
      popups_ignorealpha = 0.6,
    },

    -- 3D Neon Glow Shadows
    shadow = {
      enabled = true,
      range = 22,
      render_power = 3,
      color = activeNeonGlow,
      color_inactive = inactiveShadow,
      offset = "0 2",
    },

    -- Subtle dimming for non-focused windows & overlays
    dim_inactive = false,
    dim_strength = 0.0,
    dim_special = 0.15,
    dim_around = 0.0,
  },

  -- 3. TABBED / GROUPED WINDOWS STYLING
  ------------------------------------------------------------------------------
  group = {
    col = {
      border_active = activeBorderGradient,
      border_inactive = inactiveBorderColor,
    },
    groupbar = {
      enabled = true,
      font_family = "sans-serif",
      font_size = 10,
      height = 20,
      indicator_height = 2,
      indicator_gap = 4,
      gaps_in = 4,
      gaps_out = 0,
      text_color = "rgb(eafbfa)",
      text_color_inactive = "rgba(eafbfa80)",
      col = {
        active = "rgba(00f5d466)",
        inactive = "rgba(07080d99)",
      },
      gradients = true,
      gradient_rounding = 8,
    },
  },

  -- 4. DWINDLE LAYOUT BEST PRACTICES
  ------------------------------------------------------------------------------
  dwindle = {
    preserve_split = true,      -- Keep split direction when opening/closing tiles
    smart_split = false,        -- Predictable split behavior
    smart_resizing = true,      -- Intelligent resizing across siblings
    force_split = 2,            -- Always split to the bottom/right cleanly
  },

  -- 5. MASTER LAYOUT OPTIONS
  ------------------------------------------------------------------------------
  master = {
    new_status = "master",
    mfact = 0.55,
  },

  -- 6. SYSTEM MISC & PERFORMANCE
  ------------------------------------------------------------------------------
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    focus_on_activate = true,
    animate_manual_resizes = true,
    animate_mouse_windowdragging = true,
    vrr = 1,                    -- Variable refresh rate for gaming / low latency
  },

  -- 7. ANIMATIONS SWITCH
  ------------------------------------------------------------------------------
  animations = {
    enabled = true,
    workspace_wraparound = false, -- Strict linear direction: lower IDs on left, higher IDs on right
  },
})

-- ==============================================================================
--  8. CYBERPUNK FLUID BEZIER ANIMATIONS
-- ==============================================================================

-- Custom Beziers (Silky Smooth & Cyber Responsive)
hl.curve("cyberSpring", { type = "bezier", points = { { 0.18, 0.9 }, { 0.25, 1.12 } } })
hl.curve("fluentDecel", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("quickFade", { type = "bezier", points = { { 0.15, 0.0 }, { 0.1, 1.0 } } })
hl.curve("workspaceGlide", { type = "bezier", points = { { 0.16, 1.0 }, { 0.3, 1.0 } } })
hl.curve("workspaceSpring", { type = "bezier", points = { { 0.34, 1.2 }, { 0.64, 1.0 } } })

-- Window animations
hl.animation({ leaf = "windows", enabled = true, speed = 4.2, bezier = "cyberSpring" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.0, bezier = "cyberSpring", style = "popin 82%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.2, bezier = "quickFade", style = "popin 82%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.2, bezier = "fluentDecel" })

-- Border color transition (Fast, Crisp & Silky Smooth)
hl.animation({ leaf = "border", enabled = true, speed = 8.5, bezier = "quickFade" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.8, bezier = "quickFade" })

-- Layers & Popups (Launcher, menus, notifications)
hl.animation({ leaf = "layers", enabled = true, speed = 4.0, bezier = "fluentDecel", style = "slidefade 20%" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4.2, bezier = "cyberSpring", style = "slidefade 20%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3.2, bezier = "quickFade", style = "fade" })

-- Workspace transitions (Silky Smooth Slidefade with 35% Alpha Blend)
hl.animation({ leaf = "workspaces", enabled = true, speed = 5.0, bezier = "workspaceGlide", style = "slidefade 35%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.2, bezier = "workspaceGlide", style = "slidefadevert 35%" })

-- ==============================================================================
--  9. POPUPS & PANELS LAYER ANIMATIONS (Smooth Slidefade without Background Dim/Blur)
-- ==============================================================================
hl.layer_rule({ match = { namespace = "^(omarchy-menu|omarchy-keyboard-panel|omarchy-clipboard|omarchy-emojis|omarchy-bar-panel|omarchy-image-selector)$" }, animation = "slidefade 25%" })
hl.layer_rule({ match = { namespace = "omarchy-notifications" }, animation = "slidefade 25%" })
hl.layer_rule({ match = { namespace = "omarchy-osd" }, animation = "slidefadevert 30%" })

-- ==============================================================================
--  10. URGENT & ERROR WINDOWS (Blazing Neon Red Warning Border & Glow on Error)
-- ==============================================================================
local urgentBorderGradient = {
  colors = { "rgba(ff0055ff)", "rgba(ff1744ff)", "rgba(ff003cff)", "rgba(ff5287ff)" },
  angle = 45,
}
local urgentInactiveGradient = {
  colors = { "rgba(ff0055bb)", "rgba(ff174499)" },
  angle = 45,
}

o.window({ tag = "error-window" }, {
  border_color = urgentBorderGradient,
  border_size = 4,
})
