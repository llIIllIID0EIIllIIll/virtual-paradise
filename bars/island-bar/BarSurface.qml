import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

// V2-style bar surface: one continuous strip attached to the screen edge.
//
// Replaces the three floating pills. The bar spans the width and reads as part
// of the screen edge rather than three objects on the wallpaper. A single
// shadow belongs to the whole strip, not to each group - fragmenting it per
// group is what made the old design fall apart into pills.
//
// Adapted from Shibumi-Shell's V2 shell. Forms offered here:
//
//   "notch"  the desktop-facing edge is inset at each end and curves up into
//            the screen edge, so the bar grows out of the top of the screen.
//   "dock"   screen edge straight, desktop-facing corners rounded by
//            space(8). The quiet strip.
//   "full"   screen edge straight, desktop corners square. Edge to edge.
//   "fit"    inset from the screen edge and the sides, all four corners
//            rounded: a floating frame rather than an attached strip.
//
// Shibumi's connected tongue - a lobe that flows down into an open panel - is
// left out; that needs the panel-open geometry plumbed through, and this bar's
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

  readonly property bool notch: variant === "notch"

  // Per-form geometry. "fit" floats: it is inset from the screen edge and both
  // sides and rounds every corner. The attached forms sit flush at the screen
  // edge and only round the desktop-facing pair.
  readonly property real fitInset: Style.space(3)
  readonly property real insetH: variant === "fit" ? fitInset : 0
  readonly property real screenInset: variant === "fit" ? fitInset : 0
  readonly property real deskInset: variant === "fit" ? fitInset : 0
  readonly property real screenCorner: variant === "fit" ? Style.space(6) : 0
  readonly property real desktopCorner: variant === "dock"
    ? Style.space(8)
    : variant === "fit" ? Style.space(6) : 0

  // Corners as they fall on screen, resolved for bar position.
  readonly property real tl: root.atTop ? screenCorner : desktopCorner
  readonly property real tr: root.tl
  readonly property real bl: root.atTop ? desktopCorner : screenCorner
  readonly property real br: root.bl

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

  // dock / full / fit: a rounded rectangle, optionally inset. The two edges are
  // the screen edge (y = screenY) and the desktop edge (y = deskY).
  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    visible: !root.notch

    readonly property real x0: root.insetH
    readonly property real x1: root.width - root.insetH
    readonly property real screenY: root.atTop ? root.screenInset
      : root.height - root.screenInset
    readonly property real deskY: root.atTop
      ? root.height - root.deskInset : root.deskInset
    // Radii touching the screen edge and the desktop edge respectively.
    readonly property real sr: root.atTop ? root.screenCorner : root.desktopCorner
    readonly property real dr: root.atTop ? root.desktopCorner : root.screenCorner

    ShapePath {
      strokeColor: root.borderEnabled ? root.borderColor : "transparent"
      strokeWidth: root.borderEnabled ? 1 : 0
      fillColor: root.fillColor
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.RoundJoin

      startX: parent.x0 + parent.sr
      startY: parent.screenY
      PathLine { x: parent.x1 - parent.sr; y: parent.screenY }
      PathQuad {
        x: parent.x1
        y: parent.screenY + (root.atTop ? parent.sr : -parent.sr)
        controlX: parent.x1
        controlY: parent.screenY
      }
      PathLine { x: parent.x1; y: parent.deskY + (root.atTop ? -parent.dr : parent.dr) }
      PathQuad {
        x: parent.x1 - parent.dr
        y: parent.deskY
        controlX: parent.x1
        controlY: parent.deskY
      }
      PathLine { x: parent.x0 + parent.dr; y: parent.deskY }
      PathQuad {
        x: parent.x0
        y: parent.deskY + (root.atTop ? -parent.dr : parent.dr)
        controlX: parent.x0
        controlY: parent.deskY
      }
      PathLine { x: parent.x0; y: parent.screenY + (root.atTop ? parent.sr : -parent.sr) }
      PathQuad {
        x: parent.x0 + parent.sr
        y: parent.screenY
        controlX: parent.x0
        controlY: parent.screenY
      }
    }
  }

  // One shadow for the whole strip, cast away from the screen edge.
  RectangularShadow {
    anchors.fill: parent
    radius: root.notch ? root.bodyRadius : Math.max(root.tl, root.bl)
    blur: 10
    spread: 0
    offset: Qt.vector2d(0, root.atTop ? 3 : -3)
    color: Qt.rgba(0, 0, 0, 0.40)
    visible: root.shadowEnabled
    z: -1
  }
}
