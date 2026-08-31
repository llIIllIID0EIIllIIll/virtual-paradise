#!/bin/bash
# ==============================================================================
#  PER-WINDOW ERROR BORDER (NEON RED + NO SHADOW/GLOW, NO SHAKE)
# ==============================================================================

addr=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
if [[ -n "$addr" ]]; then
  hyprctl eval "
    local d1 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'active_border_color', value = 'rgba(ff0055ff) rgba(ff1744ff) rgba(ff003cff) 45deg' })
    local d2 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'inactive_border_color', value = 'rgba(ff0055bb) rgba(ff174499) 45deg' })
    local d3 = hl.dsp.window.set_prop({ window = 'address:$addr', prop = 'no_shadow', value = 'true' })
    hl.dispatch(d1)
    hl.dispatch(d2)
    hl.dispatch(d3)
  " &>/dev/null
fi
