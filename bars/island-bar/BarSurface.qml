import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

// V2-style bar surface: one continuous strip attached to the screen edge.
//
// Replaces the three floating pills. The bar spans the full width and reads as
// part of the screen edge rather than three objects on the wallpaper. A single
// shadow belongs to the whole strip, not to each group - fragmenting it per
// group is what made the old design fall apart into pills.
//
// Adapted from Shibumi-Shell's V2 shell. Two of its forms are offered:
//
//   "notch"  the desktop-facing edge is inset at each end and curves up into
//            the screen edge, so the bar grows out of the top of the screen.
//            This is the default.
//   "full"   edge to edge with a plain rounded desktop edge.
//
// Shibumi's "fit" and "dock" are content-width forms and are not offered,
// because this bar keeps three fixed groups across the full width.
//
// Its connected tongue - a lobe that flows down into an open panel - is left
// out. That needs the panel-open geometry plumbed through, and this bar's
// panels anchor themselves.
Item {
  id: root

  property bool atTop: true
  property string variant: "notch"
  property color fillColor: Color.bar.background
  property color borderColor: Qt.rgba(Color.foreground.r, Color.foreground.g,
    Color.foreground.b, 0.10)
  property bool borderEnabled: true
  property bool shadowEnabled: true

  // Notch geometry, from the Shibumi V2 contract: the shoulder runs out to
  // `wing`, the body corner adds `bodyRadius`, and the cubic's control points
  // use the circular-arc kappa so the curve reads as a quarter round.
  readonly property real wing: Style.space(14)
  readonly property real bodyRadius: Style.space(9)
  readonly property real inset: wing + bodyRadius
  readonly property real kappa: 0.55228475

  // Fallback radius for the "full" form.
  readonly property real cornerRadius: Style.space(2)
  readonly property real r: Math.max(0, Math.min(cornerRadius, height / 2))

  readonly property bool notch: variant === "notch"

  Shape {
    id: surface

    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    visible: root.notch

    ShapePath {
      strokeColor: root.borderEnabled ? root.borderColor : "transparent"
      strokeWidth: root.borderEnabled ? 1 : 0
      fillColor: root.fillColor
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.RoundJoin

      startX: 0.5
      startY: root.atTop ? 0 : root.height

      // Straight along the screen edge.
      PathLine { x: root.width; y: root.atTop ? 0 : root.height }

      // Right shoulder: the desktop edge curves up into the screen edge.
      PathCubic {
        x: root.width - root.inset
        y: root.atTop ? root.height : 0
        control1X: root.width - root.kappa * root.wing
        control1Y: root.atTop ? 0 : root.height
        control2X: root.width - root.wing + (1 - root.kappa) * root.bodyRadius
        control2Y: root.atTop ? root.height : 0
      }

      // Straight desktop edge between the shoulders.
      PathLine { x: root.inset; y: root.atTop ? root.height : 0 }

      // Left shoulder.
      PathCubic {
        x: 0
        y: root.atTop ? 0 : root.height
        control1X: root.wing - (1 - root.kappa) * root.bodyRadius
        control1Y: root.atTop ? root.height : 0
        control2X: root.kappa * root.wing
        control2Y: root.atTop ? 0 : root.height
      }
    }
  }

  // "full": edge to edge with the desktop-facing corners rounded.
  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    visible: !root.notch

    ShapePath {
      strokeColor: root.borderEnabled ? root.borderColor : "transparent"
      strokeWidth: root.borderEnabled ? 1 : 0
      fillColor: root.fillColor
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.RoundJoin

      startX: 0
      startY: root.atTop ? 0 : root.height

      PathLine { x: root.width; y: root.atTop ? 0 : root.height }
      PathLine { x: root.width; y: root.atTop ? root.height - root.r : root.r }
      PathQuad {
        x: root.width - root.r
        y: root.atTop ? root.height : 0
        controlX: root.width
        controlY: root.atTop ? root.height : 0
      }
      PathLine { x: root.r; y: root.atTop ? root.height : 0 }
      PathQuad {
        x: 0
        y: root.atTop ? root.height - root.r : root.r
        controlX: 0
        controlY: root.atTop ? root.height : 0
      }
      PathLine { x: 0; y: root.atTop ? 0 : root.height }
    }
  }

  // One shadow for the whole strip, cast away from the screen edge.
  RectangularShadow {
    anchors.fill: parent
    radius: root.notch ? root.bodyRadius : root.r
    blur: 10
    spread: 0
    offset: Qt.vector2d(0, root.atTop ? 3 : -3)
    color: Qt.rgba(0, 0, 0, 0.40)
    visible: root.shadowEnabled
    z: -1
  }
}
