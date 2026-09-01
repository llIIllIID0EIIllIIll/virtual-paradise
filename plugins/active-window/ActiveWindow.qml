import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "__USER__.active-window"

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string title: toplevel ? (toplevel.title || toplevel.appId || "") : ""
  readonly property int maxLabelWidth: Number(setting("maxWidth", 260))
  readonly property bool tooltipHovered: visible && mouseArea.containsMouse

  visible: title !== "" && !vertical
  implicitWidth: visible ? Math.min(maxLabelWidth, labelText.implicitWidth) + 16 : 0
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Item {
    anchors.fill: parent
    clip: true

    Text {
      id: labelText
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 4
      width: parent.width - 8
      text: root.title
      color: mouseArea.containsMouse ? "#ffffff" : "#7091a4"
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body - 1
      font.bold: mouseArea.containsMouse
      elide: Text.ElideRight

      Behavior on color { ColorAnimation { duration: 160 } }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (!root.toplevel) return
      if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
        root.toplevel.close()
      } else {
        root.toplevel.activate()
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, "Active Window: " + root.title + "\nLeft: Focus | Right: Close Window")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
