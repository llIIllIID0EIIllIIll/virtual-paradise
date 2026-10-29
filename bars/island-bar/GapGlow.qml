import QtQuick
import qs.Commons

// A light stream crossing the gaps between islands.
//
// The earlier version stacked a solid rail, two bead layers and a white core
// in every gap. On a gap only a few dozen pixels wide that read as noise, and
// it fought the hex circuitry underneath. The stream is now a fixed row of
// comets travelling across the whole bar in absolute coordinates; each gap is
// a window onto it. That keeps the motion even and, more importantly, makes it
// independent of the bar: an island that resizes when the window focus changes
// can never move a comet or change its speed, it only changes how much of the
// stream shows through.
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

  // The comet is a fixed stream travelling across the whole bar; each gap is
  // just a window onto it. Nothing in the stream's position depends on where
  // an island edge currently is, so a resizing island cannot tug the comet
  // around or change its speed.
  readonly property real cometSpacing: 90
  readonly property real cometSpeed: 90
  // Pixels of stream travel. Advanced by a fixed step on every timer tick
  // rather than read from the wall clock, so a stalled event loop slows the
  // stream down instead of teleporting it forward.
  property real cometOffset: 0

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
      root.cometOffset = (root.cometOffset + root.cometSpeed * 0.033) % root.cometSpacing
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

        // Comets from the global stream. Draw every stream position; the gap
        // clip culls the rest, so a resizing gap reveals more or less of the
        // stream without ever moving it.
        var trail = 34
        var count = Math.ceil(width / root.cometSpacing) + 2
        var first = root.cometOffset - root.cometSpacing
        for (var k = 0; k < count; k++) {
          var head = first + k * root.cometSpacing
          if (head + 8 < x1 || head - trail > x2) continue

          ctx.globalAlpha = 1
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
        }

        ctx.restore()
      }
    }
  }
}
