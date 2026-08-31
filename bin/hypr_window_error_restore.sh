#!/bin/bash
# ==============================================================================
#  GRADUAL CYBERPUNK COLOR FADE: RED -> MAGENTA -> PURPLE -> BLUE -> MIKU CYAN
# ==============================================================================

addr=""
if command -v hyprctl >/dev/null 2>&1; then
  if command -v jq >/dev/null 2>&1; then
    addr=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
  fi
  if [[ -z "$addr" ]]; then
    addr=$(hyprctl activewindow 2>/dev/null | awk '/Window / { print $2 }' | tr -d ':')
  fi
fi

[[ -z "$addr" ]] && exit 0

# Step 1: Red -> Magenta Fade
hyprctl eval "
  local d1 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'active_border_color', value = 'rgba(ff0077ee) rgba(ec4899ee) 45deg' })
  local d2 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'inactive_border_color', value = 'rgba(ff0077aa) rgba(ec4899aa) 45deg' })
  hl.dispatch(d1)
  hl.dispatch(d2)
" &>/dev/null 2>&1
sleep 0.055

# Step 2: Magenta -> Cyber Purple Fade
hyprctl eval "
  local d1 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'active_border_color', value = 'rgba(d946efee) rgba(8b5cf6ee) 45deg' })
  local d2 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'inactive_border_color', value = 'rgba(d946efaa) rgba(8b5cf6aa) 45deg' })
  hl.dispatch(d1)
  hl.dispatch(d2)
" &>/dev/null 2>&1
sleep 0.055

# Step 3: Purple -> Neon Azure Blue Fade
hyprctl eval "
  local d1 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'active_border_color', value = 'rgba(6366f1ee) rgba(06b6d4ee) 45deg' })
  local d2 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'inactive_border_color', value = 'rgba(6366f1aa) rgba(06b6d4aa) 45deg' })
  hl.dispatch(d1)
  hl.dispatch(d2)
" &>/dev/null 2>&1
sleep 0.055

# Step 4: Full Miku Cyan / Hacker Green / Sakura Pink Theme Gradient & Restore Shadow
hyprctl eval "
  local d1 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'active_border_color', value = 'rgba(00f5d4ee) rgba(00ff88dd) rgba(ffb7d5ee) 45deg' })
  local d2 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'inactive_border_color', value = 'rgba(182833aa)' })
  local d3 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'no_shadow', value = 'false' })
  hl.dispatch(d1)
  hl.dispatch(d2)
  hl.dispatch(d3)
" &>/dev/null 2>&1
