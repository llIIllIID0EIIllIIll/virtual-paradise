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
        opacity: 1.0

        // Base full glitch image (Glitch.jpg)
        Image {
          id: baseImg
          anchors.fill: parent
          source: Qt.resolvedUrl("Glitch.jpg")
          fillMode: Image.PreserveAspectCrop
          asynchronous: false
          cache: true
        }

        // RGB Split - Cyan Left Shift
        Image {
          id: cyanShift
          anchors.fill: parent
          source: Qt.resolvedUrl("Glitch.jpg")
          fillMode: Image.PreserveAspectCrop
          x: -14
          opacity: 0.35
        }
        Rectangle {
          anchors.fill: parent
          color: "#00f5d4"
          opacity: 0.15
        }

        // RGB Split - Red Right Shift
        Image {
          id: redShift
          anchors.fill: parent
          source: Qt.resolvedUrl("Glitch.jpg")
          fillMode: Image.PreserveAspectCrop
          x: 14
          opacity: 0.35
        }
        Rectangle {
          anchors.fill: parent
          color: "#ff0055"
          opacity: 0.15
        }

        // -------------------------------------------------------------
        // HEAVY HORIZONTAL SLICES (5 distinct asymmetric bands)
        // -------------------------------------------------------------
        // Slice 1 (Top edge)
        Item {
          id: slice1
          width: win.width; height: win.height * 0.14; y: win.height * 0.04; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice1.x; y: -slice1.y; source: Qt.resolvedUrl("Glitch.jpg"); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#00f5d4"; opacity: 0.8 }
        }

        // Slice 2 (Upper middle)
        Item {
          id: slice2
          width: win.width; height: win.height * 0.22; y: win.height * 0.20; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice2.x; y: -slice2.y; source: Qt.resolvedUrl("Glitch.jpg"); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 3; color: "#ff0055"; opacity: 0.9 }
        }

        // Slice 3 (Center)
        Item {
          id: slice3
          width: win.width; height: win.height * 0.16; y: win.height * 0.44; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice3.x; y: -slice3.y; source: Qt.resolvedUrl("Glitch.jpg"); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.top: parent.top; width: parent.width; height: 2; color: "#00f5d4"; opacity: 0.8 }
        }

        // Slice 4 (Lower middle)
        Item {
          id: slice4
          width: win.width; height: win.height * 0.18; y: win.height * 0.62; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice4.x; y: -slice4.y; source: Qt.resolvedUrl("Glitch.jpg"); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#ff007f"; opacity: 0.9 }
        }

        // Slice 5 (Bottom)
        Item {
          id: slice5
          width: win.width; height: win.height * 0.15; y: win.height * 0.82; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice5.x; y: -slice5.y; source: Qt.resolvedUrl("Glitch.jpg"); fillMode: Image.PreserveAspectCrop }
        }

        // Black signal dropout blocks
        Rectangle {
          id: blackBlock1
          width: win.width * 0.65; height: 24; x: win.width * 0.15; y: win.height * 0.32
          color: "#05070a"; opacity: 0
        }
        Rectangle {
          id: blackBlock2
          width: win.width * 0.50; height: 36; x: win.width * 0.35; y: win.height * 0.68
          color: "#05070a"; opacity: 0
        }

        // Intense Chromatic Laser Bars
        Rectangle {
          id: cyanBar1
          width: parent.width; height: 10; y: win.height * 0.25; color: "#00f5d4"; opacity: 0
        }
        Rectangle {
          id: pinkBar1
          width: parent.width; height: 14; y: win.height * 0.55; color: "#ff007f"; opacity: 0
        }
        Rectangle {
          id: yellowBar1
          width: parent.width; height: 8; y: win.height * 0.78; color: "#ffee00"; opacity: 0
        }

        // Fullscreen white strobe
        Rectangle {
          id: whiteStrobe
          anchors.fill: parent
          color: "white"
          opacity: 0
        }
      }

      SequentialAnimation {
        running: true

        // -------------------------------------------------------------
        // PHASE 1: VIOLENT SIGNAL CRASH (0ms -> 200ms)
        // -------------------------------------------------------------
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: -140; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: 180; duration: 30 }
          NumberAnimation { target: slice3; property: "x"; to: -190; duration: 30 }
          NumberAnimation { target: slice4; property: "x"; to: 130; duration: 30 }
          NumberAnimation { target: slice5; property: "x"; to: -110; duration: 30 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0.9; duration: 30 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0.9; duration: 30 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0.9; duration: 30 }
        }

        ParallelAnimation {
          NumberAnimation { target: whiteStrobe; property: "opacity"; to: 0.45; duration: 25 }
          NumberAnimation { target: slice1; property: "x"; to: 110; duration: 25 }
          NumberAnimation { target: slice2; property: "x"; to: -130; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: 150; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: -90; duration: 25 }
          NumberAnimation { target: yellowBar1; property: "opacity"; to: 0.85; duration: 25 }
          NumberAnimation { target: blackBlock2; property: "opacity"; to: 0.9; duration: 25 }
        }

        ParallelAnimation {
          NumberAnimation { target: whiteStrobe; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: slice1; property: "x"; to: -60; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: 80; duration: 30 }
          NumberAnimation { target: slice3; property: "x"; to: -70; duration: 30 }
          NumberAnimation { target: slice4; property: "x"; to: 50; duration: 30 }
          NumberAnimation { target: slice5; property: "x"; to: -40; duration: 30 }
        }

        // Snap into solid glitch hold
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: 0; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: 0; duration: 30 }
          NumberAnimation { target: slice3; property: "x"; to: 0; duration: 30 }
          NumberAnimation { target: slice4; property: "x"; to: 0; duration: 30 }
          NumberAnimation { target: slice5; property: "x"; to: 0; duration: 30 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: yellowBar1; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: blackBlock2; property: "opacity"; to: 0; duration: 30 }
        }

        // -------------------------------------------------------------
        // PHASE 2: HEAVY GLITCH HOLD (200ms -> 560ms = 360ms)
        // Wallpaper swaps cleanly behind this solid Glitch screen!
        // -------------------------------------------------------------
        PauseAnimation { duration: 130 }

        // Mid-hold heavy jitter twitch
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: 120; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: -90; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0.8; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "y"; to: win.height * 0.38; duration: 25 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0.8; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: -60; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: 50; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0; duration: 25 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0; duration: 25 }
        }

        PauseAnimation { duration: 130 }

        // -------------------------------------------------------------
        // PHASE 3: FINAL VIOLENT SIGNAL TEAR & REVEAL (560ms -> 720ms)
        // -------------------------------------------------------------
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: 160; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: -210; duration: 30 }
          NumberAnimation { target: slice3; property: "x"; to: 170; duration: 30 }
          NumberAnimation { target: slice4; property: "x"; to: -180; duration: 30 }
          NumberAnimation { target: slice5; property: "x"; to: 140; duration: 30 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 1.0; duration: 30 }
          NumberAnimation { target: yellowBar1; property: "opacity"; to: 0.9; duration: 30 }
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.8; duration: 30 }
        }

        ParallelAnimation {
          NumberAnimation { target: whiteStrobe; property: "opacity"; to: 0.6; duration: 25 }
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.35; duration: 25 }
          NumberAnimation { target: slice1; property: "x"; to: -100; duration: 25 }
          NumberAnimation { target: slice2; property: "x"; to: 120; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: -90; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0.9; duration: 25 }
        }

        ParallelAnimation {
          NumberAnimation { target: whiteStrobe; property: "opacity"; to: 0.0; duration: 35 }
          NumberAnimation { target: glitchRoot; property: "opacity"; to: 0.0; duration: 35 }
          NumberAnimation { target: slice1; property: "x"; to: 0; duration: 35 }
          NumberAnimation { target: slice2; property: "x"; to: 0; duration: 35 }
          NumberAnimation { target: slice3; property: "x"; to: 0; duration: 35 }
          NumberAnimation { target: slice4; property: "x"; to: 0; duration: 35 }
          NumberAnimation { target: slice5; property: "x"; to: 0; duration: 35 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0; duration: 35 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0; duration: 35 }
          NumberAnimation { target: yellowBar1; property: "opacity"; to: 0; duration: 35 }
        }

        ScriptAction {
          script: Qt.quit()
        }
      }
    }
  }
}
