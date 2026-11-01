import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// A pool of light that paints a hex grid around the pointer.
//
// The terminal itself stays plain glass; this overlay draws the grid only
// inside a soft radial mask that follows the cursor, but only while a
// terminal window is focused. The grid is anchored to the terminal window,
// so the hexes light up in the same places no matter where the pointer is.
// The canvas is small and only repaints while it moves, so the cost is a
// 320x320 paint at cursor rate, not a full-window shader.
Item {
  id: root

  readonly property color accent: Color.accent !== undefined ? Color.accent : "#00ffdd"
  readonly property string trackScript: Qt.resolvedUrl("cursor_track.py").toString().replace(/^file:\/\//, "")
  readonly property string windowTrackScript: Qt.resolvedUrl("window_track.py").toString().replace(/^file:\/\//, "")

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

  // Focus and geometry come from Hyprland's event socket, not from a poll:
  // polling `hyprctl` every 500ms made the glow appear half a second after
  // focus landed on a terminal. The helper prints `class|x,y wxh` lines.
  Process {
    id: windowTracker

    command: ["python3", root.windowTrackScript]
    running: true

    stdout: SplitParser {
      onRead: function (line) {
        var parts = String(line).split("|")
        if (parts.length < 2) return
        var geom = parts[1].split(" ")
        if (geom.length < 2) return
        var at = geom[0].split(",")
        var size = geom[1].split("x")
        if (at.length < 2 || size.length < 2) return
        var x = Number(at[0])
        var y = Number(at[1])
        var w = Number(size[0])
        var h = Number(size[1])
        if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h)) return
        root.terminalFocused = root.terminalClasses.indexOf(parts[0]) !== -1
        root.winX = x
        root.winY = y
        root.winW = w
        root.winH = h
      }
    }
  }

  // If the helper ever dies (a Hyprland restart racing the socket, a bad
  // environment), bring it back: the glow would otherwise never return.
  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: if (!windowTracker.running) windowTracker.running = true
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
        visible: !!(root.terminalFocused && onThisScreen
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

          // The pool lives in screen coordinates. Only cursor movement is
          // smoothed: the panel's origin moves with the focused window, so
          // animating the item's position across a focus change made the
          // glow race in from a corner of the terminal. Keeping the source
          // position in screen space means a focus change only recomputes
          // the item's offset and the pool is already under the cursor.
          property real poolX: -10000
          property real poolY: -10000
          property bool placed: false

          Behavior on poolX {
            enabled: spotlight.placed
            NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
          }
          Behavior on poolY {
            enabled: spotlight.placed
            NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
          }

          x: poolX - modelData.x - root.winX - width / 2
          y: poolY - modelData.y - root.winY - height / 2

          readonly property int cell: 7
          readonly property real hexW: Math.sqrt(3) * cell
          readonly property real rowStep: 1.5 * cell

          // The grid must stay fixed to the terminal window while the pool
          // moves over it, so every move repaints with a new phase.
          onXChanged: canvas.requestPaint()
          onYChanged: canvas.requestPaint()

          Connections {
            target: root
            function onCursorXChanged() { spotlight.follow() }
            function onCursorYChanged() { spotlight.follow() }
          }

          function follow() {
            var x = root.cursorX
            var y = root.cursorY
            if (x < -9000) return
            if (!placed) {
              // The first fix of a session: place, do not glide.
              poolX = x
              poolY = y
              placed = true
              return
            }
            // A jump this large is a warp, not a movement; gliding it would
            // read as the same race from a corner.
            if (Math.abs(x - poolX) > 600 || Math.abs(y - poolY) > 600) {
              placed = false
              poolX = x
              poolY = y
              placed = true
            } else {
              poolX = x
              poolY = y
            }
          }

          // The lattice is painted once into this offscreen canvas and never
          // shown directly. A full repaint is ~37ms (a thousand hex strokes),
          // which no cursor-rate canvas can afford; blitting this texture is
          // ~0.3ms, so the pool canvas can repaint synchronously and the grid
          // never lags behind the pool while it animates towards the pointer.
          Canvas {
            id: lattice

            property color accent: root.accent

            width: Math.ceil(spotlight.width + spotlight.hexW) + 4
            height: Math.ceil(spotlight.height + 2 * spotlight.rowStep) + 4
            visible: false
            renderStrategy: Canvas.Threaded

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var a = accent
              var rgb = Math.round(a.r * 255) + "," + Math.round(a.g * 255)
                + "," + Math.round(a.b * 255)
              var s = spotlight.cell
              var hexW = spotlight.hexW
              var rowStep = spotlight.rowStep
              var cols = Math.ceil(width / hexW) + 3
              var rows = Math.ceil(height / rowStep) + 3

              ctx.beginPath()
              for (var col = -1; col < cols; col++) {
                for (var row = -1; row < rows; row++) {
                  var hx = col * hexW + (row % 2 ? hexW / 2 : 0)
                  var hy = row * rowStep + s
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

              // Haze first: a wide, faint stroke that turns the grid into
              // mist. Then the crisp circuitry line on top. Both stay low
              // enough that text under the pool is still easy to read.
              ctx.lineJoin = "round"
              ctx.strokeStyle = "rgba(" + rgb + ",0.055)"
              ctx.lineWidth = 3.0
              ctx.stroke()
              ctx.strokeStyle = "rgba(" + rgb + ",0.15)"
              ctx.lineWidth = 1
              ctx.stroke()
            }

            onAccentChanged: requestPaint()
            Component.onCompleted: requestPaint()
          }

          Canvas {
            id: canvas

            anchors.fill: parent
            // Synchronous on purpose: a threaded paint can be displayed a
            // frame late, which slides the grid for a moment every time the
            // pool moves. The paint is a blit now, so it is cheap enough.
            renderStrategy: Canvas.Immediate

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var cx = width / 2
              var cy = height / 2
              var a = root.accent
              var rgb = Math.round(a.r * 255) + "," + Math.round(a.g * 255)
                + "," + Math.round(a.b * 255)

              // Soft light pool first; the lattice is blitted on top of it.
              // The whole effect is deliberately gentle: the terminal text
              // stays readable and selecting it is not a fight with the glow.
              var pool = ctx.createRadialGradient(cx, cy, 0, cx, cy, width / 2)
              pool.addColorStop(0.0, "rgba(" + rgb + ",0.06)")
              pool.addColorStop(0.55, "rgba(" + rgb + ",0.02)")
              pool.addColorStop(1.0, "rgba(0,0,0,0)")
              ctx.fillStyle = pool
              ctx.fillRect(0, 0, width, height)

              // Blit the lattice at the phase that anchors it to the window:
              // the vertical shift is taken modulo two rows, so the row
              // parity that offsets every other row never flips, and the
              // horizontal one modulo a column.
              var shiftX = ((spotlight.x % spotlight.hexW) + spotlight.hexW)
                % spotlight.hexW
              var shiftY = ((spotlight.y % (2 * spotlight.rowStep))
                + 2 * spotlight.rowStep) % (2 * spotlight.rowStep)
              ctx.drawImage(lattice, -shiftX, -shiftY)

              // Circular reveal: everything fades out at the pool's edge.
              ctx.globalCompositeOperation = "destination-in"
              var mask = ctx.createRadialGradient(cx, cy, 0, cx, cy, width / 2)
              mask.addColorStop(0.0, "rgba(255,255,255,1)")
              mask.addColorStop(0.35, "rgba(255,255,255,0.85)")
              mask.addColorStop(0.70, "rgba(255,255,255,0.28)")
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
