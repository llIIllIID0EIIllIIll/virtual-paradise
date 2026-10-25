import QtQuick
import Quickshell
import Quickshell.Wayland

// Virtual☆Paradise — Window Death
//
// Where a window just closed, a red glitch burst burns for half a second:
// red static, jumping tear bars, dropout blocks and a strobe, then nothing.
// The window does not fade away politely; it dies on screen.
//
// The burst is placed exactly over the rectangle the window occupied
// (VP_DEATH_RECT="x,y,w,h" in global coordinates) and is click-through:
// it is a corpse, not a surface.

ShellRoot {
  id: root

  property string rectEnv: Quickshell.env("VP_DEATH_RECT") || ""
  property var rect: (function () {
    var p = rectEnv.split(",")
    if (p.length !== 4) return { x: 0, y: 0, width: 0, height: 0 }
    return { x: +p[0], y: +p[1], width: +p[2], height: +p[3] }
  })()

  // The whole burst lives and dies in under half a second.
  Timer {
    interval: 480
    running: true
    onTriggered: Qt.quit()
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      // Quickshell 0.3.2 screens expose x/y/width/height directly; older
      // builds used a geometry object. Accept both so the burst lands on
      // the right monitor either way.
      property var geo: (function () {
        var s = modelData
        if (s.geometry) return s.geometry
        return { x: s.x || 0, y: s.y || 0, width: s.width || 0, height: s.height || 0 }
      })()
      property bool hit: root.rect.width > 0 && root.rect.height > 0
        && root.rect.x < geo.x + geo.width && root.rect.x + root.rect.width > geo.x
        && root.rect.y < geo.y + geo.height && root.rect.y + root.rect.height > geo.y

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      margins {
        left: Math.max(0, root.rect.x - geo.x)
        top: Math.max(0, root.rect.y - geo.y)
        right: Math.max(0, (geo.x + geo.width) - (root.rect.x + root.rect.width))
        bottom: Math.max(0, (geo.y + geo.height) - (root.rect.y + root.rect.height))
      }

      color: "transparent"
      visible: win.hit
      WlrLayershell.namespace: "vp-window-death"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      property real fade: 1

      // The corpse fades at the very end, so the burst does not cut.
      Timer {
        interval: 340
        running: win.hit
        onTriggered: fadeAnim.start()
      }

      NumberAnimation {
        id: fadeAnim
        target: win
        property: "fade"
        to: 0
        duration: 120
        easing.type: Easing.InQuad
      }

      Item {
        anchors.fill: parent
        opacity: win.fade
        clip: true

        // Dark red base: whatever was here is gone, only the wound remains.
        Rectangle {
          anchors.fill: parent
          color: "#2a0008"
          opacity: 0.92
        }

        // Red static, crawling. noise.jpg is greyscale TV static, so a red
        // wash over it is red static - no shader needed.
        Image {
          id: noise
          anchors.fill: parent
          source: Qt.resolvedUrl("noise.jpg")
          fillMode: Image.PreserveAspectCrop
          cache: true
        }

        Rectangle {
          anchors.fill: parent
          color: "#ff2244"
          opacity: 0.55
        }

        // Tear bars: heavy, jumping every tick.
        Timer {
          interval: 40
          repeat: true
          running: win.hit && win.fade > 0
          onTriggered: {
            bar1.y = Math.random() * parent.height
            bar1.height = 4 + Math.random() * 18
            bar1.opacity = Math.random() < 0.8 ? 0.9 : 0
            bar2.y = Math.random() * parent.height
            bar2.height = 3 + Math.random() * 12
            bar2.opacity = Math.random() < 0.7 ? 0.85 : 0
            bar3.y = Math.random() * parent.height
            bar3.height = 2 + Math.random() * 8
            bar3.opacity = Math.random() < 0.6 ? 0.8 : 0
            drop1.y = Math.random() * parent.height
            drop1.opacity = Math.random() < 0.5 ? 0.95 : 0
            drop2.y = Math.random() * parent.height
            drop2.opacity = Math.random() < 0.45 ? 0.95 : 0
            noise.x = (Math.random() - 0.5) * 40
          }
        }

        Rectangle {
          id: bar1
          width: parent.width
          color: "#ff003c"
          opacity: 0
        }
        Rectangle {
          id: bar2
          width: parent.width
          x: (Math.random() - 0.5) * 30
          color: "#ff5577"
          opacity: 0
        }
        Rectangle {
          id: bar3
          width: parent.width * 0.7
          color: "#00ffdd"
          opacity: 0
        }
        Rectangle {
          id: drop1
          width: parent.width * 0.6
          x: parent.width * 0.2
          height: 26
          color: "#05000a"
          opacity: 0
        }
        Rectangle {
          id: drop2
          width: parent.width * 0.45
          x: parent.width * 0.1
          height: 16
          color: "#05000a"
          opacity: 0
        }

        // The first frame is a strobe: the moment of death is bright.
        Rectangle {
          id: strobe
          anchors.fill: parent
          color: "#ff8899"
          opacity: 0.55

          NumberAnimation {
            target: strobe
            property: "opacity"
            to: 0
            duration: 70
            running: true
          }
        }
      }
    }
  }
}
