import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// A soft neon glow that trails the pointer.
//
// The position comes from a small Python helper that polls Hyprland's command
// socket (one connection per poll, no process per frame) and prints `x, y`
// lines. The canvas is painted once and only moved afterwards, so the effect
// costs a position update and a translate per frame, not a repaint.
Item {
  id: root

  readonly property color accent: Color.accent !== undefined ? Color.accent : "#00ffdd"
  readonly property color secondary: Color.urgent !== undefined ? Color.urgent : "#ff2bd6"
  readonly property string trackScript: Qt.resolvedUrl("cursor_track.py").toString().replace(/^file:\/\//, "")

  property real cursorX: -10000
  property real cursorY: -10000
  readonly property bool tracked: cursorX > -9000

  Process {
    id: tracker

    command: ["python3", root.trackScript]
    running: true

    stdout: SplitParser {
      onRead: function (line) {
        var parts = String(line).split(",")
        if (parts.length < 2) return
        var x = Number(parts[0])
        var y = Number(parts[1])
        if (!isFinite(x) || !isFinite(y)) return
        root.cursorX = x
        root.cursorY = y
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }
        color: "transparent"
        WlrLayershell.namespace: "vp-cursor-glow"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        Item {
          id: glow

          width: 150
          height: 150
          visible: root.tracked
          x: root.cursorX - modelData.x - width / 2
          y: root.cursorY - modelData.y - height / 2

          Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

          Canvas {
            anchors.fill: parent
            renderStrategy: Canvas.Threaded

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var cx = width / 2
              var cy = height / 2
              var a = root.accent
              var s = root.secondary

              // Outer sakura/magenta halo, then the cyan core, then a white
              // point: the same three-stop language as the window ramp.
              var halo = ctx.createRadialGradient(cx, cy, 0, cx, cy, width / 2)
              halo.addColorStop(0.0, "rgba(" + Math.round(s.r * 255) + ","
                + Math.round(s.g * 255) + "," + Math.round(s.b * 255) + ",0.10)")
              halo.addColorStop(0.55, "rgba(" + Math.round(s.r * 255) + ","
                + Math.round(s.g * 255) + "," + Math.round(s.b * 255) + ",0.04)")
              halo.addColorStop(1.0, "rgba(0,0,0,0)")
              ctx.fillStyle = halo
              ctx.fillRect(0, 0, width, height)

              var core = ctx.createRadialGradient(cx, cy, 0, cx, cy, width / 4)
              core.addColorStop(0.0, "rgba(" + Math.round(a.r * 255) + ","
                + Math.round(a.g * 255) + "," + Math.round(a.b * 255) + ",0.34)")
              core.addColorStop(0.5, "rgba(" + Math.round(a.r * 255) + ","
                + Math.round(a.g * 255) + "," + Math.round(a.b * 255) + ",0.12)")
              core.addColorStop(1.0, "rgba(0,0,0,0)")
              ctx.fillStyle = core
              ctx.fillRect(0, 0, width, height)

              ctx.fillStyle = "rgba(255,255,255,0.85)"
              ctx.beginPath()
              ctx.arc(cx, cy, 1.6, 0, Math.PI * 2)
              ctx.fill()
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
          }
        }
      }
    }
  }
}
