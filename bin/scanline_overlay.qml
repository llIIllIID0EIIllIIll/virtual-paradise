import QtQuick
import Quickshell
import Quickshell.Wayland

// Virtual☆Paradise — CRT Scanline Overlay
//
// A barely-there scanline grid over the whole screen, the last trace of a
// phosphor tube. Painted once into a canvas and left alone: no timers, no
// repaints, one texture.
//
// Click-through everywhere via the empty mask, no keyboard focus.

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
      WlrLayershell.namespace: "vp-scanlines"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      Item {
        anchors.fill: parent
        opacity: 0.05

        Canvas {
          id: scanlines
          anchors.fill: parent

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "rgba(0, 0, 0, 0.55)"
            for (var y = 0; y < height; y += 3) {
              ctx.fillRect(0, y, width, 1)
            }
          }

          Component.onCompleted: requestPaint()
        }
      }
    }
  }
}
