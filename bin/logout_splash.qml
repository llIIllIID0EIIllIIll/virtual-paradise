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

      color: "#0a0d12"
      WlrLayershell.namespace: "logout-splash"
      WlrLayershell.layer: WlrLayer.Overlay
      exclusionMode: ExclusionMode.Ignore

      AnimatedImage {
        id: outroGif
        anchors.fill: parent
        source: Qt.resolvedUrl("Miku_outro.gif")
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

      // Center glowing farewell text
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        spacing: 8

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "★ GOODBYE · VIRTUAL☆PARADISE ★"
          color: "#00f5d4"
          font.pixelSize: 24
          font.bold: true
          font.letterSpacing: 3
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Quickshell.env("SPLASH_TEXT") || "󰐥 Shutting down system cleanly..."
          color: "#ffb7d5"
          font.pixelSize: 15
          font.bold: true
        }
      }
    }
  }
}
