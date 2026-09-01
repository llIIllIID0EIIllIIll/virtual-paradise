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
      WlrLayershell.layer: (Quickshell.env("CURTAIN_LAYER") === "overlay") ? WlrLayer.Overlay : WlrLayer.Bottom
      exclusionMode: ExclusionMode.Ignore

      readonly property int halfWidth: Math.ceil(win.width / 2)

      // Left curtain panel (Displays the left 50% of Portal.jpg)
      Item {
        id: leftCurtain
        width: 0
        height: win.height
        x: 0
        y: 0
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

        // Cyberpunk neon right vertical edge border (center meeting line)
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
      }

      // Right curtain panel (Displays the right 50% of Portal.jpg)
      Item {
        id: rightCurtain
        width: 0
        height: win.height
        x: win.width
        y: 0
        clip: true

        Image {
          width: win.width
          height: win.height
          anchors.right: parent.right
          y: 0
          source: Qt.resolvedUrl("Portal.jpg")
          fillMode: Image.PreserveAspectCrop
          asynchronous: false
          cache: true
        }

        // Cyberpunk neon left vertical edge border (center meeting line)
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
      }

      SequentialAnimation {
        running: true

        // 1. INTRO: Snappy & fast curtain closure from both sides to center (200ms)
        ParallelAnimation {
          NumberAnimation {
            target: leftCurtain
            property: "width"
            from: 0
            to: win.halfWidth
            duration: 200
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            target: rightCurtain
            property: "width"
            from: 0
            to: win.halfWidth
            duration: 200
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            target: rightCurtain
            property: "x"
            from: win.width
            to: win.width - win.halfWidth
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        // 2. HOLD: 500ms pause while wallpaper decodes behind closed curtain
        PauseAnimation { duration: 500 }

        // 3. OUTRO: Open curtains outward to both sides (280ms)
        ParallelAnimation {
          NumberAnimation {
            target: leftCurtain
            property: "x"
            from: 0
            to: -win.halfWidth
            duration: 280
            easing.type: Easing.InCubic
          }
          NumberAnimation {
            target: rightCurtain
            property: "x"
            from: win.width - win.halfWidth
            to: win.width
            duration: 280
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
