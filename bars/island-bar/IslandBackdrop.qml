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
  // A soft bloom behind the island, in the ramp colour at the current angle.
  // The centre runs stronger so it stays the focal surface; the sides get a
  // faint aura so the whole bar glows instead of only the middle. Zero means
  // no bloom at all.
  property real glowStrength: 0
  // Ease width changes so a section that grows (revealed indicators, a new
  // tray item) glides instead of snapping its backdrop.
  property bool animateWidth: false
  // Degrees. The bar spins this once per rim period so the rim gradient
  // travels around the island like the window borders do.
  property real rimAngle: 0

  readonly property bool filled: fillOpacity > 0
  readonly property color base: Color.bar.background

  RimRamp {
    id: ramp

    alphaScale: root.edge === "center" ? 0.9 : 0.75
    angle: root.rimAngle
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

  // Accent bloom for the island. Sits behind the neutral shadow so the dark
  // edge stays crisp and the colour only spills outward.
  RectangularShadow {
    anchors.fill: parent
    radius: root.radius
    blur: 18
    spread: 1
    offset: Qt.vector2d(0, 0)
    color: Qt.rgba(ramp.colorAt.r, ramp.colorAt.g, ramp.colorAt.b,
      root.glowStrength)
    visible: root.glowStrength > 0 && root.shadowEnabled && root.filled
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

  // Inner hairline: a dim frame two pixels inside the rim. It reads as a
  // machined bezel and gives the bar a second line the hover chrome does not
  // have, so the two effects never blur together.
  Rectangle {
    anchors.fill: parent
    anchors.margins: 2
    radius: Math.max(0, root.radius - 2)
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g,
      Color.foreground.b, 0.07)
    visible: root.filled
  }

  // Accent rim. The colours come from the shared window-gradient ramp and the
  // angle is animated by the bar so the bands travel around the island.
  BorderOverlay {
    radius: root.radius
    borderSpec: ({
      color: Color.accent,
      widths: { top: 1, right: 1, bottom: 1, left: 1 },
      gradient: {
        enabled: true,
        angle: root.rimAngle,
        colors: ramp.colors
      }
    })
  }
}
