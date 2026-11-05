import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// One dropdown for the specialized plugins and voice dictation. The plugin
// widgets stay in the bar layout but hidden (`"hidden": true`), so their
// panels can still open from the bar; this menu is the visible entry point.
Panel {
  id: root

  moduleName: "__USER__.tools"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var tools: [
    { id: "io.github.randazraik.xray", label: "X-Ray", icon: "󰗇", hint: "Screen lens" },
    { id: "io.github.grichard99.omaproton-vpn", label: "OmaProton VPN", icon: "󰦝", hint: "VPN" },
    { id: "io.github.kristoferlund.webcam", label: "Webcam controls", icon: "󰄀", hint: "Camera" },
    { id: "crmne.hyprmoncfg", label: "Displays", icon: "󰍹", hint: "Monitor config" },
    { id: "io.github.jeffcortez23.omarchy-projector-cast", label: "Projector & Cast", icon: "󰐧", hint: "Screen mirroring" },
    { id: "ssupt.bluetooth-audio", label: "Bluetooth audio", icon: "󰂯", hint: "Devices" }
  ]

  function activate(tool) {
    if (root.bar) root.bar.run("omarchy-shell shell toggle " + tool.id)
    root.close()
  }

  function activateDictation() {
    if (root.bar) root.bar.run("omarchy-dictation toggle")
    root.close()
  }

  KeyboardPanel {
    id: panel

    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: Style.space(330)
    contentHeight: panel.fittedContentHeight(toolsColumn.implicitHeight)

    Column {
      id: toolsColumn

      width: parent.width
      spacing: Style.space(4)

      Text {
        text: "TOOLS"
        color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.35)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
        height: Style.space(18)
      }

      // Voice dictation first: it is the everyday action, and Omarchy's
      // backend-aware toggle already handles the voxtype daemon.
      Rectangle {
        width: parent.width
        height: Math.max(Style.space(38), dictationRow.implicitHeight + Style.space(4))
        radius: Style.cornerRadius
        color: dictationHover.hovered ? Qt.rgba(0, 1, 0.867, 0.12) : "transparent"

        Row {
          id: dictationRow

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Text {
            text: "󰔊"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.iconLarge
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
              text: "Voice dictation"
              color: root.bar ? root.bar.barForeground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              text: "ALT + SPACE"
              color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        HoverHandler { id: dictationHover }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activateDictation()
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: root.bar ? root.bar.barForeground : Color.foreground
        opacity: 0.08
      }

      Repeater {
        model: root.tools

        delegate: Rectangle {
          required property var modelData

          width: parent.width
          height: Math.max(Style.space(38), toolRow.implicitHeight + Style.space(4))
          radius: Style.cornerRadius
          color: toolHover.hovered ? Qt.rgba(0, 1, 0.867, 0.10) : "transparent"

          Row {
            id: toolRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Text {
              text: modelData.icon
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.iconLarge
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              Text {
                text: modelData.label
                color: root.bar ? root.bar.barForeground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }

              Text {
                text: modelData.hint
                color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          HoverHandler { id: toolHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(modelData)
          }
        }
      }
    }
  }
}