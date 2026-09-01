import QtQuick
import Quickshell
import Quickshell.Wayland

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
      WlrLayershell.namespace: "curtain-transition"
      WlrLayershell.layer: WlrLayer.Bottom
      exclusionMode: ExclusionMode.Ignore

      // Left curtain panel (Displays the left 50% of Portal.jpg)
      Item {
        id: leftCurtain
        width: Math.ceil(win.width / 2)
        height: win.height
        x: 0
        y: -win.height
        clip: true

        Image {
          width: win.width
          height: win.height
          x: 0
          y: 0
          source: Qt.resolvedUrl("Portal.jpg")
          fillMode: Image.PreserveAspectCrop
          asynchronous: false
          cache: true
        }

        // Cyberpunk neon right vertical edge border (when opening to sides)
        Rectangle {
          anchors.right: parent.right
          width: 3
          height: parent.height
          color: "#00f5d4"
        }
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 3
          width: 2
          height: parent.height
          color: "#ffb7d5"
          opacity: 0.7
        }

        // Cyberpunk neon bottom horizontal border (when dropping from top)
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 3
          color: "#00f5d4"
        }
      }

      // Right curtain panel (Displays the right 50% of Portal.jpg)
      Item {
        id: rightCurtain
        width: Math.ceil(win.width / 2)
        height: win.height
        x: Math.floor(win.width / 2)
        y: -win.height
        clip: true

        Image {
          width: win.width
          height: win.height
          x: -Math.floor(win.width / 2)
          y: 0
          source: Qt.resolvedUrl("Portal.jpg")
          fillMode: Image.PreserveAspectCrop
          asynchronous: false
          cache: true
        }

        // Cyberpunk neon left vertical edge border (when opening to sides)
        Rectangle {
          anchors.left: parent.left
          width: 3
          height: parent.height
          color: "#00f5d4"
        }
        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: 3
          width: 2
          height: parent.height
          color: "#ffb7d5"
          opacity: 0.7
        }

        // Cyberpunk neon bottom horizontal border (when dropping from top)
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 3
          color: "#00f5d4"
        }
      }

      SequentialAnimation {
        running: true

        // 1. INTRO: Drop both panels together from top to bottom (từ trên xuống)
        ParallelAnimation {
          NumberAnimation {
            target: leftCurtain
            property: "y"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            target: rightCurtain
            property: "y"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
          }
        }

        // 2. HOLD: Brief pause while live wallpaper swaps behind the closed Portal
        PauseAnimation { duration: 150 }

        // 3. OUTRO: Split and open curtains outward to both sides (mở ra 2 bên)
        ParallelAnimation {
          NumberAnimation {
            target: leftCurtain
            property: "x"
            to: -leftCurtain.width
            duration: 300
            easing.type: Easing.InCubic
          }
          NumberAnimation {
            target: rightCurtain
            property: "x"
            to: win.width
            duration: 300
            easing.type: Easing.InCubic
          }
        }

        ScriptAction {
          script: Qt.quit()
        }
      }
    }
  }
}
