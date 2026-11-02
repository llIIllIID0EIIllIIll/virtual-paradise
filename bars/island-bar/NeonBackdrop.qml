import QtQuick
import qs.Commons

// Faint hex circuitry behind the islands.
//
// This is an underlay, not a surface. The islands are opaque and cover it, so
// only the gaps between them reveal the pattern. That keeps the gaps alive
// without painting a second plate - and a second outline - around the whole
// bar. There is deliberately no fill and no border here: the island rims are
// the only chrome.
Item {
  id: root

  property color accent: Color.accent
  property real cell: Style.space(7)
  property bool animated: true
  // Low enough that the pattern reads as circuitry under glass rather than a
  // texture competing with the widgets.
  property real patternOpacity: 0.11

  // Horizontal drift, in pixels per second. Slower than the gap comet so the
  // two motions do not fight for attention.
  readonly property real driftPerSecond: 5

  // Column spacing. The drift must wrap on exactly this, or the pattern jumps
  // once per loop: a hex row repeats every column, not every cell.
  readonly property real hexWidth: Math.sqrt(3) * Math.max(4, cell)

  property real phase: 0

  // Driven by an animation, not a timer: a timer advances in whole ticks and
  // lands on a different sub-pixel offset each loop, which is what read as
  // stutter. Linear and seamless, wrapping on the column width.
  NumberAnimation on phase {
    running: root.animated && root.visible
    loops: Animation.Infinite
    from: 0
    to: root.hexWidth
    duration: Math.max(1, root.hexWidth / root.driftPerSecond * 1000)
    easing.type: Easing.Linear
  }

  onPhaseChanged: canvas.requestPaint()

  // The lattice is painted once into this offscreen canvas and never shown
  // directly. A full repaint is ~15ms - one path per hex over the whole bar -
  // which is the entire frame budget, so the drift could only be painted
  // every other frame and read as stepping. Blitting the cached texture is
  // ~0.2ms, and the fractional offset resamples the lines smoothly instead
  // of jumping whole pixels.
  Canvas {
    id: lattice

    property color accent: root.accent
    property real cell: Math.max(4, root.cell)

    width: Math.ceil(root.width + root.hexWidth) + 4
    height: Math.ceil(root.height + 3 * cell) + 4
    visible: false
    renderStrategy: Canvas.Threaded

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (width <= 0 || height <= 0) return

      var a = accent
      var stroke = "rgba(" + Math.round(a.r * 255) + "," + Math.round(a.g * 255)
        + "," + Math.round(a.b * 255) + ",1)"
      ctx.strokeStyle = stroke
      ctx.lineWidth = 1
      ctx.lineJoin = "round"

      // Pointy-top hexagons. Cols are spaced by the hex width, rows by 3/4 of
      // the hex height, and every other column is offset by half a row so the
      // cells interlock. The drift is applied by the blit, not here.
      var s = Math.max(4, cell)
      var hexW = Math.sqrt(3) * s
      var rowStep = 1.5 * s
      var cols = Math.ceil(width / hexW) + 2
      var rows = Math.ceil(height / rowStep) + 1

      ctx.beginPath()
      for (var col = -1; col < cols; col++) {
        for (var row = -1; row < rows; row++) {
          var cx = col * hexW + (row % 2 ? hexW / 2 : 0)
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

    onAccentChanged: requestPaint()
    onCellChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
  }

  Canvas {
    id: canvas

    anchors.fill: parent
    // Synchronous: the blit is cheap, and a threaded paint can be displayed a
    // frame late, which would add its own stutter on top of the drift.
    renderStrategy: Canvas.Immediate
    opacity: root.patternOpacity

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (width <= 0 || height <= 0) return
      ctx.drawImage(lattice, -root.phase, 0)
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
  }
}
