// Virtual☆Paradise SDDM theme. Installed into its own theme directory by
// lib/sddm.sh; the distro's omarchy theme is never patched in place.
//
// The login screen is the Plymouth splash, continued: the same cyber
// backdrop, the same centred animation and the same neon frame. What the
// boot animation shows is what the greeter shows, so the handover from
// Plymouth into the login screen does not break the picture.
import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#050310"

  // Fade the whole screen in when the greeter comes up, and out again when
  // the login succeeds: the desktop then appears out of the same picture.
  opacity: 0
  Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

  // Cyber backdrop: the same artwork the Plymouth splash uses.
  Image {
    id: backdrop
    anchors.fill: parent
    source: "backdrop.png"
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.25
  }

  // The picture, centred and scaled to the screen, exactly like Plymouth
  // draws it: the same cyber backdrop, the same still of the animation and
  // the same neon frame. The greeter is the boot splash, continued.
  Item {
    id: stage
    width: Math.min(1600, root.width - 80)
    height: width * 9 / 16
    anchors.centerIn: parent

    // A very slow drift so the picture is never completely still.
    SequentialAnimation {
      running: true
      loops: Animation.Infinite
      NumberAnimation { target: stage; property: "scale"; from: 1.0; to: 1.012; duration: 14000; easing.type: Easing.InOutSine }
      NumberAnimation { target: stage; property: "scale"; from: 1.012; to: 1.0; duration: 14000; easing.type: Easing.InOutSine }
    }

    Image {
      id: backgroundGif
      anchors.fill: parent
      source: "still.png"
      fillMode: Image.Stretch
      asynchronous: true
      cache: true
    }

    // Neon frame around the picture, drawn like Plymouth draws it.
    Image {
      anchors.fill: parent
      source: "frame.png"
      fillMode: Image.Stretch
      asynchronous: true
      cache: true
    }
  }

  property string currentUser: userModel.lastUser
  property bool loginFailed: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
      // Hand over to the session by fading the picture out.
      fadeOut.start()
    }
  }

  SequentialAnimation {
    id: fadeOut
    NumberAnimation {
      target: root
      property: "opacity"
      from: 1.0
      to: 0.0
      duration: 450
      easing.type: Easing.InCubic
    }
  }

  // ── Password entry ────────────────────────────────────────────────────────
  // A wide neon panel instead of the stock line: the entry is the one thing
  // the user has to look at, so it gets the accent colour, a glow and a
  // label.
  Column {
    id: prompt
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.max(60, parent.height * 0.07)
    spacing: 18

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.currentUser
      color: "#eafbfa"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: Math.max(22, Math.round(root.width * 0.026))
      font.bold: true
      font.letterSpacing: 3
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "ENTER PASSWORD"
      color: "#ff007f"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 13
      font.letterSpacing: 6
      opacity: 0.9
    }

    Rectangle {
      id: box
      width: Math.min(760, root.width - 80)
      height: 92
      radius: 14
      color: "#0a0714"
      opacity: 0.82
      border.width: 2
      border.color: root.loginFailed ? "#ff007f" : "#00ffdd"

      // Soft glow around the panel: a few translucent frames instead of a
      // shader, so the greeter keeps working on a plain Qt Quick install.
      Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 18
        color: "transparent"
        border.width: 2
        border.color: root.loginFailed ? "#ff007f" : "#00ffdd"
        opacity: 0.35
      }
      Rectangle {
        anchors.fill: parent
        anchors.margins: -9
        radius: 22
        color: "transparent"
        border.width: 3
        border.color: root.loginFailed ? "#ff007f" : "#00ffdd"
        opacity: 0.14
      }

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20

        Image {
          source: root.loginFailed ? "lock-failed.png" : "lock.png"
          width: 46
          height: 52
          fillMode: Image.PreserveAspectFit
          anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
          width: 2
          height: 44
          color: root.loginFailed ? "#ff007f" : "#00ffdd"
          opacity: 0.6
          anchors.verticalCenter: parent.verticalCenter
        }

        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 9

          Repeater {
            model: Math.min(password.text.length, 28)

            Rectangle {
              width: 12
              height: 12
              radius: 6
              color: root.loginFailed ? "#ff007f" : "#00ffdd"
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // The caret: a blinking neon bar, because the real cursor of the
      // text input is hidden.
      Rectangle {
        id: caret
        width: 3
        height: 40
        color: "#00ffdd"
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 30 + 46 + 20 + 12 + 20 + 14
        visible: password.text.length === 0 && password.activeFocus
        opacity: 0.9

        SequentialAnimation on opacity {
          running: caret.visible
          loops: Animation.Infinite
          NumberAnimation { from: 0.9; to: 0.0; duration: 550 }
          NumberAnimation { from: 0.0; to: 0.9; duration: 550 }
        }
      }

      TextInput {
        id: password
        anchors.fill: parent
        anchors.leftMargin: 30
        anchors.rightMargin: 30
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 26
        font.letterSpacing: 6
        passwordCharacter: "•"
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        cursorDelegate: Item {}
        focus: true

        onTextChanged: root.loginFailed = false

        Keys.onPressed: {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            sddm.login(root.currentUser, password.text, root.sessionIndex)
            event.accepted = true
          }
        }
      }
    }
  }

  Component.onCompleted: {
    password.forceActiveFocus()
    // Fade the picture in: the greeter is the boot splash continued, and the
    // transition into the session has to look the same way.
    opacity = 1
  }
}
