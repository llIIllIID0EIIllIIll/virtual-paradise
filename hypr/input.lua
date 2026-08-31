-- ==============================================================================
--  Virtual☆Paradise — Full-Topping Input & Gestures Configuration
-- ==============================================================================
--  Documentation: https://wiki.hypr.land/Configuring/Basics/Variables/#input
--                 https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- ==============================================================================

hl.config({
  input = {
    -- 1. KEYBOARD TUNING (Fast & Responsive Coding / Vim experience)
    ----------------------------------------------------------------------------
    repeat_rate = 50,           -- Repeat speed (50 chars/sec, fast & snappy)
    repeat_delay = 240,         -- Delay before key repeat starts (ms)
    numlock_by_default = true,  -- Automatically enable NumLock at startup
    resolve_binds_by_sym = 1,   -- Resolve bindings by symbol (no Vietnamese IME conflicts)

    -- 2. MOUSE FOCUS & SENSITIVITY
    ----------------------------------------------------------------------------
    follow_mouse = 1,                 -- Focus follows cursor movement
    mouse_refocus = true,             -- Re-focus window under mouse
    float_switch_override_focus = 2,  -- Smooth focus switching between floating & tiled
    sensitivity = 0.0,                -- Standard 1:1 mouse sensitivity
    accel_profile = "adaptive",       -- Natural pointer acceleration
    scroll_factor = 1.05,             -- Smooth, responsive mouse wheel scrolling

    -- 3. TOUCHPAD FULL TOPPING (macOS-level Precision)
    ----------------------------------------------------------------------------
    touchpad = {
      natural_scroll = true,          -- Natural inverted scrolling (macOS style)
      scroll_factor = 1.05,           -- Responsive 2-finger scroll multiplier
      clickfinger_behavior = true,    -- 1-finger = Left click, 2-finger = Right click, 3-finger = Middle click
      tap_to_click = true,            -- Tap to click
      tap_and_drag = true,            -- Tap twice and hold to drag (smooth text selection & window moving)
      drag_lock = false,              -- Release drag immediately upon lifting finger
      disable_while_typing = true,    -- Prevent palm/hand accidental touchpad touches while typing
      middle_button_emulation = true, -- Emulate middle-click with 3 fingers / dual press
    },
  },

  -- 4. SMART CURSOR BEHAVIOR
  ------------------------------------------------------------------------------
  cursor = {
    hide_on_key_press = true,         -- Auto-hide cursor when typing
    inactive_timeout = 5,             -- Auto-hide cursor after 5s of inactivity (clean screen)
    warp_on_change_workspace = 1,     -- Warp cursor to active window when switching workspaces
    enable_hyprcursor = true,         -- Use high-performance Hyprcursor engine
  },
})

-- 5. APP-SPECIFIC SCROLL TUNING
--------------------------------------------------------------------------------
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.0 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 1.0 })

-- 6. NATIVE TOUCHPAD GESTURES (100% Stable)
--------------------------------------------------------------------------------
-- 3-FINGER SWIPE: Switch between workspaces fluidly (macOS-like)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 2-FINGER PINCH: Smooth cursor zoom (1.25x / 1.0x)
hl.gesture({ fingers = 2, direction = "pinchin", action = "cursor_zoom", zoom_level = 1.25, mode = "mult" })
hl.gesture({ fingers = 2, direction = "pinchout", action = "cursor_zoom", zoom_level = 1.0, mode = "live" })