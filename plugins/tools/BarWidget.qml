import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// One compact button replacing the long row of specialized widgets. The
// dropdown loads each plugin's own bar widget, so the plugin keeps its
// behaviour and its panel; the bar itself stays short.
BarWidget {
  id: root
  moduleName: "__USER__.tools"

  property bool panelWanted: false
  property bool openRequested: false
  property bool settingsRequested: false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function ensurePanel() {
    if (!panelLoader.item) {
      panelWanted = true
      panelLoader.active = true
    }
    return panelLoader.item
  }

  function open() {
    if (!ensurePanel()) {
      openRequested = true
      return
    }
    panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (!ensurePanel()) {
      openRequested = true
      return
    }
    panelLoader.item.toggle()
  }

  function showSettings() {
    if (!ensurePanel()) {
      settingsRequested = true
      openRequested = true
      return
    }
    panelLoader.item.showSettings = true
    panelLoader.item.open()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  implicitWidth: 30
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader

    active: false
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
      if (root.settingsRequested) {
        root.settingsRequested = false
        panelLoader.item.showSettings = true
      }
      if (root.openRequested) {
        root.openRequested = false
        panelLoader.item.open()
      }
    }
  }

  IpcHandler {
    target: "__USER__.tools"

    function toggle(): void { root.togglePanel() }
    function open(): void { root.open() }
    function settings(): void { root.showSettings() }
    function close(): void { root.close() }
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
    Accessible.name: "Tools"
    Accessible.role: Accessible.Button
    Accessible.description: "Open specialized plugins and voice dictation"
    tooltipText: "Tools\nSpecialized plugins and voice dictation"
    onPressed: function(b) { if (root.bar) root.togglePanel() }

    Text {
      anchors.centerIn: parent
      text: "󰇙"
      color: root.opened ? "#00ff88" : (button.tooltipHovered ? "#ffffff" : "#00ffdd")
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.iconLarge
      Behavior on color { ColorAnimation { duration: 120 } }
    }
  }
}