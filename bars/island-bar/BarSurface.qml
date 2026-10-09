import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

// V2-style bar surface: one continuous strip attached to the screen edge.
//
// Replaces the three floating pills. The bar now spans the full width and only
// its desktop-facing corners are rounded, so it reads as part of the screen
// edge rather than three objects sitting on the wallpaper. A single shadow
// belongs to the whole strip, not to each group - fragmenting it per group is
// what made the old design read as separate pills.
//
// Adapted from Shibumi-Shell's V2 shell geometry. Its "notch" variant adds
// flowing shoulders and a tongue that connects to an open panel; both are
// deliberately left out here. This is the "full" idea: edge to edge, quiet.
Item {
  id: root

  // Which screen edge the bar hugs. Drives which corners round and which way
  // the shadow falls.
  property bool atTop: true
  property real cornerRadius: Style.space(2)
  property color fillColor: Color.bar.background
  property color borderColor: Qt.rgba(Color.foreground.r, Color.foreground.g,
    Color.foreground.b, 0.10)
  property bool borderEnabled: true
  property bool shadowEnabled: true

  readonly property real r: Math.max(0, Math.min(cornerRadius, height / 2))

  Shape {
    id: surface

    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    // Top bar: the screen-edge corners stay square, the desktop-facing pair
    // rounds. A bottom bar is the same path mirrored.
    ShapePath {
      strokeColor: root.borderEnabled ? root.borderColor : "transparent"
      strokeWidth: root.borderEnabled ? 1 : 0
      fillColor: root.fillColor
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.RoundJoin

      startX: 0
      startY: root.atTop ? 0 : root.height

      PathLine { x: root.width; y: root.atTop ? 0 : root.height }

      PathLine {
        x: root.width
        y: root.atTop ? root.height - root.r : root.r
      }

      PathQuad {
        x: root.width - root.r
        y: root.atTop ? root.height : 0
        controlX: root.width
        controlY: root.atTop ? root.height : 0
      }

      PathLine {
        x: root.r
        y: root.atTop ? root.height : 0
      }

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
    radius: root.r
    blur: 10
    spread: 0
    offset: Qt.vector2d(0, root.atTop ? 3 : -3)
    color: Qt.rgba(0, 0, 0, 0.40)
    visible: root.shadowEnabled
    z: -1
  }
}
