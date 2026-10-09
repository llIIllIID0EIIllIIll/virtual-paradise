import QtQuick
import qs.Commons

// Streaming glow drawn in the gaps between islands.
//
// Adapted from Shibumi-Shell's V1 gap-effects layer (mode 1): a soft accent
// line at the bar's vertical centre with two layers of dots travelling along
// it, the fast layer pulsing. It is the one effect that fits this bar's shape -
// the islands already leave real gaps, so there is somewhere for it to live
// without covering a widget.
//
// Deliberately a Canvas: a gap can carry dozens of dots at 30fps, which is
// cheaper as one threaded paint than as dozens of animated Rectangles.
Item {
  id: root

  // Each entry is { x, width } in this item's coordinate space, ordered left
  // to right. Only the spans between consecutive entries are painted.
  property var runs: []
  property color accent: Color.accent
  property bool enabled: true
  property real fade: 0.0

  // Two cadences, like the source: a fast dense layer and a slow sparse one.
  readonly property int fastSpacing: 65
  readonly property int slowSpacing: 110
  readonly property real fastSpeed: 70
  readonly property real slowSpeed: 38

  readonly property bool active: enabled && runs.length > 1 && width > 0 && height > 0

  visible: active
  opacity: fade

  Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }

  function requestFrame() {
    if (active) canvas.requestPaint()
  }

  onRunsChanged: requestFrame()
  onWidthChanged: requestFrame()
  onHeightChanged: requestFrame()
  onActiveChanged: {
    if (active) fade = 1.0
    else fade = 0.0
    requestFrame()
  }

  Timer {
    interval: 33
    repeat: true
    running: root.active
    onTriggered: root.requestFrame()
  }

  Canvas {
    id: canvas

    anchors.fill: parent
    renderStrategy: Canvas.Threaded

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (!root.active) return

      var now = Date.now()
      var cy = height / 2
      var a = root.accent
      var rgba = function (alpha) {
        return "rgba(" + Math.round(a.r * 255) + "," + Math.round(a.g * 255)
          + "," + Math.round(a.b * 255) + "," + alpha + ")"
      }

      for (var gapIndex = 0; gapIndex + 1 < root.runs.length; gapIndex++) {
        var leftRun = root.runs[gapIndex]
        var rightRun = root.runs[gapIndex + 1]
        var x1 = Number(leftRun.x || 0) + Number(leftRun.width || 0)
        var x2 = Number(rightRun.x || 0)
        var gapWidth = x2 - x1
        if (!isFinite(x1) || !isFinite(x2) || gapWidth < 12) continue

        ctx.save()
        ctx.beginPath()
        ctx.rect(x1, 0, gapWidth, height)
        ctx.clip()

        // Soft horizontal glow through the gap.
        var glowHeight = 8
        var glow = ctx.createLinearGradient(0, cy - glowHeight, 0, cy + glowHeight)
        glow.addColorStop(0.00, rgba(0.00))
        glow.addColorStop(0.25, rgba(0.05))
        glow.addColorStop(0.45, rgba(0.10))
        glow.addColorStop(0.50, rgba(0.13))
        glow.addColorStop(0.55, rgba(0.10))
        glow.addColorStop(0.75, rgba(0.05))
        glow.addColorStop(1.00, rgba(0.00))
        ctx.fillStyle = glow
        ctx.fillRect(x1, cy - glowHeight, gapWidth, glowHeight * 2)

        // The line the dots travel along.
        ctx.globalAlpha = 0.45
        ctx.strokeStyle = rgba(1)
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(x1, cy)
        ctx.lineTo(x2, cy)
        ctx.stroke()
        ctx.globalAlpha = 0.22
        ctx.strokeStyle = "#ffffff"
        ctx.lineWidth = 0.75
        ctx.beginPath()
        ctx.moveTo(x1, cy)
        ctx.lineTo(x2, cy)
        ctx.stroke()

        // Fast layer: smaller, denser, pulses.
        var fastOffset = (now / 1000 * root.fastSpeed) % root.fastSpacing
        var fastStart = Math.ceil((x1 - fastOffset) / root.fastSpacing)
        for (var i = 0; i < 60; i++) {
          var dotId = fastStart + i + 100000
          var dotX = fastOffset + (fastStart + i) * root.fastSpacing
          if (dotX >= x2) break
          var pulse = dotId % 5 === 0
            ? 0.5 + 0.5 * Math.sin(now / 700 + dotId * 2.4) : 0
          ctx.globalAlpha = pulse > 0 ? 0.28 + pulse * 0.18 : 0.30
          ctx.fillStyle = rgba(1)
          ctx.beginPath()
          ctx.arc(dotX, cy, pulse > 0 ? 4 + pulse * 1.5 : 4.5, 0, Math.PI * 2)
          ctx.fill()
          ctx.globalAlpha = pulse > 0 ? 0.95 : 0.90
          ctx.fillStyle = "#ffffff"
          ctx.beginPath()
          ctx.arc(dotX, cy, pulse > 0 ? 1.6 + pulse * 0.4 : 1.6, 0, Math.PI * 2)
          ctx.fill()
        }

        // Slow layer: larger haloes, sparse.
        var slowOffset = (now / 1000 * root.slowSpeed) % root.slowSpacing
        var slowStart = Math.ceil((x1 - slowOffset) / root.slowSpacing)
        for (var j = 0; j < 40; j++) {
          var slowX = slowOffset + (slowStart + j) * root.slowSpacing
          if (slowX >= x2) break
          ctx.globalAlpha = 0.11
          ctx.fillStyle = rgba(1)
          ctx.beginPath()
          ctx.arc(slowX, cy, 8.5, 0, Math.PI * 2)
          ctx.fill()
          ctx.globalAlpha = 0.50
          ctx.fillStyle = "#ffffff"
          ctx.beginPath()
          ctx.arc(slowX, cy, 2.3, 0, Math.PI * 2)
          ctx.fill()
        }

        ctx.restore()
      }
    }
  }
}
