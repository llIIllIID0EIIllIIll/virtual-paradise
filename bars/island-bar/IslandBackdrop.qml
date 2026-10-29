import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// Floating island surface drawn behind one bar section.
//
// Everything here is derived from Color tokens, so the islands re-tint with
// the active theme. The island only becomes its own opaque surface when the
// bar asks for it; a transparent bar keeps the rim and drops the fill so the
// desktop shows through.
Item {
  id: root

  // Which edge of the bar this island hugs. The centre rides the full-strength
  // rim; the sides sit a little dimmer so the centre stays the focus.
  property string edge: "center"
  property real radius: 0
  property real fillOpacity: 1
  // Shadow direction follows the bar: an island on the bottom edge casts up.
  property bool barAtTop: true
  property bool shadowEnabled: true
  // A faint accent bloom behind one island. The centre uses it to read as the
  // focal surface; the sides keep only the neutral shadow so the bar does not
  // turn into three competing glows.
  property bool accentGlow: false
  // Ease width changes so a section that grows (revealed indicators, a new
  // tray item) glides instead of snapping its backdrop.
  property bool animateWidth: false
  // Degrees. The bar spins this once per rim period so the rim gradient
  // travels around the island like the window borders do.
  property real rimAngle: 0

  readonly property bool filled: fillOpacity > 0
  readonly property color base: Color.bar.background

  // The rim rides the same gradient token the compositor paints on window
  // borders, so the bar and the windows always travel through the same
  // colours, including theme variants that rewrite that token. A theme
  // without the token falls back to the accent/muted pair.
  readonly property var windowGradient: {
    var spec = Border.surfaceSpec("hyprland", "active-border", Color.accent, 1)
    return (spec && spec.gradient && spec.gradient.enabled) ? spec.gradient : null
  }

  readonly property var rimColors: {
    var grad = root.windowGradient
    if (!grad || !grad.colors || grad.colors.length === 0)
      return [Color.accent, Color.muted]
    var scale = root.edge === "center" ? 0.9 : 0.75
    var out = []
    for (var i = 0; i < grad.colors.length; i++) {
      var c = grad.colors[i]
      out.push(Qt.rgba(c.r, c.g, c.b, (c.a === undefined ? 1 : c.a) * scale))
    }
    return out
  }

  // The colour the centre bloom shows at this point in the spin, sampled from
  // the same ramp as the rim so the two never disagree.
  readonly property color glowColor: {
    var colors = root.rimColors
    var n = colors.length
    if (n === 0) return Color.accent
    var pos = (root.rimAngle % 360) / 360 * n
    var i = Math.floor(pos) % n
    var f = pos - Math.floor(pos)
    var a = colors[i]
    var b = colors[(i + 1) % n]
    return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f,
      a.b + (b.b - a.b) * f, 1)
  }

  Behavior on width {
    enabled: root.animateWidth
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  // Glass fill: a touch lighter at the top edge, settling into the theme
  // background. The gradient spans only a few percent of the value range -
  // enough to catch light without turning the pill into a two-tone block.
  Rectangle {
    id: surface

    anchors.fill: parent
    radius: root.radius
    color: "transparent"
    opacity: root.fillOpacity
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.lighter(root.base, 1.20) }
      GradientStop { position: 0.52; color: root.base }
      GradientStop { position: 1.0; color: Qt.darker(root.base, 1.10) }
    }
  }

  // Accent bloom for the focal island. Sits behind the neutral shadow so the
  // dark edge stays crisp and the colour only spills outward.
  RectangularShadow {
    anchors.fill: parent
    radius: root.radius
    blur: 18
    spread: 1
    offset: Qt.vector2d(0, 0)
    color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.16)
    visible: root.accentGlow && root.shadowEnabled && root.filled
    z: -2
  }

  // Soft drop shadow so the islands read as floating above the wallpaper
  // rather than painted onto it. RectangularShadow tracks a rounded rect,
  // which a plain Rectangle or a blurred copy cannot do cleanly. Sits behind
  // every other child via z, and is skipped on a rim-only island.
  RectangularShadow {
    anchors.fill: parent
    radius: root.radius
    blur: 11
    spread: 0
    offset: Qt.vector2d(0, root.barAtTop ? 2 : -2)
    color: Qt.rgba(0, 0, 0, 0.38)
    visible: root.shadowEnabled && root.fillOpacity > 0
    z: -1
  }

  // A one-stop sheen along the leading edge. Cheap depth cue: it reads as a
  // light source catching the top of the island without a blur pass.
  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: Math.max(0, root.radius - 1)
    color: "transparent"
    opacity: 0.6
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop {
        position: 0.0
        color: Qt.alpha(Color.foreground, 0.08)
      }
      GradientStop {
        position: 0.42
        color: "transparent"
      }
    }
  }

  // Accent rim. The colours come from the same window-gradient token the
  // compositor paints on window borders, and the angle is animated by the bar
  // so the bands travel around the island. A theme without that token falls
  // back to the accent/muted pair, which still rotates.
  BorderOverlay {
    radius: root.radius
    borderSpec: ({
      color: Color.accent,
      widths: { top: 1, right: 1, bottom: 1, left: 1 },
      gradient: {
        enabled: true,
        angle: root.rimAngle,
        colors: root.rimColors
      }
    })
  }
}
