import QtQuick
import qs.Commons

// A single light pulse crossing each gap between islands.
//
// The earlier version stacked a solid rail, two bead layers and a white core
// in every gap. On a gap only a few dozen pixels wide that read as noise, and
// it fought the hex circuitry underneath. One comet with a short trail over a
// faint, edge-faded rail keeps the motion legible and lets the pattern breathe.
//
// Deliberately a Canvas: a few gradients and circles per gap at 30fps are
// cheaper as one threaded paint than as dozens of animated Rectangles.
Item {
  id: root

  // Each entry is { x, width } in this item's coordinate space, ordered left
  // to right. Only the spans between consecutive entries are painted.
  property var runs: []
  property color accent: Color.accent
  // Not `enabled`: that shadows Item.enabled, which is a different concept.
  property bool glowEnabled: true
  property real fade: 0.0

  // Seconds for the comet to cross one gap. The animated value is the
  // fraction of that crossing, not an absolute pixel position: when a gap
  // resizes (the active-window island grows on a focus change), the comet
  // keeps its place in the crossing and glides with the island edge instead
  // of being re-rolled by a new modulo.
  readonly property real cometPeriod: 1.6
  // 0..1 crossing phase. Advanced by a fixed step on every timer tick rather
  // than read from the wall clock, so a stalled event loop slows the comet
  // down instead of teleporting it forward.
  property real cometLap: 0
  // Extra travel beyond the gap so the comet enters and leaves off-screen
  // instead of popping into existence at the island rim.
  readonly property real cometOverhang: 40

  readonly property bool active: glowEnabled && runs.length > 1 && width > 0 && height > 0

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
    onTriggered: {
      root.cometLap = (root.cometLap + 0.033 / root.cometPeriod) % 1.0
      root.requestFrame()
    }
  }

  Canvas {
    id: canvas

    anchors.fill: parent
    renderStrategy: Canvas.Threaded

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (!root.active) return

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

        // Soft horizontal band through the gap. Tighter and dimmer than the
        // old glow so it reads as a lit seam, not a neon tube.
        var bandHeight = 9
        var band = ctx.createLinearGradient(0, cy - bandHeight, 0, cy + bandHeight)
        band.addColorStop(0.00, rgba(0.00))
        band.addColorStop(0.50, rgba(0.09))
        band.addColorStop(1.00, rgba(0.00))
        ctx.fillStyle = band
        ctx.fillRect(x1, cy - bandHeight, gapWidth, bandHeight * 2)

        // Rail fades into both islands, so it has no hard endpoints to fight
        // the rounded rims.
        var rail = ctx.createLinearGradient(x1, 0, x2, 0)
        rail.addColorStop(0.00, rgba(0.00))
        rail.addColorStop(0.22, rgba(0.26))
        rail.addColorStop(0.50, rgba(0.38))
        rail.addColorStop(0.78, rgba(0.26))
        rail.addColorStop(1.00, rgba(0.00))
        ctx.strokeStyle = rail
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(x1, cy)
        ctx.lineTo(x2, cy)
        ctx.stroke()

        // One comet per gap. The phase offset keeps the two gaps from
        // travelling in lockstep. Position is a fraction of the crossing, so a
        // gap that resizes under the comet moves it smoothly instead of
        // wrapping it to a new spot.
        var span = gapWidth + root.cometOverhang * 2
        var frac = (root.cometLap + gapIndex * 0.37) % 1.0
        var head = x1 - root.cometOverhang + frac * span
        var trail = 34
        var comet = ctx.createLinearGradient(head - trail, 0, head + 6, 0)
        comet.addColorStop(0.00, rgba(0.00))
        comet.addColorStop(0.55, rgba(0.22))
        comet.addColorStop(0.90, rgba(0.72))
        comet.addColorStop(1.00, rgba(0.85))
        ctx.fillStyle = comet
        ctx.fillRect(head - trail, cy - 1.5, trail + 6, 3)

        // Bloom plus a white core at the head. The core is what makes the
        // pulse read at a glance; the bloom supplies the neon spill.
        ctx.globalAlpha = 0.22
        ctx.fillStyle = rgba(1)
        ctx.beginPath()
        ctx.arc(head, cy, 6.5, 0, Math.PI * 2)
        ctx.fill()
        ctx.globalAlpha = 0.92
        ctx.fillStyle = "#ffffff"
        ctx.beginPath()
        ctx.arc(head, cy, 1.7, 0, Math.PI * 2)
        ctx.fill()

        ctx.restore()
      }
    }
  }
}
