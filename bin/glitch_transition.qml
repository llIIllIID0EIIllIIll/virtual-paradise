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

      Item {
        id: glitchRoot
        anchors.fill: parent
        opacity: 0

        // Base full glitch image (Glitch.jpg)
        Image {
          id: baseImg
          anchors.fill: parent
          source: Qt.resolvedUrl("Glitch.jpg")
          fillMode: Image.PreserveAspectCrop
          asynchronous: false
          cache: true
        }

        // Horizontal Slice 1: Upper band
        Item {
          id: slice1
          width: win.width
          height: win.height * 0.18
          y: win.height * 0.08
          clip: true
          x: 0
          Image {
            width: win.width
            height: win.height
            x: -slice1.x
            y: -slice1.y
            source: Qt.resolvedUrl("Glitch.jpg")
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
          }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#00f5d4"; opacity: 0.6 }
        }

        // Horizontal Slice 2: Upper-middle band
        Item {
          id: slice2
          width: win.width
          height: win.height * 0.24
          y: win.height * 0.30
          clip: true
          x: 0
          Image {
            width: win.width
            height: win.height
            x: -slice2.x
            y: -slice2.y
            source: Qt.resolvedUrl("Glitch.jpg")
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
          }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#ff007f"; opacity: 0.7 }
        }

        // Horizontal Slice 3: Lower-middle band
        Item {
          id: slice3
          width: win.width
          height: win.height * 0.22
          y: win.height * 0.58
          clip: true
          x: 0
          Image {
            width: win.width
            height: win.height
            x: -slice3.x
            y: -slice3.y
            source: Qt.resolvedUrl("Glitch.jpg")
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
          }
          Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#00f5d4"; opacity: 0.6 }
        }

        // Horizontal Slice 4: Bottom band
        Item {
          id: slice4
          width: win.width
          height: win.height * 0.16
          y: win.height * 0.82
          clip: true
          x: 0
          Image {
            width: win.width
            height: win.height
            x: -slice4.x
            y: -slice4.y
            source: Qt.resolvedUrl("Glitch.jpg")
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
          }
        }

        // Neon chromatic glitch strips
        Rectangle {
          id: cyanBar
          width: parent.width
          height: 8
          y: win.height * 0.28
          color: "#00f5d4"
          opacity: 0
        }

        Rectangle {
          id: pinkBar
          width: parent.width
          height: 12
          y: win.height * 0.62
          color: "#ff007f"
          opacity: 0
        }

        Rectangle {
          id: whiteFlash
          anchors.fill: parent
          color: "white"
          opacity: 0
        }
      }

      SequentialAnimation {
        running: true

        // -------------------------------------------------------------
        // PHASE 1: Jitter Flash-In (0ms -> ~125ms)
        // -------------------------------------------------------------
        ParallelAnimation {
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.85; duration: 25 }
          NumberAnimation { target: slice1; property: "x"; to: -65; duration: 25 }
          NumberAnimation { target: slice2; property: "x"; to: 85; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: -40; duration: 25 }
          NumberAnimation { target: cyanBar; property: "opacity"; to: 0.8; duration: 25 }
        }

        ParallelAnimation {
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.25; duration: 20 }
          NumberAnimation { target: slice1; property: "x"; to: 45; duration: 20 }
          NumberAnimation { target: slice2; property: "x"; to: -70; duration: 20 }
          NumberAnimation { target: slice4; property: "x"; to: 90; duration: 20 }
          NumberAnimation { target: pinkBar; property: "opacity"; to: 0.8; duration: 20 }
          NumberAnimation { target: cyanBar; property: "opacity"; to: 0; duration: 20 }
        }

        ParallelAnimation {
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 1.0; duration: 30 }
          NumberAnimation { target: whiteFlash; property: "opacity"; to: 0.35; duration: 20 }
          NumberAnimation { target: slice1; property: "x"; to: -25; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: 35; duration: 30 }
          NumberAnimation { target: slice3; property: "x"; to: -50; duration: 30 }
          NumberAnimation { target: slice4; property: "x"; to: 0; duration: 30 }
        }

        // Lock solid coverage
        ParallelAnimation {
          NumberAnimation { target: whiteFlash; property: "opacity"; to: 0; duration: 25 }
          NumberAnimation { target: slice1; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: slice2; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: pinkBar; property: "opacity"; to: 0; duration: 25 }
        }

        // -------------------------------------------------------------
        // PHASE 2: Solid Hold & Signal Interference (125ms -> 585ms = 460ms hold)
        // Wallpaper swaps cleanly behind this solid Glitch screen!
        // -------------------------------------------------------------
        PauseAnimation { duration: 160 }

        // Glitch twitch 1
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: 40; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: -30; duration: 25 }
          NumberAnimation { target: cyanBar; property: "opacity"; to: 0.6; duration: 25 }
          NumberAnimation { target: cyanBar; property: "y"; to: win.height * 0.45; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: cyanBar; property: "opacity"; to: 0; duration: 25 }
        }

        PauseAnimation { duration: 150 }

        // Glitch twitch 2
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: -50; duration: 20 }
          NumberAnimation { target: slice4; property: "x"; to: 60; duration: 20 }
          NumberAnimation { target: pinkBar; property: "opacity"; to: 0.6; duration: 20 }
          NumberAnimation { target: pinkBar; property: "y"; to: win.height * 0.75; duration: 20 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: 0; duration: 20 }
          NumberAnimation { target: slice4; property: "x"; to: 0; duration: 20 }
          NumberAnimation { target: pinkBar; property: "opacity"; to: 0; duration: 20 }
        }

        PauseAnimation { duration: 60 }

        // -------------------------------------------------------------
        // PHASE 3: Glitch Breakdown & Reveal (585ms -> 715ms)
        // -------------------------------------------------------------
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: 75; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: -95; duration: 30 }
          NumberAnimation { target: slice3; property: "x"; to: 60; duration: 30 }
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.7; duration: 30 }
          NumberAnimation { target: cyanBar; property: "opacity"; to: 0.8; duration: 30 }
          NumberAnimation { target: cyanBar; property: "y"; to: win.height * 0.32; duration: 30 }
        }

        ParallelAnimation {
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.25; duration: 30 }
          NumberAnimation { target: slice1; property: "x"; to: -50; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: 60; duration: 30 }
          NumberAnimation { target: slice4; property: "x"; to: -70; duration: 30 }
          NumberAnimation { target: pinkBar; property: "opacity"; to: 0.8; duration: 30 }
          NumberAnimation { target: cyanBar; property: "opacity"; to: 0; duration: 30 }
        }

        ParallelAnimation {
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.0; duration: 40 }
          NumberAnimation { target: slice1; property: "x"; to: 0; duration: 40 }
          NumberAnimation { target: slice2; property: "x"; to: 0; duration: 40 }
          NumberAnimation { target: slice3; property: "x"; to: 0; duration: 40 }
          NumberAnimation { target: slice4; property: "x"; to: 0; duration: 40 }
          NumberAnimation { target: pinkBar; property: "opacity"; to: 0; duration: 40 }
        }

        ScriptAction {
          script: Qt.quit()
        }
      }
    }
  }
}
