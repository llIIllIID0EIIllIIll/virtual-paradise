import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter Password 󰍉"
  readonly property int fieldWidth: 390
  readonly property int fieldHeight: 58
  readonly property int outlineThickness: 2
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.05)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  property string currentQuote: "“Loading system wisdom…”"

  // Linux Fortune Process: Fetch short quotes/jokes/sayings directly from Linux fortune
  Process {
    id: fortuneProc
    command: ["fortune", "-s"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim().replace(/\t+/g, " — ").replace(/\r?\n|\r/g, " ").replace(/\s+/g, " ")
        if (raw.length > 0) {
          root.currentQuote = "“" + raw + "”"
        }
      }
    }
  }

  function fetchFortune() {
    fortuneProc.running = false
    fortuneProc.running = true
  }

  // Auto-refresh quote every 10 seconds
  Timer {
    id: quoteRefreshTimer
    interval: 10000
    running: root.loadBackground
    repeat: true
    onTriggered: root.fetchFortune()
  }

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
    root.fetchFortune()
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: "#07080d"

    // 100% Unblurred, Sharp, Vivid 1080p Animated GIF (Sleeping Miku)
    AnimatedImage {
      id: wallpaperGif
      anchors.fill: parent
      source: "file:///home/doe/.config/omarchy/plugins/doe.lock/Sleeping_miku.gif"
      fillMode: Image.PreserveAspectCrop
      asynchronous: false
      cache: true
      playing: true
      visible: true
    }

    // High clarity subtle dark tint so Sleeping Miku is crystal clear and vivid
    Rectangle {
      anchors.fill: parent
      color: "#2b07080d"
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // =========================================================================
    // TOP SECTION (Above Miku): Neon Clock, Live Date & Fortune Quote
    // =========================================================================
    Column {
      id: topHeader
      anchors.top: parent.top
      anchors.topMargin: 48
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 8

      Text {
        id: timeDisplay
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(new Date(), "hh:mm")
        color: "#00f5d4"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 2.4)
        font.bold: true

        Timer {
          interval: 1000
          running: true
          repeat: true
          onTriggered: timeDisplay.text = Qt.formatDateTime(new Date(), "hh:mm")
        }
      }

      Text {
        id: dateDisplay
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy")
        color: "#ffb7d5"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.base * 1.15)
        font.bold: true
      }

      Text {
        id: quoteDisplay
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentQuote
        color: "#eafbfa"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.base * 0.95)
        font.italic: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        width: Math.min(740, parent.parent.width - 40)
      }
    }

    // =========================================================================
    // BOTTOM SECTION: Password Input Box
    // =========================================================================
    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 72
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#d9131920"
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
          anchors.fill: parent
          anchors.topMargin: inputField.borderTop
          anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
          anchors.bottomMargin: inputField.borderBottom
          anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
          verticalAlignment: TextInput.AlignVCenter
          horizontalAlignment: TextInput.AlignHCenter
          activeFocusOnPress: true
          clip: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: TextInput.Password
          passwordCharacter: "\u25CF"
          passwordMaskDelay: 0
          color: "#00ff88"
          selectionColor: Color.lock.selection
          selectedTextColor: "#eafbfa"
          font.family: Style.font.family
          font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
          font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
          cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
          cursorDelegate: Rectangle {
            width: 2
            color: "#00f5d4"
            visible: passwordInput.cursorVisible
          }

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) {
              root.wakeRequested()
            }
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.fill: passwordInput
          text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
          visible: passwordInput.text.length === 0
          color: root.authenticatingPassword ? "#00f5d4" : (root.failureMessage.length > 0 ? Color.lock.textError : "#7091a4")
          font.family: Style.font.family
          font.pixelSize: root.fieldFontSize
          font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        Text {
          id: fingerprintIcon
          objectName: "fingerprintIndicator"
          anchors.right: parent.right
          anchors.rightMargin: inputField.borderRight + 18
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: "󰈷"
          color: "#00f5d4"
          font.family: Style.font.family
          font.pixelSize: Math.round(root.fieldFontSize * 1.1)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }
