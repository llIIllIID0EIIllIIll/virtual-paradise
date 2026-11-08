import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
  id: root

  property bool isReady: false
  property bool exiting: false
  property string targetName: Quickshell.env("WALLPAPER_TARGET") || "LIVE STREAM"
  property int loadingPhase: 0

  // The picture the glitch cuts apart. The wallpaper switch uses the glitch
  // wallpaper; the session splash uses the theme's cyber artwork.
  property string baseImage: Quickshell.env("VP_TRANSITION_IMAGE") || "Glitch.jpg"

  // Wait for the desktop instead of for a wallpaper file: the session splash
  // stays until the shell answers.
  property bool waitForShell: Quickshell.env("VP_TRANSITION_WAIT_SHELL") === "1"

  // The session splash gets its own language: the framed picture stays in the
  // middle of the screen and is torn horizontally, and the glitch is built
  // from three flat signal blocks (black/cyan/violet) stacked diagonally
  // instead of a gradient wash. The wallpaper switch keeps its old look.
  property bool sessionStyle: Quickshell.env("VP_TRANSITION_STYLE") === "session"
  property real shiftScale: sessionStyle ? 0.30 : 1.0

  // Safety net, so the overlay can never stay on the screen.
  property int timeout: parseInt(Quickshell.env("VP_TRANSITION_TIMEOUT") || "4500", 10)

  // How hard the signal breaks up. The wallpaper switch can stay subtle, the
  // session splash wants the full "TV with a bad antenna" look.
  property real noiseLevel: parseFloat(Quickshell.env("VP_TRANSITION_NOISE") || "0.35")

  // A counter the random jitter is derived from: every tick the picture
  // shifts, so the static keeps crawling instead of sitting still.
  property int tick: 0

  // Whether the picture is allowed to jump around. On while the signal is
  // breaking up and during the last of it, off while the entry and the
  // reveal animate the picture themselves.
  property bool jitter: false

  // The overlay is done and gone.
  property bool finished: false

  // How much of the glitch is still left after the picture and the static are
  // gone. The picture and the noise end at once, the tearing does not.
  property real remnant: 1

  // The transition is only worth showing if it is seen. The wallpaper is
  // usually ready in a fraction of a second, and a glitch that flashes past
  // reads as a flicker instead of a transition - so the curtain holds for a
  // moment before it opens.
  property real shownAt: 0
  property real minimumVisible: 1200

  Component.onCompleted: {
    shownAt = Date.now();
  }

  function readyNow() {
    // The wallpaper is up, but the curtain stays for its minimum time.
    if (Date.now() - root.shownAt < root.minimumVisible) {
      if (!exitTimer.running) {
        exitTimer.restart();
      }
      return;
    }
    root.isReady = true;
  }

  Timer {
    id: exitTimer
    interval: root.minimumVisible
    onTriggered: root.isReady = true
  }

  // The wallpaper has finished decoding and rendering.
  Process {
    id: readyChecker
    command: ["test", "-f", Quickshell.env("VP_WALLPAPER_READY_FILE") || "/tmp/virtual_paradise_wallpaper_ready"]
    onExited: exitCode => {
      if (exitCode === 0) {
        root.readyNow();
      }
    }
  }

  // The shell answers: the desktop is there, the overlay can step aside.
  Process {
    id: shellChecker
    command: ["omarchy-shell", "shell", "ping"]
    onExited: exitCode => {
      if (exitCode === 0) {
        root.readyNow();
      }
    }
  }

  // Poll every 120ms while waiting. The curtain holds for its minimumVisible
  // floor anyway, so this cadence is invisible; it just spawns far fewer
  // processes than the old 30ms loop.
  Timer {
    interval: 120
    repeat: true
    running: !root.isReady && !root.exiting
    onTriggered: {
      if (root.waitForShell) {
        if (!shellChecker.running) {
          shellChecker.running = true;
        }
      } else if (!readyChecker.running) {
        readyChecker.running = true;
      }
    }
  }

  Timer {
    interval: 350
    repeat: true
    running: !root.isReady && !root.exiting
    onTriggered: root.loadingPhase = (root.loadingPhase + 1) % 4
  }

  // Safety fallback timeout: maximum 4.5s so glitch screen NEVER gets stuck
  Timer {
    interval: root.timeout
    running: true
    onTriggered: {
      root.isReady = true;
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
            exitAnim.start()
          }
        }
      }

      Item {
        id: glitchRoot
        anchors.fill: parent
        opacity: 1.0

        // Base full glitch image
        Image {
          id: baseImg
          anchors.fill: parent
          source: Qt.resolvedUrl(root.baseImage)
          fillMode: Image.PreserveAspectCrop
          asynchronous: false
          cache: true
        }

        // RGB Split - Cyan Left Shift
        Image {
          id: cyanShift
          anchors.fill: parent
          source: Qt.resolvedUrl(root.baseImage)
          fillMode: Image.PreserveAspectCrop
          x: -14
          opacity: 0.35
        }
        Rectangle {
          anchors.fill: parent
          color: "#00ffdd"
          opacity: root.sessionStyle ? 0.06 : 0.15
        }

        // RGB Split - Magenta Right Shift
        Image {
          id: magentaShift
          anchors.fill: parent
          source: Qt.resolvedUrl(root.baseImage)
          fillMode: Image.PreserveAspectCrop
          x: 14
          opacity: 0.35
        }
        Rectangle {
          anchors.fill: parent
          color: "#ff2bd6"
          opacity: root.sessionStyle ? 0.06 : 0.15
        }

        // -------------------------------------------------------------
        // HEAVY HORIZONTAL SLICES (5 distinct asymmetric bands)
        // -------------------------------------------------------------
        // Slice 1 (Top edge)
        Item {
          id: slice1
          width: win.width; height: win.height * 0.14; y: win.height * 0.04; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice1.x; y: -slice1.y; source: Qt.resolvedUrl(root.baseImage); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#00ffdd"; opacity: 0.8 }
        }

        // Slice 2 (Upper middle)
        Item {
          id: slice2
          width: win.width; height: win.height * 0.22; y: win.height * 0.20; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice2.x; y: -slice2.y; source: Qt.resolvedUrl(root.baseImage); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 3; color: "#ff2bd6"; opacity: 0.9 }
        }

        // Slice 3 (Center)
        Item {
          id: slice3
          width: win.width; height: win.height * 0.16; y: win.height * 0.44; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice3.x; y: -slice3.y; source: Qt.resolvedUrl(root.baseImage); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.top: parent.top; width: parent.width; height: 2; color: "#00ffdd"; opacity: 0.8 }
        }

        // Slice 4 (Lower middle)
        Item {
          id: slice4
          width: win.width; height: win.height * 0.18; y: win.height * 0.62; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice4.x; y: -slice4.y; source: Qt.resolvedUrl(root.baseImage); fillMode: Image.PreserveAspectCrop }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#ff9ecb"; opacity: 0.9 }
        }

        // Slice 5 (Bottom)
        Item {
          id: slice5
          width: win.width; height: win.height * 0.15; y: win.height * 0.82; clip: true; x: 0
          Image { width: win.width; height: win.height; x: -slice5.x; y: -slice5.y; source: Qt.resolvedUrl(root.baseImage); fillMode: Image.PreserveAspectCrop }
        }

        // -------------------------------------------------------------
        // SESSION SPLASH: SOLID SIGNAL BLOCKS
        // Three square blocks — black, cyan, violet — nested inside each
        // other. Each hop re-rolls which corner the child sits in, how much it
        // covers, whether it is tilted, and the neon edge colour, so every
        // cluster reads like a different signal artefact. Three of them roam
        // the screen continuously instead of one fixed cascade.
        // -------------------------------------------------------------
        Item {
          id: signalBlocks
          anchors.fill: parent
          visible: root.sessionStyle

          Rectangle {
            id: trioA
            width: win.width * 0.16; height: width
            color: "#05070a"; opacity: 0
            border.width: 1; border.color: "#00ffdd"
            x: win.width * 0.12; y: win.height * 0.14

            Rectangle {
              id: trioACyan
              width: parent.width * 0.58; height: width
              color: "#00ffdd"
              x: 0; y: 0
              Rectangle {
                id: trioAPurple
                width: parent.width * 0.58; height: width
                color: "#7a2bff"
                x: 0; y: 0
              }
            }
          }

          Rectangle {
            id: trioB
            width: win.width * 0.11; height: width
            color: "#05070a"; opacity: 0
            border.width: 1; border.color: "#7a2bff"
            x: win.width * 0.72; y: win.height * 0.62

            Rectangle {
              id: trioBCyan
              width: parent.width * 0.58; height: width
              color: "#00ffdd"
              x: 0; y: 0
              Rectangle {
                id: trioBPurple
                width: parent.width * 0.58; height: width
                color: "#7a2bff"
                x: 0; y: 0
              }
            }
          }

          Rectangle {
            id: trioC
            width: win.width * 0.075; height: width
            color: "#05070a"; opacity: 0
            border.width: 1; border.color: "#00ffdd"
            x: win.width * 0.40; y: win.height * 0.78

            Rectangle {
              id: trioCCyan
              width: parent.width * 0.58; height: width
              color: "#00ffdd"
              x: 0; y: 0
              Rectangle {
                id: trioCPurple
                width: parent.width * 0.58; height: width
                color: "#7a2bff"
                x: 0; y: 0
              }
            }
          }
        }

        // Horizontal cuts clean across the whole screen, so the frame reads as
        // violently torn rather than simply slid into a corner.
        Rectangle { id: tearGap1; width: parent.width; height: 16; color: "#05070a"; opacity: 0; y: win.height * 0.32 }
        Rectangle { id: tearGap2; width: parent.width; height: 34; color: "#0f081d"; opacity: 0; y: win.height * 0.61 }
        Rectangle { id: tearGap3; width: parent.width; height: 8; color: "#00ffdd"; opacity: 0; y: win.height * 0.47 }
        Rectangle { id: tearGap4; width: parent.width; height: 10; color: "#7a2bff"; opacity: 0; y: win.height * 0.72 }

        // -------------------------------------------------------------
        // TV STATIC: the picture keeps crawling, the lines roll and the
        // whole frame jumps around.
        // -------------------------------------------------------------
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
          width: parent.width; height: 10; y: win.height * 0.25; color: "#00ffdd"; opacity: 0
        }
        Rectangle {
          id: pinkBar1
          width: parent.width; height: 14; y: win.height * 0.55; color: "#ff9ecb"; opacity: 0
        }
        Rectangle {
          id: yellowBar1
          width: parent.width; height: 8; y: win.height * 0.78; color: "#ffee00"; opacity: 0
        }
        Rectangle {
          id: purpleBar1
          width: parent.width; height: 12; y: win.height * 0.66; color: "#7a2bff"; opacity: 0
        }
        // Thin digital scan lines for the modern cyber look.
        Rectangle {
          id: neonLine1
          height: 2; y: win.height * 0.4; width: parent.width
          color: "#00ffdd"; opacity: 0
        }
        Rectangle {
          id: neonLine2
          height: 1; y: win.height * 0.72; width: parent.width
          color: "#7a2bff"; opacity: 0
        }
        // Small data fragments: the little bits of signal that survive a tear.
        Rectangle { id: frag1; width: 48; height: 3; color: "#00ffdd"; opacity: 0 }
        Rectangle { id: frag2; width: 24; height: 2; color: "#ff2bd6"; opacity: 0 }
        Rectangle { id: frag3; width: 64; height: 4; color: "#7a2bff"; opacity: 0 }
        Rectangle { id: frag4; width: 16; height: 2; color: "#eafbfa"; opacity: 0 }
      }

      // The static sits on top of the picture, so it can outlive it: the
      // picture fades away and the desktop shows through the noise.
      Image {
        id: noiseLayer
        anchors.fill: parent
        source: Qt.resolvedUrl("noise.jpg")
        fillMode: Image.PreserveAspectCrop
        // The static breaks the picture up, it does not replace it: the
        // picture has to stay readable through the noise.
        opacity: root.noiseLevel * 0.30
        visible: root.noiseLevel > 0
        cache: true
      }

      Image {
        id: scanLayer
        anchors.fill: parent
        source: Qt.resolvedUrl("scanlines.png")
        fillMode: Image.Stretch
        opacity: 0.30
        visible: root.noiseLevel > 0
        cache: true
      }

      // Fullscreen white strobe
      Rectangle {
        id: whiteStrobe
        anchors.fill: parent
        color: "white"
        opacity: 0
      }

      // -------------------------------------------------------------
      // PHASE 1: VIOLENT SIGNAL CRASH (0ms -> ~200ms)
      // -------------------------------------------------------------
      SequentialAnimation {
        id: entryAnim
        running: true

        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: root.sessionStyle ? -240 : -140; duration: 30 }
          NumberAnimation { target: slice2; property: "x"; to: root.sessionStyle ? 300 : 180; duration: 30 }
          NumberAnimation { target: slice3; property: "x"; to: root.sessionStyle ? -320 : -190; duration: 30 }
          NumberAnimation { target: slice4; property: "x"; to: root.sessionStyle ? 220 : 130; duration: 30 }
          NumberAnimation { target: slice5; property: "x"; to: root.sessionStyle ? -190 : -110; duration: 30 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0.9; duration: 30 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0.9; duration: 30 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0.9; duration: 30 }
          NumberAnimation { target: trioA; property: "opacity"; to: root.sessionStyle ? 0.9 : 0; duration: 30 }
          NumberAnimation { target: trioB; property: "opacity"; to: root.sessionStyle ? 0.85 : 0; duration: 30 }
          NumberAnimation { target: trioC; property: "opacity"; to: root.sessionStyle ? 0.8 : 0; duration: 30 }
          NumberAnimation { target: tearGap1; property: "opacity"; to: root.sessionStyle ? 0.9 : 0; duration: 30 }
          NumberAnimation { target: tearGap2; property: "opacity"; to: root.sessionStyle ? 0.85 : 0; duration: 30 }
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
            root.jitter = true
            if (root.isReady) {
              win.hasStartedExit = true
              root.jitter = false
              exitAnim.start()
            } else {
              loadingLoopAnim.start()
            }
          }
        }
      }

      // -------------------------------------------------------------
      // PHASE 2: THE SIGNAL BREAKS UP (Active until the picture is ready)
      // -------------------------------------------------------------
      // Every tick the slices jump to a new random offset, the picture crawls
      // and the colour split wanders. That is what a broken TV looks like.
      Timer {
        interval: 40
        repeat: true
        running: root.jitter && !root.finished
        onTriggered: {
          root.tick = (root.tick + 1) % 997;

          const jump = 34 * root.noiseLevel + 6;
          const hx = root.sessionStyle ? 1.15 : 1.0;
          const vy = root.sessionStyle ? 2.2 : 1.0;

          slice1.x = (Math.random() * jump * 2 - jump) * hx;
          slice1.y = (Math.random() * jump * 0.5 - jump * 0.25) * vy;
          slice2.x = (Math.random() * jump * 2.4 - jump * 1.2) * hx;
          slice2.y = (Math.random() * jump * 0.4 - jump * 0.2) * vy;
          slice3.x = (Math.random() * jump * 2.8 - jump * 1.4) * hx;
          slice3.y = (Math.random() * jump * 0.6 - jump * 0.3) * vy;
          slice4.x = (Math.random() * jump * 2.2 - jump * 1.1) * hx;
          slice4.y = (Math.random() * jump * 0.5 - jump * 0.25) * vy;
          slice5.x = (Math.random() * jump * 2.6 - jump * 1.3) * hx;
          slice5.y = (Math.random() * jump * 0.4 - jump * 0.2) * vy;

          cyanShift.x = -6 - Math.random() * 26 * root.noiseLevel * root.shiftScale;
          magentaShift.x = 6 + Math.random() * 26 * root.noiseLevel * root.shiftScale;

          noiseLayer.x = Math.random() * 60 - 30;
          noiseLayer.y = Math.random() * 60 - 30;
          scanLayer.y = (root.tick % 4) * 1.5 - 3;

          blackBlock1.opacity = Math.random() < 0.18 * root.noiseLevel + 0.05 ? 0.85 * root.remnant : 0;
          blackBlock2.opacity = Math.random() < 0.15 * root.noiseLevel + 0.05 ? 0.85 * root.remnant : 0;
          blackBlock1.x = Math.random() * win.width * 0.3;
          blackBlock2.x = Math.random() * win.width * 0.4;
          blackBlock1.y = Math.random() * win.height * 0.8;
          blackBlock2.y = Math.random() * win.height * 0.85;

          cyanBar1.opacity = Math.random() < 0.25 * root.noiseLevel + 0.05 ? 0.9 * root.remnant : 0;
          pinkBar1.opacity = Math.random() < 0.25 * root.noiseLevel + 0.05 ? 0.9 * root.remnant : 0;
          yellowBar1.opacity = Math.random() < 0.2 * root.noiseLevel + 0.05 ? 0.85 * root.remnant : 0;
          cyanBar1.y = Math.random() * win.height * 0.9;
          pinkBar1.y = Math.random() * win.height * 0.9;
          yellowBar1.y = Math.random() * win.height * 0.9;

          if (root.sessionStyle) {
            // Three nested block trios roam the screen continuously. Every hop
            // re-rolls the nesting: which corner each child square sits in, how
            // much it covers, whether it is tilted, and the neon edge colour.
            // That variation is what makes the blocks read as real signal noise
            // instead of the same cascade every time.
            const pulse = root.remnant;
            function nest(outer, cyan, purple, size) {
              outer.width = size; outer.height = size;
              cyan.width = size * (0.38 + Math.random() * 0.34);
              cyan.height = cyan.width;
              cyan.x = Math.random() < 0.5 ? 0 : outer.width - cyan.width;
              cyan.y = Math.random() < 0.5 ? 0 : outer.height - cyan.height;
              cyan.rotation = Math.random() < 0.30 ? 45 : 0;
              purple.width = cyan.width * (0.38 + Math.random() * 0.34);
              purple.height = purple.width;
              purple.x = Math.random() < 0.5 ? 0 : cyan.width - purple.width;
              purple.y = Math.random() < 0.5 ? 0 : cyan.height - purple.height;
              purple.rotation = Math.random() < 0.30 ? 45 : 0;
              outer.border.color = Math.random() < 0.5 ? "#00ffdd" : "#7a2bff";
            }

            trioA.opacity = Math.random() < 0.78 ? (0.62 + Math.random() * 0.20) * pulse : 0;
            trioB.opacity = Math.random() < 0.68 ? (0.58 + Math.random() * 0.22) * pulse : 0;
            trioC.opacity = Math.random() < 0.58 ? (0.55 + Math.random() * 0.22) * pulse : 0;

            if ((root.tick % 3) === 0) {
              trioA.x = Math.random() * (win.width - trioA.width);
              trioA.y = Math.random() * (win.height - trioA.height);
              nest(trioA, trioACyan, trioAPurple, win.width * (0.12 + Math.random() * 0.08));
            }
            if ((root.tick % 4) === 0) {
              trioB.x = Math.random() * (win.width - trioB.width);
              trioB.y = Math.random() * (win.height - trioB.height);
              nest(trioB, trioBCyan, trioBPurple, win.width * (0.08 + Math.random() * 0.06));
            }
            if ((root.tick % 5) === 0) {
              trioC.x = Math.random() * (win.width - trioC.width);
              trioC.y = Math.random() * (win.height - trioC.height);
              nest(trioC, trioCCyan, trioCPurple, win.width * (0.05 + Math.random() * 0.05));
            }

            // Full-width cuts: heavy horizontal tearing.
            tearGap1.opacity = (0.70 + Math.random() * 0.30) * pulse;
            tearGap2.opacity = (0.65 + Math.random() * 0.35) * pulse;
            tearGap3.opacity = Math.random() < 0.65 ? 0.90 * pulse : 0;
            tearGap4.opacity = Math.random() < 0.55 ? 0.85 * pulse : 0;
            tearGap1.y = win.height * (0.14 + Math.random() * 0.50);
            tearGap2.y = win.height * (0.20 + Math.random() * 0.55);
            tearGap3.y = win.height * (0.16 + Math.random() * 0.60);
            tearGap4.y = win.height * (0.22 + Math.random() * 0.55);

            // Thin neon scan lines: modern digital noise rather than a TV wash.
            neonLine1.opacity = Math.random() < 0.55 ? (0.55 + Math.random() * 0.35) * pulse : 0;
            neonLine2.opacity = Math.random() < 0.40 ? (0.45 + Math.random() * 0.35) * pulse : 0;
            neonLine1.y = Math.random() * win.height;
            neonLine2.y = Math.random() * win.height;
            neonLine1.width = win.width * (0.20 + Math.random() * 0.80);

            // Scattered fragments keep the signal feeling digital and modern.
            const frags = [frag1, frag2, frag3, frag4];
            for (let f = 0; f < frags.length; f++) {
              const fr = frags[f];
              fr.opacity = Math.random() < 0.45 ? (0.55 + Math.random() * 0.40) * pulse : 0;
              fr.x = Math.random() * win.width;
              fr.y = Math.random() * win.height;
            }

            purpleBar1.opacity = Math.random() < 0.35 ? 0.85 * pulse : 0;
            purpleBar1.y = Math.random() * win.height * 0.9;
          }
        }
      }

      SequentialAnimation {
        id: loadingLoopAnim
        loops: Animation.Infinite

        PauseAnimation { duration: 180 }

        // Cyber slice jitter pulse
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: root.sessionStyle ? 64 : 90; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: root.sessionStyle ? -56 : -70; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "opacity"; to: 0.7; duration: 25 }
          NumberAnimation { target: cyanBar1; property: "y"; to: win.height * 0.36; duration: 25 }
          NumberAnimation { target: blackBlock1; property: "opacity"; to: 0.75; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice2; property: "x"; to: root.sessionStyle ? -34 : -40; duration: 25 }
          NumberAnimation { target: slice4; property: "x"; to: root.sessionStyle ? 30 : 35; duration: 25 }
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
          NumberAnimation { target: slice1; property: "x"; to: root.sessionStyle ? -58 : -80; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: root.sessionStyle ? 76 : 100; duration: 25 }
          NumberAnimation { target: pinkBar1; property: "opacity"; to: 0.75; duration: 25 }
          NumberAnimation { target: pinkBar1; property: "y"; to: win.height * 0.58; duration: 25 }
          NumberAnimation { target: blackBlock2; property: "opacity"; to: 0.8; duration: 25 }
        }
        ParallelAnimation {
          NumberAnimation { target: slice1; property: "x"; to: root.sessionStyle ? 44 : 40; duration: 25 }
          NumberAnimation { target: slice3; property: "x"; to: root.sessionStyle ? -44 : -50; duration: 25 }
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
          NumberAnimation { target: trioA; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: trioB; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: trioC; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: tearGap1; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: tearGap2; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: tearGap3; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: tearGap4; property: "opacity"; to: 0; duration: 30 }
          NumberAnimation { target: purpleBar1; property: "opacity"; to: 0; duration: 30 }
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
            // The picture and the static end here, at once, the way they
            // always did. Only the glitch itself lingers.
            glitchRoot.visible = false;
            noiseLayer.visible = false;
            root.jitter = true
            afterglow.start()
          }
        }
      }

      // -------------------------------------------------------------
      // PHASE 4: THE LAST OF THE STATIC, FADING AWAY
      // -------------------------------------------------------------
      // The desktop is already visible behind the overlay. The noise and the
      // jitter calm down over a couple of seconds and then the overlay is gone.
      SequentialAnimation {
        id: afterglow
        // The last of the glitch: the tearing, the dropout bands and the
        // colour bars keep breaking up over the desktop for a moment.
        NumberAnimation {
          target: root
          property: "remnant"
          from: 1.0
          to: 0.0
          duration: 1400
          easing.type: Easing.OutQuad
        }
        ScriptAction {
          script: {
            root.finished = true
            Qt.quit()
          }
        }
      }
    }
  }

}
