import QtQuick
import QtQuick.Effects
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

  readonly property string placeholderText: "Enter Password to Unlock 󰍉"
  readonly property int fieldWidth: 390
  readonly property int fieldHeight: 64
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

    // Animated GIF Lockscreen Background (Sleeping Miku 1080p 60fps)
    AnimatedImage {
      id: wallpaperGif
      anchors.fill: parent
      source: {
        if (!root.loadBackground) return ""
        if (root.backgroundPath && root.backgroundPath.toLowerCase().endsWith(".gif")) {
          return root.fileUrl(root.backgroundPath)
        }
        return "file://" + Qt.resolvedUrl("Sleeping_miku.gif")
      }
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      playing: true
      visible: status === Image.Ready
    }

    // Fallback static background if GIF is not ready
    Image {
      id: wallpaperFallback
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      visible: wallpaperGif.status !== Image.Ready
    }

    // Acrylic dark Cyberpunk tint overlay for optimal text/input contrast
    Rectangle {
      anchors.fill: parent
      color: "#5907080d"
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // Top Header: Live Neon Clock & Date + Sleeping Miku Badge
    Column {
      id: headerGroup
      anchors.bottom: inputField.top
      anchors.bottomMargin: 32
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6

      Text {
        id: timeDisplay
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(new Date(), "hh:mm")
        color: "#00f5d4"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 2.2)
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
        text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
        color: "#ffb7d5"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.base * 1.1)
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "🌸 Virtual☆Paradise · Sleeping Miku 💤"
        color: "#7091a4"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.small * 1.05)
      }
    }

    // Password Input Box
    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
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
