#!/bin/bash
# ==============================================================================
#  PER-WINDOW ERROR BORDER (NEON RED + NO SHADOW/GLOW)
# ==============================================================================

# Extract active window address robustly (works with jq, grep, or awk)
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

# Apply Neon Red border & suppress shadow for clear warning visibility
hyprctl eval "
  local d1 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'active_border_color', value = 'rgba(ff0055ff) rgba(ff1744ff) rgba(ff003cff) 45deg' })
  local d2 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'inactive_border_color', value = 'rgba(ff0055bb) rgba(ff174499) 45deg' })
  local d3 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'no_shadow', value = 'true' })
  hl.dispatch(d1)
  hl.dispatch(d2)
  hl.dispatch(d3)
" &>/dev/null 2>&1
