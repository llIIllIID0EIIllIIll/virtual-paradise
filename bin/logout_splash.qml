import QtQuick
import Qt5Compat.GraphicalEffects
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

      color: "#0a0d12"
      WlrLayershell.namespace: "logout-splash"
      WlrLayershell.layer: WlrLayer.Overlay
      exclusionMode: ExclusionMode.Ignore

      AnimatedImage {
        id: outroGif
        anchors.fill: parent
        source: Qt.resolvedUrl("Miku_missing.gif")
        fillMode: Image.PreserveAspectCrop
        playing: true
        asynchronous: false
        cache: true
      }

      // Neon frame borders
      Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 3
        color: "#00f5d4"
      }
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 3
        color: "#ffb7d5"
      }

      // Bottom status bar with Cyberpunk Gradient
      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 55
        width: statusText.paintedWidth
        height: statusText.paintedHeight

        Text {
          id: statusText
          anchors.centerIn: parent
          text: Quickshell.env("SPLASH_TEXT") || "󰐥 Shutting down system cleanly..."
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          font.bold: true
          font.letterSpacing: 2
          visible: false
        }

        LinearGradient {
          id: gradientFill
          anchors.fill: parent
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#00f5d4" }  // Miku Cyan
            GradientStop { position: 0.5; color: "#00ff88" }  // Hacker Green
            GradientStop { position: 1.0; color: "#ffb7d5" }  // Sakura Pink
          }
          visible: false
        }

        OpacityMask {
          anchors.fill: parent
          source: gradientFill
          maskSource: statusText
        }
      }
    }
  }
}
