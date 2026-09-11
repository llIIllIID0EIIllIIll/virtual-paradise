import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "__USER__.weather"

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

  function editLocation() {
    if (!panelLoader.item) return
    panelLoader.item.openFromHotkey()
    panelLoader.item.startEditingLocation()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property string weatherIcon: (panelLoader.item && panelLoader.item.label !== "") ? panelLoader.item.label : "󰖙"
  readonly property string weatherTemp: (panelLoader.item && panelLoader.item.reportTempNum !== "") ? (panelLoader.item.reportTempNum + panelLoader.item.tempUnit) : "27°C"
  readonly property string weatherLoc: (panelLoader.item && panelLoader.item.reportLocation !== "") ? panelLoader.item.reportLocation : "Local Weather"

  visible: true
  implicitWidth: root.vertical ? button.implicitWidth
    : (weatherPill.width + 6 + (button.tooltipHovered ? 4 : 0))
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

  // A panel is loaded for each bar surface. Keeping its IpcHandler inside the
  // panel therefore registers the same target repeatedly during reloads and
  // can leave the popout coordinator pointing at a destroyed instance. Match
  // the clock widget: the bar host owns the IPC route and relays refreshes to
  // every monitor, while each loaded panel only owns its presentation.
  IpcHandler {
    target: "__USER__.weather"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function edit(): void { root.editLocation() }
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
      color: root.opened
        ? Qt.rgba(1.0, 0.88, 0.40, 0.28)
        : (button.tooltipHovered ? Qt.rgba(1.0, 0.88, 0.40, 0.16) : Qt.rgba(1.0, 0.88, 0.40, 0.09))
      border.color: root.opened ? "#ffe066" : (button.tooltipHovered ? "#ffe066" : Qt.rgba(1.0, 0.88, 0.40, 0.38))
      border.width: root.opened ? 2 : 1
      scale: button.tooltipHovered ? 1.04 : 1

      Behavior on color { ColorAnimation { duration: 180 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }
      Behavior on border.width { NumberAnimation { duration: 150 } }
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

      // Outer Halo Glow Ring when Weather Popup is Opened
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: weatherPill.radius + 3
        color: "transparent"
        border.color: "#ffe066"
        border.width: 1.8
        opacity: 0.85
        visible: root.opened || button.tooltipHovered

        SequentialAnimation on opacity {
          running: root.opened
          loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.95; duration: 800; easing.type: Easing.InOutQuad }
        }
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: weatherPill.radius + 6
        color: "transparent"
        border.color: "#ffe066"
        border.width: 1.5
        opacity: 0.60
        visible: root.opened || button.tooltipHovered

        SequentialAnimation on opacity {
          running: root.opened || button.tooltipHovered
          loops: Animation.Infinite
          NumberAnimation { to: 0.20; duration: 800; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.75; duration: 800; easing.type: Easing.InOutQuad }
        }
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
