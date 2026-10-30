import QtQuick
import qs.Commons

// One spark with a short trail lapping the whole bar.
//
// The rim gradient rotates per island, but the scanner is a single light that
// travels the outer contour of the whole bar - the top edges, around the
// right cap, the bottom edges, around the left cap - so the three islands
// read as one circuit instead of three little ones. It is deliberately a
// Canvas: one spark at 60fps is cheaper as one threaded paint than a path
// animation, and the geometry is just a rounded-rect walk.
Item {
  id: root

  // Each entry is { x, width } in this item's coordinate space. The spark's
  // loop is the rounded-rect spanning from the first island's left edge to
  // the last island's right edge, at the islands' shared height.
  property var runs: []
  property real barHeight: 30
  property real radius: 15
  // Pixels per second. Constant in screen space: a wider bar does not speed
  // the spark up.
  property real sparkSpeed: 220
  property color color: Color.accent
  // Not `enabled`: that shadows Item.enabled, which is a different concept.
  property bool lightEnabled: true

  // Pixels travelled along the loop.
  property real sparkOffset: 0

  readonly property bool active: lightEnabled && runs.length > 0 && width > 0 && height > 0

  visible: active

  // The perimeter of the loop, so the timer can wrap the offset without
  // waiting for the next paint.
  readonly property real totalPerimeter: {
    var minX = Number.POSITIVE_INFINITY
    var maxX = Number.NEGATIVE_INFINITY
    for (var i = 0; i < runs.length; i++) {
      var x0 = Number(runs[i].x || 0)
      var w0 = Number(runs[i].width || 0)
      if (!isFinite(x0) || !isFinite(w0)) continue
      minX = Math.min(minX, x0)
      maxX = Math.max(maxX, x0 + w0)
    }
    if (!isFinite(minX) || !isFinite(maxX)) return 0
    var w = maxX - minX
    var h = Math.max(4, barHeight)
    var r = Math.min(radius, w / 2, h / 2)
    return 2 * Math.max(0, w - 2 * r) + 2 * Math.max(0, h - 2 * r)
      + 4 * Math.PI * r / 2
  }

  onRunsChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onActiveChanged: requestPaint()

  function requestPaint() {
    if (active) canvas.requestPaint()
  }

  Timer {
    interval: 16
    repeat: true
    running: root.active
    onTriggered: {
      root.sparkOffset = root.totalPerimeter > 0
        ? (root.sparkOffset + root.sparkSpeed * 0.016) % root.totalPerimeter
        : 0
      root.requestPaint()
    }
  }

  // Walks the rounded-rect perimeter clockwise from the top-left corner arc.
  function rimPoint(s, x, y, w, h, r, straightX, straightY, arc) {
    if (s < straightX) return { x: x + r + s, y: y }
    s -= straightX
    if (s < arc) {
      var a1 = -Math.PI / 2 + s / r
      return { x: x + w - r + r * Math.cos(a1), y: y + r + r * Math.sin(a1) }
    }
    s -= arc
    if (s < straightY) return { x: x + w, y: y + r + s }
    s -= straightY
    if (s < arc) {
      var a2 = s / r
      return { x: x + w - r + r * Math.cos(a2), y: y + h - r + r * Math.sin(a2) }
    }
    s -= arc
    if (s < straightX) return { x: x + w - r - s, y: y + h }
    s -= straightX
    if (s < arc) {
      var a3 = Math.PI / 2 + s / r
      return { x: x + r + r * Math.cos(a3), y: y + h - r + r * Math.sin(a3) }
    }
    s -= arc
    if (s < straightY) return { x: x, y: y + h - r - s }
    s -= straightY
    var a4 = Math.PI + s / r
    return { x: x + r + r * Math.cos(a4), y: y + r + r * Math.sin(a4) }
  }

  Canvas {
    id: canvas

    anchors.fill: parent
    renderStrategy: Canvas.Threaded

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (!root.active) return

      var minX = Number.POSITIVE_INFINITY
      var maxX = Number.NEGATIVE_INFINITY
      for (var i = 0; i < root.runs.length; i++) {
        var x0 = Number(root.runs[i].x || 0)
        var w0 = Number(root.runs[i].width || 0)
        if (!isFinite(x0) || !isFinite(w0)) continue
        minX = Math.min(minX, x0)
        maxX = Math.max(maxX, x0 + w0)
      }
      if (!isFinite(minX) || !isFinite(maxX)) return

      var h = Math.max(4, root.barHeight)
      var y0 = (height - h) / 2
      var w = maxX - minX
      var r = Math.min(root.radius, w / 2, h / 2)
      var straightX = Math.max(0, w - 2 * r)
      var straightY = Math.max(0, h - 2 * r)
      var arc = Math.PI * r / 2
      var total = 2 * straightX + 2 * straightY + 4 * arc
      if (total <= 0) return

      var a = root.color
      var rgba = function (alpha) {
        return "rgba(" + Math.round(a.r * 255) + "," + Math.round(a.g * 255)
          + "," + Math.round(a.b * 255) + "," + alpha + ")"
      }

      var head = rimPoint(root.sparkOffset, minX, y0, w, h, r,
        straightX, straightY, arc)

      // Head bloom, then the trail, then the white core on top.
      ctx.globalAlpha = 0.22
      ctx.fillStyle = rgba(1)
      ctx.beginPath()
      ctx.arc(head.x, head.y, 6, 0, Math.PI * 2)
      ctx.fill()

      var step = 4
      var count = 12
      for (var k = count - 1; k >= 1; k--) {
        var s = (root.sparkOffset - k * step) % total
        if (s < 0) s += total
        var p = rimPoint(s, minX, y0, w, h, r, straightX, straightY, arc)
        ctx.globalAlpha = 0.30 * (1 - k / count)
        ctx.fillStyle = rgba(1)
        ctx.beginPath()
        ctx.arc(p.x, p.y, 1.3, 0, Math.PI * 2)
        ctx.fill()
      }

      ctx.globalAlpha = 0.95
      ctx.fillStyle = "#ffffff"
      ctx.beginPath()
      ctx.arc(head.x, head.y, 2.0, 0, Math.PI * 2)
      ctx.fill()

      ctx.globalAlpha = 1
    }
  }
}
