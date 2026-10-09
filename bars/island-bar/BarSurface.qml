import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

// V2-style bar surface: a continuous strip, or one notch tab.
//
// A single shadow belongs to the whole shape. It is drawn by MultiEffect over
// the rendered path rather than by RectangularShadow: a rectangular shadow
// cannot follow a notch whose desktop edge tapers inward at both ends, so its
// square corners pushed out past the curve and the whole thing read as a block
// sitting behind the bar.
//
// Adapted from Shibumi-Shell's V2 shell. Forms:
//
//   "notch"  the desktop-facing edge is inset at each end and curves up into
//            the screen edge, so the bar grows out of the top of the screen.
//   "dock"   screen edge straight, desktop-facing corners rounded by space(8).
//   "full"   screen edge straight, desktop corners square. Edge to edge.
//   "fit"    inset from the screen edge and the sides, all four corners
//            rounded: a floating frame rather than an attached strip.
//
// Shibumi's connected tongue - a lobe that flows down into an open panel - is
// left out; that needs the panel-open geometry plumbed through.
Item {
  id: root

  property bool atTop: true
  property string variant: "notch"
  property color fillColor: Color.bar.background
  // A faint accent-tinted edge rather than plain foreground: it ties the
  // surface to the theme colour the way the widgets are tied to it.
  property color borderColor: Qt.rgba(Color.accent.r, Color.accent.g,
    Color.accent.b, 0.35)
  property bool borderEnabled: true
  // Thin lit line along the screen edge - the glass cue.
  property bool highlightEnabled: true
  property color highlightColor: Qt.rgba(1, 1, 1, 0.10)
  property bool shadowEnabled: true
  // Depth of the cast shadow. Kept modest because a bar window is only as tall
  // as the bar, so anything past the desktop edge has nowhere to render.
  property real shadowBlur: 0.5
  property real shadowOffset: 3

  // Notch geometry, from the Shibumi V2 contract: the shoulder runs out to
  // `wing`, the body corner adds `bodyRadius`, and the cubic's control points
  // use the circular-arc kappa so the curve reads as a quarter round.
  // Overridable: a narrow island needs a smaller shoulder.
  property real wing: Style.space(14)
  property real bodyRadius: Style.space(9)
  readonly property real inset: wing + bodyRadius
  readonly property real kappa: 0.55228475

  readonly property bool notch: variant === "notch"

  // Per-form geometry. "fit" floats: inset from the screen edge and both sides,
  // every corner rounded. The attached forms sit flush at the screen edge and
  // only round the desktop-facing pair.
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

  // The whole shape is rendered as one layer so MultiEffect can cast a shadow
  // that follows the path, curve and all.
  Item {
    id: surfaceContent

    anchors.fill: parent
    layer.enabled: root.shadowEnabled
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.55)
      shadowBlur: root.shadowBlur
      shadowVerticalOffset: root.atTop ? root.shadowOffset : -root.shadowOffset
      shadowHorizontalOffset: 0
      shadowScale: 1.0
      // Lets the blur bleed past the item; harmless where the bar fills the
      // window, needed in the gaps between islands.
      autoPaddingEnabled: true
    }

    // A lit line along the screen edge. Reads as light catching the top of the
    // surface, which is what makes the strip look like glass rather than paint.
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      y: root.atTop ? 0 : parent.height - height
      height: 1
      color: root.highlightColor
      visible: root.highlightEnabled
    }

    Shape {
      id: notchShape

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

    // dock / full / fit: a rounded rectangle, optionally inset.
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
  }
}
