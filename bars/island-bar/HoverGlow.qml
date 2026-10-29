import QtQuick
import QtQuick.Effects
import qs.Commons

// Soft accent halo behind the bar widget under the pointer.
//
// Separate from GapGlow: the gap effect travels between islands, while this one
// marks the widget the pointer is on. Both are gated by the bar's effects switch
// so a user who wants a completely still bar can turn them off together, and
// hoverGlow can disable this one on its own.
Item {
  id: root

  property bool active: false
  // Color is a singleton and normally always has an accent, but a partially
  // loaded host theme can leave it undefined. Keep the halo visible instead of
  // binding an invalid QColor.
  property color accent: Color.accent !== undefined ? Color.accent : "#ff2bd6"
  property real radius: 0
  // 0..1 lets a caller dim the halo for a dense layout without changing the
  // shared toggle.
  property real intensity: 1.0

  opacity: active ? intensity : 0
  visible: active || opacity > 0

  Behavior on opacity {
    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
  }

  // A coloured shadow at zero offset, the same treatment BarSurface uses for
  // its centre-island glow. RectangularShadow follows the rounded rectangle;
  // a blurred Rectangle copy would square off the corners.
  RectangularShadow {
    anchors.fill: parent
    radius: root.radius
    blur: 18
    spread: 0
    offset: Qt.vector2d(0, 0)
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
  }

  // The shadow supplies the bloom. A faint wash and a crisp rim keep the
  // widget's outline legible against a bright wallpaper without turning the
  // halo into a hard box around every icon.
  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.04)
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.38)
  }
}
