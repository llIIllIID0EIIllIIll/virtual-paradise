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

  // Which edge of the bar this island hugs. Drives the rim gradient so the
  // brightest accent always sits on the outer edge of the island.
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

  readonly property bool filled: fillOpacity > 0
  readonly property color base: Color.bar.background

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
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
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

  // Accent rim. Colour pairs come from the theme rather than literals so a
  // palette swap carries over to the bar chrome. The centre is a little
  // brighter than the sides, matching its role as the focus.
  BorderOverlay {
    radius: root.radius
    borderSpec: ({
      color: Color.accent,
      widths: { top: 1, right: 1, bottom: 1, left: 1 },
      gradient: {
        enabled: true,
        angle: root.parent && root.parent.vertical === true ? 90 : 0,
        colors: root.edge === "left"
          ? [Qt.alpha(Color.accent, 0.68), Qt.alpha(Color.muted, 0.24)]
          : root.edge === "right"
            ? [Qt.alpha(Color.muted, 0.24), Qt.alpha(Color.accent, 0.68)]
            : [Qt.alpha(Color.accent, 0.58), Qt.alpha(Color.muted, 0.28),
               Qt.alpha(Color.accent, 0.58)]
      }
    })
  }
}
