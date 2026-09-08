import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
  id: root

  property bool isReady: false
  property bool exiting: false

  // Process checking if the wallpaper has finished decoding and rendering
  Process {
    id: readyChecker
    command: ["test", "-f", "/tmp/virtual_paradise_wallpaper_ready"]
    onExited: exitCode => {
      if (exitCode === 0) {
        root.isReady = true
      }
    }
  }

  // Poll ready file every 30ms while waiting
  Timer {
    interval: 30
    repeat: true
    running: !root.isReady && !root.exiting
    onTriggered: {
      if (!readyChecker.running) {
        readyChecker.running = true
      }
    }
  }

  // Safety fallback timeout: maximum 4.5s so glitch screen NEVER gets stuck
  Timer {
    interval: 4500
    running: true
    onTriggered: {
      root.isReady = true
    }
  }

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
      WlrLayershell.layer: (Quickshell.env("CURTAIN_LAYER") === "bottom") ? WlrLayer.Bottom : WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      property bool entryFinished: false
      property bool hasStartedExit: false

      Connections {
        target: root
        function onIsReadyChanged() {
          if (root.isReady && win.entryFinished && !win.hasStartedExit) {
            win.hasStartedExit = true
            loadingLoopAnim.stop()
            loadingHud.opacity = 0
            exitAnim.start()
          }
        }
      }

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

        // -------------------------------------------------------------
        // CYBERPUNK LOADING HUD (Active while wallpaper is synchronizing)
        // -------------------------------------------------------------
        Item {
          id: loadingHud
          anchors.centerIn: parent
          width: 500
          height: 125
          opacity: 0.0

          Behavior on opacity { NumberAnimation { duration: 160 } }

          Rectangle {
            anchors.fill: parent
            color: "#05070a"
            opacity: 0.88
            radius: 10
            border.color: "#00f5d4"
            border.width: 1.5
          }

          // Cyber Corner Accents
          Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 16; height: 3; color: "#ff007f" }
          Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 3; height: 16; color: "#ff007f" }
          Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 16; height: 3; color: "#00f5d4" }
          Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 3; height: 16; color: "#00f5d4" }
          Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 16; height: 3; color: "#00f5d4" }
          Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 3; height: 16; color: "#00f5d4" }
          Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 16; height: 3; color: "#ff007f" }
          Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 3; height: 16; color: "#ff007f" }

          Column {
            anchors.centerIn: parent
            spacing: 12

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 8
              Text {
                text: "⚡"
                color: "#ffee00"
                font.pixelSize: 15
              }
              Text {
                text: "VIRTUAL☆PARADISE // SYNCHRONIZING STREAM"
                color: "#00f5d4"
                font.pixelSize: 13
                font.bold: true
                font.family: "JetBrainsMono Nerd Font, monospace"
              }
            }

            // Neon Scanning Progress Track
            Rectangle {
              id: track
              width: 380
              height: 4
              color: "#161e2e"
              radius: 2
              clip: true
              anchors.horizontalCenter: parent.horizontalCenter

              Rectangle {
                id: scanBar
                width: 100
                height: 4
                radius: 2
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0.0; color: "transparent" }
                  GradientStop { position: 0.5; color: "#00f5d4" }
                  GradientStop { position: 1.0; color: "#ff007f" }
                }

                SequentialAnimation on x {
                  loops: Animation.Infinite
                  running: loadingHud.opacity > 0
                  NumberAnimation { from: -100; to: 380; duration: 650; easing.type: Easing.InOutQuad }
                  NumberAnimation { from: 380; to: -100; duration: 650; easing.type: Easing.InOutQuad }
                }
              }
            }

            Text {
              id: loadingSubtext
              text: "BUFFERING NEURAL FRAMES..."
              color: "#ff007f"
              font.pixelSize: 10
              font.bold: true
              font.family: "JetBrainsMono Nerd Font, monospace"
              anchors.horizontalCenter: parent.horizontalCenter
              opacity: 0.9

              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: loadingHud.opacity > 0
                NumberAnimation { from: 0.9; to: 0.3; duration: 400 }
                NumberAnimation { from: 0.3; to: 0.9; duration: 400 }
              }
            }
          }
        }

        // Fullscreen white strobe
        Rectangle {
          id: whiteStrobe
          anchors.fill: parent
          color: "white"
          opacity: 0
        }
      }

      // -------------------------------------------------------------
      // PHASE 1: VIOLENT SIGNAL CRASH (0ms -> ~200ms)
      // -------------------------------------------------------------
      SequentialAnimation {
        id: entryAnim
        running: true

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

        ScriptAction {
          script: {
            win.entryFinished = true
            if (root.isReady) {
              win.hasStartedExit = true
              exitAnim.start()
            } else {
              loadingHud.opacity = 1.0
              loadingLoopAnim.start()
            }
          }
        }
      }

      // -------------------------------------------------------------
      // PHASE 2: GLITCH LOADING LOOP (Active until wallpaper is ready)
      // -------------------------------------------------------------
      SequentialAnimation {
        id: loadingLoopAnim
        loops: Animation.Infinite

        PauseAnimation { duration: 180 }

        // Cyber slice jitter pulse
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: 90; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: -70; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0.7; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "y"; to: win.height * 0.36; duration: 25 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0.75; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: -40; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: 35; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0; duration: 25 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0; duration: 25 }
        }

        PauseAnimation { duration: 180 }

        // Secondary slice jitter pulse
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: -80; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: 100; duration: 25 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0.75; duration: 25 }
          NumberAnimation { target: pinkBar1; property: "y"; to: win.height * 0.58; duration: 25 }
          NumberAnimation { target: blackBlock2; property: "opacity"; to: 0.8; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: 40; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: -50; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: 0; duration: 25 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0; duration: 25 }
          NumberAnimation { target: blackBlock2; property: "opacity"; to: 0.8; duration: 25 }
        }
      }

      // -------------------------------------------------------------
      // PHASE 3: FINAL VIOLENT SIGNAL TEAR & REVEAL (Exits smoothly)
      // -------------------------------------------------------------
      SequentialAnimation {
        id: exitAnim

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
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0.35; duration: 35 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0; duration: 35 }
          NumberAnimation { target: yellowBar1; property: "opacity"; to: 0; duration: 35 }
        }

        ScriptAction {
          script: {
            root.exiting = true
            Qt.quit()
          }
        }
      }
    }
  }
}
