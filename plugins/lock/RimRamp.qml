import QtQuick
import qs.Commons

// The window-border gradient as a reusable ramp.
//
// Same idea as the island bar's RimRamp: the lock screen's input border and
// bloom read the [hyprland] active-border token so the lock chrome travels
// through the same colours as the windows and the bar.
QtObject {
  id: root

  property real alphaScale: 1.0
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
