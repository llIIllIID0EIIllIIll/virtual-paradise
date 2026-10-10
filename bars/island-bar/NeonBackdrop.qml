import QtQuick
import QtQuick.Effects
import qs.Commons

// A neon backplate for the centre pill.
//
// The centre pill floats on top of this; the plate is a little larger on every
// side so the pattern frames the pill instead of hiding under it. The pattern
// is a hex grid drifting slowly to the right - the cheapest way to read as a
// HUD surface without a texture file, and it costs one Canvas paint every
// other frame rather than an image decode.
Item {
  id: root

  property color accent: Color.accent
  property color base: Color.bar.background
  property real radius: 14
  property real cell: Style.space(7)
  property bool animated: true
  property real patternOpacity: 0.20

  // Horizontal drift, in pixels per second.
  readonly property real driftPerSecond: 6

  property real phase: 0

  Rectangle {
    id: plate

    anchors.fill: parent
    radius: root.radius
    color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.92)
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
  }

  // Soft accent wash so the plate reads as lit rather than painted.
  Rectangle {
    anchors.fill: parent
    radius: root.radius
    opacity: 0.5
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop {
        position: 0.5
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10)
      }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  Timer {
    interval: 50
    repeat: true
    running: root.animated && root.visible
    onTriggered: {
      root.phase = (root.phase + root.driftPerSecond * 0.05) % root.cell
      canvas.requestPaint()
    }
  }

  Canvas {
    id: canvas

    anchors.fill: parent
    renderStrategy: Canvas.Threaded
    opacity: root.patternOpacity

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (width <= 0 || height <= 0) return

      var a = root.accent
      var stroke = "rgba(" + Math.round(a.r * 255) + "," + Math.round(a.g * 255)
        + "," + Math.round(a.b * 255) + ",1)"
      ctx.strokeStyle = stroke
      ctx.lineWidth = 1
      ctx.lineJoin = "round"

      // Pointy-top hexagons. Cols are spaced by the hex width, rows by 3/4 of
      // the hex height, and every other column is offset by half a row so the
      // cells interlock.
      var s = Math.max(4, root.cell)
      var hexW = Math.sqrt(3) * s
      var hexH = 2 * s
      var rowStep = 1.5 * s
      var cols = Math.ceil(width / hexW) + 2
      var rows = Math.ceil(height / rowStep) + 1
      var offset = root.phase

      ctx.beginPath()
      for (var col = -1; col < cols; col++) {
        for (var row = -1; row < rows; row++) {
          var cx = col * hexW + (row % 2 ? hexW / 2 : 0) + offset
          var cy = row * rowStep + s
          for (var i = 0; i < 6; i++) {
            var angle = Math.PI / 180 * (60 * i - 30)
            var px = cx + s * Math.cos(angle)
            var py = cy + s * Math.sin(angle)
            if (i === 0) ctx.moveTo(px, py)
            else ctx.lineTo(px, py)
          }
          ctx.closePath()
        }
      }
      ctx.stroke()
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
  }
}
