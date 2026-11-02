import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// A soft neon glow that trails the pointer over terminals.
//
// The position comes from the shared cursor server (`vp_cursor_track.py`) and
// the focused window from the shared window server (`vp_window_track.py`):
// one process each per session, shared with the hex spotlight. The glow only
// appears while the pointer is inside a focused terminal - over a game or a
// browser it is a bright spot with no business being there.
Item {
  id: root

  readonly property color accent: Color.accent !== undefined ? Color.accent : "#00ffdd"
  readonly property color secondary: Color.urgent !== undefined ? Color.urgent : "#ff2bd6"
  readonly property string publishScript: (Quickshell.env("HOME") || "")
    + "/.local/bin/vp_cursor_track.py"
  readonly property string cursorSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
    + "/vp-cursor.sock"
  readonly property string windowPublishScript: (Quickshell.env("HOME") || "")
    + "/.local/bin/vp_window_track.py"
  readonly property string windowSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
    + "/vp-window.sock"

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

  readonly property bool tracked: cursorX > -9000
  readonly property bool overTerminal: terminalFocused && tracked
    && cursorX >= winX && cursorX < winX + winW
    && cursorY >= winY && cursorY < winY + winH

  Process {
    id: publisher

    command: ["python3", root.publishScript]
    running: true
  }

  Socket {
    id: cursorFeed

    path: root.cursorSocket
    // The first connect is left to the retry timer below: the server binds a
    // moment after the plugin loads, and connecting eagerly logged a
    // ConnectionRefused at every login.
    connected: false

    parser: SplitParser {
      onRead: function (line) {
        root.lastFix = Date.now() / 1000
        var parts = String(line).split(",")
        if (parts.length < 2) return
        var x = parseInt(parts[0], 10)
        var y = parseInt(parts[1], 10)
        if (!isFinite(x) || !isFinite(y)) return
        root.cursorX = x
        root.cursorY = y
      }
    }

  }

  // Quickshell's Socket does not emit connectionStateChanged when the very
  // first connect fails (the server may not have bound yet at login), so a
  // steady retry - not just a signal - is what keeps the feed alive.
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: if (!cursorFeed.connected) cursorFeed.connected = true
  }

  // The server is shared: if nobody is serving (the other plugin stopped its
  // copy, or it died), take the socket back by starting our own.
  property double lastFix: 0
  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: {
      if (!cursorFeed.connected && !publisher.running) publisher.running = true
    }
  }

  // Focused window, from the shared window server: the glow is gated on the
  // pointer being inside a terminal, and the same feed drives the hex
  // spotlight.
  Process {
    id: windowPublisher

    command: ["python3", root.windowPublishScript]
    running: true
  }

  Socket {
    id: windowFeed

    path: root.windowSocket
    connected: false

    parser: SplitParser {
      onRead: function (line) {
        root.windowFix = Date.now() / 1000
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

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: if (!windowFeed.connected) windowFeed.connected = true
  }

  property double windowFix: 0
  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: {
      if (!windowFeed.connected && !windowPublisher.running)
        windowPublisher.running = true
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
          // Only over a focused terminal: over a game, a browser or the bar
          // the glow is a bright spot with nothing to light up.
          visible: root.overTerminal
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
