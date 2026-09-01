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

      // Top-to-Bottom Curtain Panel (Portal.jpg dropping smoothly from top)
      Item {
        id: curtainPanel
        width: win.width
        height: win.height
        x: 0
        y: -win.height
        clip: true

        Image {
          anchors.fill: parent
          source: "file:///home/doe/.local/bin/Portal.jpg"
          fillMode: Image.PreserveAspectCrop
          asynchronous: false
          cache: true
        }

        // Cyberpunk neon bottom edge border
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 3
          color: "#00f5d4"
        }
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 3
          width: parent.width
          height: 2
          color: "#ffb7d5"
          opacity: 0.7
        }
      }

      SequentialAnimation {
        running: true

        // 1. Drop Portal curtain from top to bottom (từ trên xuống)
        NumberAnimation {
          target: curtainPanel
          property: "y"
          to: 0
          duration: 260
          easing.type: Easing.OutCubic
        }

        // 2. Hold momentarily while new wallpaper starts in background
        PauseAnimation { duration: 150 }

        // 3. Roll Portal curtain back up to reveal new wallpaper
        NumberAnimation {
          target: curtainPanel
          property: "y"
          to: -win.height
          duration: 300
          easing.type: Easing.InCubic
        }

        ScriptAction {
          script: Qt.quit()
        }
      }
    }
  }
}
