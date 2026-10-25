import QtQuick
import Quickshell
import Quickshell.Wayland

// Virtual☆Paradise — Ambient Glitch
//
// A cyberpunk atmosphere layer: every few seconds a horizontal tear of
// cyan or magenta flashes across the screen for a fraction of a second,
// like a signal that cannot quite hold its sync.
//
// The window is drawn everywhere but clickable nowhere: the empty mask
// makes every pointer event pass through to whatever is underneath, and
// the layer never takes keyboard focus.

ShellRoot {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      color: "transparent"
      WlrLayershell.namespace: "vp-ambient-glitch"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      // Where the tear sits and how it looks while it lives. Kept as faint
      // as a tear can be and still be seen: one or two pixels, a fifth of
      // full opacity, a nudge rather than a jump.
      property real tearY: 0
      property real tearHeight: 1
      property real tearShift: 0
      property real tearOpacity: 0
      property color tearColor: "#00ffdd"

      // The first tear comes early so the effect announces itself; after
      // that it stays unpredictable.
      property bool firstTear: true

      Timer {
        id: tearTimer
        interval: win.firstTear ? 2500 : 10000 + Math.random() * 15000
        repeat: true
        running: true

        onTriggered: {
          win.tearY = Math.random() * win.height
          win.tearHeight = 1 + Math.random() * 1
          win.tearColor = Math.random() > 0.5 ? "#00ffdd" : "#ff00ff"
          win.firstTear = false
          tearAnim.start()
        }
      }

      Rectangle {
        x: win.tearShift
        y: win.tearY
        width: win.width
        height: win.tearHeight
        color: win.tearColor
        opacity: win.tearOpacity
      }

      SequentialAnimation {
        id: tearAnim

        NumberAnimation {
          target: win
          property: "tearOpacity"
          to: 0.2
          duration: 60
        }
        NumberAnimation {
          target: win
          property: "tearShift"
          to: (Math.random() - 0.5) * 10
          duration: 40
        }
        NumberAnimation {
          target: win
          property: "tearOpacity"
          to: 0
          duration: 140
        }
        ScriptAction {
          script: win.tearShift = 0
        }
      }
    }
  }
}
