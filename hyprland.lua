-- Virtual☆Paradise Theme — Hyprland Configuration
-- Neon Pastel Cyberpunk: Miku Cyan -> Hacker Green -> Sakura Pink

local activeBorderColor = {
  colors = { "rgba(00f5d4ee)", "rgba(00ff88dd)", "rgba(ffb7d5ee)" },
  angle = 45,
}
local inactiveBorderColor = "rgba(182833aa)"
local activeShadowColor = "rgba(00f5d428)"
local inactiveShadowColor = "rgba(00000080)"

hl.config({
  general = {
    col = {
      active_border = activeBorderColor,
      inactive_border = inactiveBorderColor,
    },
    border_size = 2,
    gaps_in = 6,
    gaps_out = 12,
  },
  group = {
    col = {
      border_active = activeBorderColor,
      border_inactive = inactiveBorderColor,
    },
  },
  decoration = {
    active_opacity = 0.95,
    inactive_opacity = 0.85,
    rounding = 12,
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      ignore_opacity = true,
      new_optimizations = true,
      xray = false,
      noise = 0.02,
      contrast = 0.95,
      vibrancy = 0.35,
      vibrancy_darkness = 0.5,
      brightness = 0.85,
      popups_ignorealpha = 0.5,
      input_methods_ignorealpha = 0.5,
    },
    shadow = {
      enabled = true,
      range = 20,
      render_power = 3,
      color = activeShadowColor,
      color_inactive = inactiveShadowColor,
      offset = "0 2",
    },
  },
  animations = {
    enabled = true,
  },
})

-- Cyberpunk snappiness with soft spring curves
hl.curve("cyberOvershoot", { type = "bezier", points = { { 0.18, 0.9 }, { 0.25, 1.12 } } })
hl.curve("sakuraGlide", { type = "bezier", points = { { 0.25, 1.0 }, { 0.35, 1.0 } } })
hl.curve("quickFade", { type = "bezier", points = { { 0.15, 0.0 }, { 0.1, 1.0 } } })
hl.curve("workspaceSpring", { type = "bezier", points = { { 0.2, 0.95 }, { 0.3, 1.04 } } })

hl.animation({
  leaf = "windows",
  enabled = true,
  speed = 4.5,
  bezier = "cyberOvershoot",
})
hl.animation({
  leaf = "windowsIn",
  enabled = true,
  speed = 4.2,
  bezier = "cyberOvershoot",
  style = "popin 80%",
})
hl.animation({
  leaf = "windowsOut",
  enabled = true,
  speed = 3.5,
  bezier = "quickFade",
  style = "popin 80%",
})
hl.animation({
  leaf = "windowsMove",
  enabled = true,
  speed = 4.5,
  bezier = "sakuraGlide",
})
hl.animation({
  leaf = "border",
  enabled = true,
  speed = 5,
  bezier = "quickFade",
})
hl.animation({
  leaf = "fade",
  enabled = true,
  speed = 4,
  bezier = "quickFade",
})
hl.animation({
  leaf = "layers",
  enabled = true,
  speed = 4.5,
  bezier = "sakuraGlide",
  style = "slidefade",
})
hl.animation({
  leaf = "layersIn",
  enabled = true,
  speed = 4.5,
  bezier = "cyberOvershoot",
  style = "slidefade",
})
hl.animation({
  leaf = "layersOut",
  enabled = true,
  speed = 3.5,
  bezier = "quickFade",
  style = "fade",
})
hl.animation({
  leaf = "workspaces",
  enabled = true,
  speed = 5.5,
  bezier = "workspaceSpring",
  style = "slide",
})