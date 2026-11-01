import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// A pool of light that reveals the terminal's hex circuitry around the pointer.
//
// The terminal background image is nearly invisible on purpose; this overlay
// paints a brighter copy of the same hex grid inside a soft radial mask that
// follows the cursor, but only while a terminal window is focused. The canvas
// is small and only repaints while it moves, so the cost is a 260x260 paint at
// cursor rate, not a full-window shader.
Item {
  id: root

  readonly property color accent: Color.accent !== undefined ? Color.accent : "#00ffdd"
  readonly property string trackScript: Qt.resolvedUrl("cursor_track.py").toString().replace(/^file:\/\//, "")

  readonly property var terminalClasses: [
    "com.mitchellh.ghostty",
    "ghostty",
    "foot",
    "Alacritty",
    "kitty",
    "org.wezfurlong.wezterm",
    "wezterm"
  ]

  property real cursorX: -10000
  property real cursorY: -10000
  property bool terminalFocused: false
  property real winX: 0
  property real winY: 0
  property real winW: 0
  property real winH: 0

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

  Process {
    id: windowProbe

    command: ["hyprctl", "-j", "activewindow"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = null
        try {
          data = JSON.parse(text)
        } catch (e) {
          data = null
        }
        if (!data || !data.class || !data.at || !data.size) {
          root.terminalFocused = false
          return
        }
        var isTerminal = root.terminalClasses.indexOf(String(data.class)) !== -1
        root.terminalFocused = isTerminal
        if (!isTerminal) return
        root.winX = Number(data.at[0])
        root.winY = Number(data.at[1])
        root.winW = Number(data.size[0])
        root.winH = Number(data.size[1])
      }
    }
  }

  // Geometry only changes on focus/move/resize; 500ms keeps it current without
  // polling per frame.
  Timer {
    interval: 500
    repeat: true
    running: true
    onTriggered: if (!windowProbe.running) windowProbe.running = true
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        readonly property bool onThisScreen: root.winX < modelData.x + modelData.width
          && root.winX + root.winW > modelData.x
          && root.winY < modelData.y + modelData.height
          && root.winY + root.winH > modelData.y

        screen: modelData
        anchors {
          top: true
          left: true
        }
        margins {
          top: root.winY - modelData.y
          left: root.winX - modelData.x
        }
        implicitWidth: Math.max(0, root.winW)
        implicitHeight: Math.max(0, root.winH)
        visible: !!(root.terminalFocused && root.onThisScreen
          && root.winW > 40 && root.winH > 40)
        color: "transparent"
        WlrLayershell.namespace: "vp-hex-spotlight"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        Item {
          id: spotlight

          width: 320
          height: 320
          visible: root.cursorX > -9000
          x: root.cursorX - modelData.x - root.winX - width / 2
          y: root.cursorY - modelData.y - root.winY - height / 2

          Behavior on x { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }

          // The pattern must stay fixed to the terminal window while the
          // spotlight moves over it, so every move repaints with a shift.
          onXChanged: canvas.requestPaint()
          onYChanged: canvas.requestPaint()

          Canvas {
            id: canvas

            anchors.fill: parent
            renderStrategy: Canvas.Threaded

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var cx = width / 2
              var cy = height / 2
              var a = root.accent
              var rgb = Math.round(a.r * 255) + "," + Math.round(a.g * 255)
                + "," + Math.round(a.b * 255)

              // Soft light pool first; the hex grid sits on top of it.
              var pool = ctx.createRadialGradient(cx, cy, 0, cx, cy, width / 2)
              pool.addColorStop(0.0, "rgba(" + rgb + ",0.11)")
              pool.addColorStop(0.55, "rgba(" + rgb + ",0.04)")
              pool.addColorStop(1.0, "rgba(0,0,0,0)")
              ctx.fillStyle = pool
              ctx.fillRect(0, 0, width, height)

              // Hex grid aligned to the terminal window, not to the moving
              // canvas: shift by where this canvas sits inside the window.
              // The cell size is fixed (s = 7) so every terminal window shows
              // the same hexes; the background tile uses the same size.
              var originX = root.cursorX - modelData.x - root.winX - width / 2
              var originY = root.cursorY - modelData.y - root.winY - height / 2
              var s = 7
              var hexW = Math.sqrt(3) * s
              var rowStep = 1.5 * s
              var cols = Math.ceil(width / hexW) + 3
              var rows = Math.ceil(height / rowStep) + 3
              // The background tile is 158x168: 13.03 hex columns and exactly
              // 16 rows. Its repetition restarts the lattice every 158px, so
              // the horizontal phase drifts by (158 - 13*hexW) per tile.
              // Anchor the reveal to the tile under the canvas, or the lit
              // hexes walk off the ghost ones towards the far window edge.
              var tileW = 158
              var tileDrift = tileW - 13 * hexW
              var tileIndex = Math.floor(originX / tileW)
              var shiftX = ((originX - tileDrift * tileIndex) % hexW + hexW) % hexW
              var shiftY = ((originY % rowStep) + rowStep) % rowStep
              // The tile is exactly 16 rows tall, so the row parity that
              // decides the half-cell offset repeats every tile; count it
              // from the window origin, not from the canvas.
              var rowOffset = Math.floor(originY / rowStep)

              function hexPath() {
                ctx.beginPath()
                for (var col = -1; col < cols; col++) {
                  for (var row = -1; row < rows; row++) {
                    var hx = col * hexW + ((row + rowOffset) % 2 ? hexW / 2 : 0) - shiftX
                    var hy = row * rowStep + s - shiftY
                    for (var i = 0; i < 6; i++) {
                      var angle = Math.PI / 180 * (60 * i - 30)
                      var px = hx + s * Math.cos(angle)
                      var py = hy + s * Math.sin(angle)
                      if (i === 0) ctx.moveTo(px, py)
                      else ctx.lineTo(px, py)
                    }
                    ctx.closePath()
                  }
                }
              }

              // Haze first: a wide, faint stroke that turns the grid into mist
              // around the cursor. Then the crisp circuitry line on top.
              ctx.lineJoin = "round"
              ctx.strokeStyle = "rgba(" + rgb + ",0.10)"
              ctx.lineWidth = 3.2
              hexPath()
              ctx.stroke()

              ctx.strokeStyle = "rgba(" + rgb + ",0.30)"
              ctx.lineWidth = 1
              hexPath()
              ctx.stroke()

              // Circular reveal: everything fades out at the pool's edge.
              ctx.globalCompositeOperation = "destination-in"
              var mask = ctx.createRadialGradient(cx, cy, 0, cx, cy, width / 2)
              mask.addColorStop(0.0, "rgba(255,255,255,1)")
              mask.addColorStop(0.35, "rgba(255,255,255,0.92)")
              mask.addColorStop(0.70, "rgba(255,255,255,0.35)")
              mask.addColorStop(1.0, "rgba(255,255,255,0)")
              ctx.fillStyle = mask
              ctx.fillRect(0, 0, width, height)
              ctx.globalCompositeOperation = "source-over"
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
