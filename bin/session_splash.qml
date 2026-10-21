import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Virtual☆Paradise — Session splash.
//
// The greeter hands the screen to the session, and the session needs a few
// seconds before the desktop has anything to show: the compositor starts,
// then the shell loads its plugins. Without a splash that gap is a black
// screen.
//
// This shows the same cyber artwork as the boot splash and the login screen,
// so the whole way from the firmware to the desktop is one picture, and it
// fades out as soon as the shell answers.
ShellRoot {
  id: root

  property bool finished: false
  property real contentOpacity: 1

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

      color: "#050310"
      WlrLayershell.namespace: "paradise-session-splash"
      WlrLayershell.layer: WlrLayer.Overlay
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      Item {
        anchors.fill: parent
        opacity: root.contentOpacity

        Image {
          anchors.fill: parent
          source: "backdrop.png"
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
        }

        Image {
          anchors.centerIn: parent
          width: Math.min(1600, parent.width - 80)
          height: width * 9 / 16
          source: "still.png"
          fillMode: Image.Stretch
          asynchronous: true
          cache: true
        }

        Image {
          anchors.centerIn: parent
          width: Math.min(1600, parent.width - 80)
          height: width * 9 / 16
          source: "frame.png"
          fillMode: Image.Stretch
          asynchronous: true
          cache: true
        }
      }
    }
  }

  // The shell is up: it answers the ping, and the splash steps aside.
  Process {
    id: shellCheck
    command: ["omarchy-shell", "shell", "ping"]
    onExited: exitCode => {
      if (exitCode === 0 && !root.finished) {
        root.finished = true;
        fadeOut.start();
      }
    }
  }

  Timer {
    interval: 300
    repeat: true
    running: !root.finished
    onTriggered: {
      if (!shellCheck.running) {
        shellCheck.running = true;
      }
    }
  }

  // Safety net: never leave the splash on the screen.
  Timer {
    interval: 20000
    running: true
    onTriggered: {
      if (!root.finished) {
        root.finished = true;
        fadeOut.start();
      }
    }
  }

  SequentialAnimation {
    id: fadeOut
    NumberAnimation {
      target: root
      property: "contentOpacity"
      from: 1.0
      to: 0.0
      duration: 450
      easing.type: Easing.InCubic
    }
    ScriptAction {
      script: Qt.quit()
    }
  }

  Component.onCompleted: {
    shellCheck.running = true;
  }
}
