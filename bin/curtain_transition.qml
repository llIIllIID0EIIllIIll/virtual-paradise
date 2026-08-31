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
      WlrLayershell.layer: WlrLayer.Overlay
      exclusionMode: ExclusionMode.Ignore

      // Left curtain panel
      Rectangle {
        id: leftCurtain
        width: parent.width / 2 + 4
        height: parent.height
        x: -width
        color: "#0a0d12"

        // Cyberpunk neon edge border
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
          opacity: 0.6
        }
      }

      // Right curtain panel
      Rectangle {
        id: rightCurtain
        width: parent.width / 2 + 4
        height: parent.height
        x: parent.width
        color: "#0a0d12"

        // Cyberpunk neon edge border
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
          opacity: 0.6
        }
      }

      // Center glowing emblem & status
      Column {
        id: centerBadge
        anchors.centerIn: parent
        opacity: 0
        spacing: 8

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "★ VIRTUAL☆PARADISE ★"
          color: "#00f5d4"
          font.pixelSize: 24
          font.bold: true
          font.letterSpacing: 2
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰸌 Switching Live Wallpaper..."
          color: "#ffb7d5"
          font.pixelSize: 14
          font.bold: true
        }
      }

      SequentialAnimation {
        running: true

        // 1. Close curtains smoothly
        ParallelAnimation {
          NumberAnimation { target: leftCurtain; property: "x"; to: 0; duration: 250; easing.type: Easing.OutCubic }
          NumberAnimation { target: rightCurtain; property: "x"; to: win.width / 2 - 2; duration: 250; easing.type: Easing.OutCubic }
          NumberAnimation { target: centerBadge; property: "opacity"; to: 1; duration: 180 }
        }

        // 2. Pause while wallpaper is swapped behind curtains
        PauseAnimation { duration: 150 }

        // 3. Open curtains smoothly
        ParallelAnimation {
          NumberAnimation { target: leftCurtain; property: "x"; to: -leftCurtain.width; duration: 280; easing.type: Easing.InCubic }
          NumberAnimation { target: rightCurtain; property: "x"; to: win.width; duration: 280; easing.type: Easing.InCubic }
          NumberAnimation { target: centerBadge; property: "opacity"; to: 0; duration: 140 }
        }

        ScriptAction {
          script: Qt.quit()
        }
      }
    }
  }
}
