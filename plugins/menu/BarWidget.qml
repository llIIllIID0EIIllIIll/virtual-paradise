import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "__USER__.menu"
  // Palette loaded by the island bar from theme-switcher.sh; fallbacks keep
  // the component usable when it is mounted outside the bar.
  readonly property color accentColor: root.bar && root.bar.accentColor !== undefined ? root.bar.accentColor : Color.accent
  readonly property color greenColor: root.bar && root.bar.greenColor !== undefined ? root.bar.greenColor : "#00ff88"
  readonly property color warmColor: root.bar && root.bar.warmColor !== undefined ? root.bar.warmColor : "#ffe066"
  readonly property color pinkColor: root.bar && root.bar.pinkColor !== undefined ? root.bar.pinkColor : "#ffb7d5"
  readonly property color hotColor: root.bar && root.bar.hotColor !== undefined ? root.bar.hotColor : "#ff0055"

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
    Accessible.name: "Menu"
    Accessible.role: Accessible.Button
    Accessible.description: "Open the application menu"
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
        color: button.tooltipHovered ? root.greenColor : root.accentColor
        scale: button.tooltipHovered ? 1.15 : 1.0

        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on font.pixelSize { NumberAnimation { duration: 160 } }
      }
    }
  }
}
