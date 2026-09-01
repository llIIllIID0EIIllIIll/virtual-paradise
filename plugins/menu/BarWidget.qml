import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "__USER__.menu"

  implicitWidth: 32
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 2
    verticalPadding: 2
    tooltipText: "Omarchy Menu (Super)\nLeft: Application Menu | Right: Terminal"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }

    // Sleek floating glowing logo without clunky box
    Item {
      anchors.centerIn: parent
      width: 24
      height: 24

      Text {
        anchors.centerIn: parent
        text: "\ue900"
        font.family: "omarchy"
        font.pixelSize: Style.font.iconLarge + (button.tooltipHovered ? 2 : 0)
        color: button.tooltipHovered ? "#00ff88" : "#00f5d4"
        scale: button.tooltipHovered ? 1.15 : 1.0

        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on font.pixelSize { NumberAnimation { duration: 160 } }
      }
    }
  }
}
