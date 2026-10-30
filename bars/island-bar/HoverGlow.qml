import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// Hover chrome behind the bar widget under the pointer.
//
// The first pass was a flat accent halo, which read as the same grey-blue box
// on every widget. This version treats the hovered widget like a tiny window:
// a gradient rim that rides the same ramp as the compositor's window borders
// and spins with the bar, a bloom whose colour is sampled from that ramp, and
// a faint hex shimmer inside the pill so the effect belongs to the HUD the
// rest of the bar is built from.
//
// The whole chrome is created by a Loader only while the halo is visible, so
// a bar with dozens of widgets pays nothing for the ones that are not
// hovered. Everything the caller can switch off still routes through the
// bar's effects switch, and hoverGlow can disable this one on its own.
Item {
  id: root

  property bool active: false
  // The bar's rim angle, so the hover rim is part of the same slow spin as
  // the islands and the windows.
  property real barAngle: 0
  property real radius: 0
  // 0..1 lets a caller dim the halo for a dense layout without changing the
  // shared toggle.
  property real intensity: 1.0
  // Color is a singleton and normally always has an accent, but a partially
  // loaded host theme can leave it undefined. Keep the halo visible instead of
  // binding an invalid QColor.
  readonly property color accent: Color.accent !== undefined ? Color.accent : "#ff2bd6"

  opacity: active ? intensity : 0
  visible: active || opacity > 0
  scale: active ? 1.0 : 0.96

  Behavior on opacity {
    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
  }

  Behavior on scale {
    NumberAnimation { duration: 220; easing.type: Easing.OutBack }
  }

  // Stays alive through the fade-out, then destroys the whole chrome. That
  // keeps the rotating rim, the hex canvas and the pulse animation off every
  // idle widget.
  Loader {
    anchors.fill: parent
    active: root.active || root.opacity > 0
    sourceComponent: chrome
  }

  Component {
    id: chrome

    Item {
      id: chromeRoot

      anchors.fill: parent

      property real pulse: 1.0

      SequentialAnimation on pulse {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation {
          from: 1.0; to: 0.78
          duration: 1700; easing.type: Easing.InOutSine
        }
        NumberAnimation {
          from: 0.78; to: 1.0
          duration: 1700; easing.type: Easing.InOutSine
        }
      }

      RimRamp {
        id: ramp

        alphaScale: 1.0
        angle: root.barAngle
      }

      // Bloom: the colour is sampled from the ramp at the current angle, so
      // the spill is never the same colour twice while the rim travels.
      RectangularShadow {
        anchors.fill: parent
        radius: root.radius
        blur: 20
        spread: 0
        offset: Qt.vector2d(0, 0)
        color: Qt.rgba(ramp.colorAt.r, ramp.colorAt.g, ramp.colorAt.b,
          0.30 * chromeRoot.pulse)
      }

      // Faint wash so text stays legible over a bright wallpaper.
      Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(ramp.colorAt.r, ramp.colorAt.g, ramp.colorAt.b, 0.10)
      }

      // Top sheen: the lit-glass cue the bar border deliberately does not
      // have, so the hovered pill reads as a pressed button instead of a
      // smaller copy of the island rim.
      Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        opacity: 0.55
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.14) }
          GradientStop { position: 0.5; color: "transparent" }
        }
      }

      // HUD hex shimmer inside the pill, clipped to its rounded shape. Static
      // pattern, repainted a few times a second so the tint drifts with the
      // rim instead of costing a full-rate canvas.
      Canvas {
        id: hexCanvas

        anchors.fill: parent
        opacity: 0.22
        renderStrategy: Canvas.Threaded

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          if (width <= 0 || height <= 0) return

          var r = Math.min(root.radius, width / 2, height / 2)
          ctx.beginPath()
          ctx.moveTo(r, 0)
          ctx.arcTo(width, 0, width, height, r)
          ctx.arcTo(width, height, 0, height, r)
          ctx.arcTo(0, height, 0, 0, r)
          ctx.arcTo(0, 0, width, 0, r)
          ctx.closePath()
          ctx.clip()

          var c = ramp.colorAt
          ctx.strokeStyle = "rgba(" + Math.round(c.r * 255) + ","
            + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ",1)"
          ctx.lineWidth = 1
          ctx.lineJoin = "round"

          var s = 4
          var hexW = Math.sqrt(3) * s
          var rowStep = 1.5 * s
          var cols = Math.ceil(width / hexW) + 2
          var rows = Math.ceil(height / rowStep) + 2

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

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Timer {
          interval: 120
          repeat: true
          running: root.active
          onTriggered: hexCanvas.requestPaint()
        }
      }

      // The rim: a miniature of the window border, on the same gradient and
      // the same angle as the islands.
      BorderOverlay {
        anchors.fill: parent
        radius: root.radius
        borderSpec: ({
          color: root.accent,
          widths: { top: 1, right: 1, bottom: 1, left: 1 },
          gradient: {
            enabled: true,
            angle: root.barAngle,
            colors: ramp.colors
          }
        })
      }
    }
  }
}
