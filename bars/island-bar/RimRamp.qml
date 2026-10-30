import QtQuick
import qs.Commons

// The window-border gradient as a reusable ramp.
//
// Hyprland paints window borders from the [hyprland] active-border token; the
// bar rim, the centre bloom and the hover halos all ride the same ramp, so
// every piece of chrome travels through the same colours - including theme
// variants that rewrite that token. A theme without the token falls back to
// the accent/muted pair.
QtObject {
  id: root

  // 0..1 multiplier on every stop's alpha. The centre island and a hovered
  // widget run brighter than the side islands.
  property real alphaScale: 0.85
  // Current spin angle in degrees.
  property real angle: 0

  readonly property var gradient: {
    var spec = Border.surfaceSpec("hyprland", "active-border", Color.accent, 1)
    return (spec && spec.gradient && spec.gradient.enabled) ? spec.gradient : null
  }

  readonly property var colors: {
    var grad = root.gradient
    if (!grad || !grad.colors || grad.colors.length === 0)
      return [Color.accent, Color.muted]
    var out = []
    for (var i = 0; i < grad.colors.length; i++) {
      var c = grad.colors[i]
      out.push(Qt.rgba(c.r, c.g, c.b, (c.a === undefined ? 1 : c.a) * root.alphaScale))
    }
    return out
  }

  // The colour the ramp shows at the current angle, for glows and fills that
  // cannot carry a gradient themselves.
  readonly property color colorAt: {
    var list = root.colors
    var n = list.length
    if (n === 0) return Color.accent
    var pos = (root.angle % 360) / 360 * n
    var i = Math.floor(pos) % n
    var f = pos - Math.floor(pos)
    var a = list[i]
    var b = list[(i + 1) % n]
    return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f,
      a.b + (b.b - a.b) * f, 1)
  }
}
