import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1

  function isVideo(path) {
    if (!path) return false
    var lower = String(path).toLowerCase()
    return lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".mov")
  }

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function setBackground(path, instant) {
    transitionBackground("", path, path, instant, false)
  }

  function transitionBackground(fromPath, path, finalPath, instant, force) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    currentBackground = finalPath
    backgroundVersion += 1
    revealStartedVersion = -1

    revealAnimation.stop()
    finishingTransition = false

    if (instant || !displayedBackground) {
      oldBackground = ""
      incomingBackground = ""
      displayedBackground = path
      revealProgress = 1
      return
    }

    oldBackground = fromPath || displayedBackground
    incomingBackground = path
    revealProgress = 0
  }

  function setPendingTheme(colorsB64, shellB64) {
    pendingColorsRaw = Util.decodeBase64(colorsB64)
    pendingShellRaw = Util.decodeBase64(shellB64)
    pendingThemeVersion = backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    if (pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Color.loadColors(pendingColorsRaw)
    Color.loadShell(pendingShellRaw)
    Style.scheduleRefresh()
    pendingThemeVersion = -1
    pendingColorsRaw = ""
    pendingShellRaw = ""
  }

  function transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    transitionBackground(fromPath, path, finalPath, false, true)
    setPendingTheme(colorsB64, shellB64)
    if (!incomingBackground || revealProgress >= 1) applyPendingTheme()
  }

  function startReveal(panel) {
    if (!incomingBackground) return
    panel.maskReady = true
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    applyPendingTheme()
    revealAnimation.restart()
  }

  function openSelector() {
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  function openThemeSwitcher() {
    if (!themeSwitchProc.running) themeSwitchProc.running = true
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshBackground()
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1 &"]
    onExited: root.refreshBackground()
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.setBackground(String(text || "").trim(), false)
    }
  }

  IpcHandler {
    target: "background"

    function refresh(): void {
      root.refreshBackground()
    }

    function set(path: string): void {
      root.setBackground(path, false)
    }

    function setInstant(path: string): void {
      root.setBackground(path, true)
    }

    function transition(fromPath: string, path: string): void {
      root.transitionBackground(fromPath, path, path, false, false)
    }

    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: 520
    easing.type: Easing.InOutCubic
    onFinished: {
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
      root.revealProgress = 1
    }
  }

  Component.onCompleted: refreshBackground()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: "transparent"
      updatesEnabled: true

      property bool maskReady: false

      function maybeStartReveal() {
        if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
        var isVid = root.isVideo(root.incomingBackground)
        if (isVid) {
          if (!incomingPlayer.hasVideoFrame && incomingPlayer.playbackState !== MediaPlayer.PlayingState) return
        } else {
          if (incomingFrame.status !== Image.Ready) return
        }
        Qt.callLater(function() {
          if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
          root.startReveal(panel)
        })
      }

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // ==========================================
      // BASE LAYER (Current active background)
      // ==========================================
      Item {
        id: baseContainer
        anchors.fill: parent

        Image {
          id: baseImage
          anchors.fill: parent
          visible: !root.isVideo(root.displayedBackground)
          source: visible ? root.imageUrl(root.displayedBackground) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          onStatusChanged: {
            if (status === Image.Ready && root.finishingTransition) {
              root.incomingBackground = ""
              root.oldBackground = ""
              root.finishingTransition = false
            }
          }
        }

        MediaPlayer {
          id: basePlayer
          source: root.isVideo(root.displayedBackground) ? root.imageUrl(root.displayedBackground) : ""
          loops: MediaPlayer.Infinite
          audioOutput: AudioOutput { muted: true }
          videoOutput: baseVideoOutput
          Component.onCompleted: {
            if (root.isVideo(root.displayedBackground)) play()
          }
        }

        VideoOutput {
          id: baseVideoOutput
          anchors.fill: parent
          visible: root.isVideo(root.displayedBackground)
          fillMode: VideoOutput.PreserveAspectCrop
        }
      }

      // ==========================================
      // OLD LAYER (Outgoing background during transition)
      // ==========================================
      Item {
        id: oldLayer
        anchors.fill: parent
        visible: root.oldBackground !== "" && root.revealProgress < 1

        Image {
          id: oldImage
          anchors.fill: parent
          visible: !root.isVideo(root.oldBackground)
          source: visible ? root.imageUrl(root.oldBackground) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          onStatusChanged: panel.maybeStartReveal()
        }

        MediaPlayer {
          id: oldPlayer
          source: (visible && root.isVideo(root.oldBackground)) ? root.imageUrl(root.oldBackground) : ""
          loops: MediaPlayer.Infinite
          audioOutput: AudioOutput { muted: true }
          videoOutput: oldVideoOutput
          Component.onCompleted: {
            if (root.isVideo(root.oldBackground)) play()
          }
        }

        VideoOutput {
          id: oldVideoOutput
          anchors.fill: parent
          visible: root.isVideo(root.oldBackground)
          fillMode: VideoOutput.PreserveAspectCrop
        }
      }

      // ==========================================
      // INCOMING LAYER (New background with Slanted 2-Sided Curtain Reveal Mask)
      // ==========================================
      Item {
        id: incomingLayer
        anchors.fill: parent
        readonly property bool ready: root.isVideo(root.incomingBackground) ? (incomingPlayer.playbackState === MediaPlayer.PlayingState || incomingPlayer.hasVideoFrame) : (incomingFrame.status === Image.Ready)
        visible: root.incomingBackground !== "" && ready && (root.revealProgress >= 1 || panel.maskReady)
        layer.enabled: root.incomingBackground !== "" && root.revealProgress < 1
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: revealMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.02
        }

        Image {
          id: incomingFrame
          anchors.fill: parent
          visible: !root.isVideo(root.incomingBackground)
          source: visible ? root.imageUrl(root.incomingBackground) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          onStatusChanged: panel.maybeStartReveal()
        }

        MediaPlayer {
          id: incomingPlayer
          source: root.isVideo(root.incomingBackground) ? root.imageUrl(root.incomingBackground) : ""
          loops: MediaPlayer.Infinite
          audioOutput: AudioOutput { muted: true }
          videoOutput: incomingVideoOutput
          onPlaybackStateChanged: panel.maybeStartReveal()
          onMediaStatusChanged: {
            if (mediaStatus >= MediaPlayer.LoadedMedia) {
              play()
              panel.maybeStartReveal()
            }
          }
        }

        VideoOutput {
          id: incomingVideoOutput
          anchors.fill: parent
          visible: root.isVideo(root.incomingBackground)
          fillMode: VideoOutput.PreserveAspectCrop
        }
      }

      // ==========================================
      // SLANTED 2-SIDED CURTAIN REVEAL MASK
      // ==========================================
      Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property real slant: -0.18
        readonly property real centerTop: width / 2 - slant * height / 2
        readonly property real centerBottom: width / 2 + slant * height / 2
        readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
        readonly property real spread: reach * root.revealProgress

        Shape {
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: revealMask.centerTop - revealMask.spread; startY: 0
            PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
            PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
          }
        }
      }

      Connections {
        target: root
        function onIncomingBackgroundChanged() {
          panel.maskReady = false
          if (root.isVideo(root.incomingBackground)) {
            incomingPlayer.source = root.imageUrl(root.incomingBackground)
            incomingPlayer.play()
          }
          panel.maybeStartReveal()
        }
        function onDisplayedBackgroundChanged() {
          if (root.isVideo(root.displayedBackground)) {
            basePlayer.source = root.imageUrl(root.displayedBackground)
            basePlayer.play()
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
          else root.openSelector()
          mouse.accepted = true
        }
      }
    }
  }
}
