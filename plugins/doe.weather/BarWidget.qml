import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "doe.weather"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property string weatherIcon: (panelLoader.item && panelLoader.item.label !== "") ? panelLoader.item.label : "󰖙"
  readonly property string weatherTemp: (panelLoader.item && panelLoader.item.reportTempNum !== "") ? (panelLoader.item.reportTempNum + panelLoader.item.tempUnit) : "27°C"
  readonly property string weatherLoc: (panelLoader.item && panelLoader.item.reportLocation !== "") ? panelLoader.item.reportLocation : "Hồ Chí Minh"

  visible: true
  implicitWidth: root.vertical ? button.implicitWidth : (weatherRow.implicitWidth + 24)
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 2
    verticalPadding: 2
    tooltipText: "Weather: " + root.weatherLoc + " (" + root.weatherTemp + ")\nLeft: Weather Details | Right: Notification | Middle: Refresh"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("omarchy-notification-send \"$(omarchy-weather-status)\"")
      else if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    // Glowing Neon Weather Capsule Pill
    Rectangle {
      id: weatherPill
      visible: !root.vertical
      anchors.centerIn: parent
      width: weatherRow.implicitWidth + 20
      height: 28
      radius: 14
      color: Qt.rgba(1.0, 0.88, 0.40, 0.09) // Cyber Yellow frosted tint
      border.color: root.opened ? "#00ff88" : (button.tooltipHovered ? "#ffe066" : Qt.rgba(1.0, 0.88, 0.40, 0.38))
      border.width: 1

      Behavior on border.color {
        ColorAnimation { duration: 180 }
      }

      Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 6

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.weatherIcon
          color: "#ffe066" // Cyber Neon Yellow
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body + 1
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.weatherTemp
          color: "#ffffff" // Pure White
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }
    }
  }
}
