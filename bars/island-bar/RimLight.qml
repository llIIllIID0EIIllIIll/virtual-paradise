import QtQuick
import qs.Commons

// A pair of bright sparks with short trails running along each island's rim.
//
// The rim gradient already rotates; this layer adds the one motion the hover
// chrome does not have, so the bar border reads as its own thing: two scanner
// lights on opposite sides of the lap, so the rim is never still. Each island
// starts at a different point on the lap, so the three never move in lockstep.
// It is deliberately a Canvas - six sparks at 60fps are cheaper as one
// threaded paint than as six path animations, and the geometry is just a
// rounded-rect walk.
Item {
  id: root

  // Each entry is { x, width } in this item's coordinate space, ordered left
  // to right. All islands share the bar's height, radius and vertical centre.
  property var runs: []
  property real barHeight: 30
  property real radius: 15
  // The bar's rim angle in degrees; the spark laps faster than the gradient.
  property real angle: 0
  property real speedFactor: 2.5
  property color color: Color.accent
  // Not `enabled`: that shadows Item.enabled, which is a different concept.
  property bool lightEnabled: true

  readonly property bool active: lightEnabled && runs.length > 0 && width > 0 && height > 0

  visible: active

  onAngleChanged: requestPaint()
  onRunsChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onActiveChanged: requestPaint()

  function requestPaint() {
    if (active) canvas.requestPaint()
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

      var h = Math.max(4, root.barHeight)
      var y0 = (height - h) / 2
      var a = root.color
      var rgba = function (alpha) {
        return "rgba(" + Math.round(a.r * 255) + "," + Math.round(a.g * 255)
          + "," + Math.round(a.b * 255) + "," + alpha + ")"
      }

      for (var i = 0; i < root.runs.length; i++) {
        var run = root.runs[i]
        var x0 = Number(run.x || 0)
        var w = Number(run.width || 0)
        if (!isFinite(x0) || !isFinite(w) || w < 6) continue

        var r = Math.min(root.radius, w / 2, h / 2)
        var straightX = Math.max(0, w - 2 * r)
        var straightY = Math.max(0, h - 2 * r)
        var arc = Math.PI * r / 2
        var total = 2 * straightX + 2 * straightY + 4 * arc
        if (total <= 0) continue

        // Two sparks per island, opposite each other on the lap.
        for (var spark = 0; spark < 2; spark++) {
          var t = ((root.angle / 360) * root.speedFactor + i * 0.37
            + spark * 0.5) % 1.0
          var head = rimPoint(t * total, x0, y0, w, h, r, straightX, straightY, arc)

          // Head bloom, then the trail, then the white core on top.
          ctx.globalAlpha = 0.22
          ctx.fillStyle = rgba(1)
          ctx.beginPath()
          ctx.arc(head.x, head.y, 6, 0, Math.PI * 2)
          ctx.fill()

          var step = 4
          var count = 12
          for (var k = count - 1; k >= 1; k--) {
            var s = (t * total - k * step) % total
            if (s < 0) s += total
            var p = rimPoint(s, x0, y0, w, h, r, straightX, straightY, arc)
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
        }
      }

      ctx.globalAlpha = 1
    }
  }
}
