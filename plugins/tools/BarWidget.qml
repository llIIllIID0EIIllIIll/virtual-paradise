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
  // Palette loaded by the island bar from theme-switcher.sh; fallbacks keep
  // the component usable when it is mounted outside the bar.
  readonly property color accentColor: root.bar && root.bar.accentColor !== undefined ? root.bar.accentColor : Color.accent
  readonly property color greenColor: root.bar && root.bar.greenColor !== undefined ? root.bar.greenColor : "#00ff88"
  readonly property color warmColor: root.bar && root.bar.warmColor !== undefined ? root.bar.warmColor : "#ffe066"
  readonly property color pinkColor: root.bar && root.bar.pinkColor !== undefined ? root.bar.pinkColor : "#ffb7d5"
  readonly property color hotColor: root.bar && root.bar.hotColor !== undefined ? root.bar.hotColor : "#ff0055"

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

  // Scriptable counterparts for the panel controls. `setBar` writes one
  // bar-level boolean; `verify` opens settings and starts the pin check.
  function setBar(key, value) {
    // Prefer the panel path (the same one the visible toggles use) so the IPC
    // exercises exactly what a click does; fall back when the panel is closed.
    if (panelLoader.item) {
      panelLoader.item.setBarOption(key, value)
      return
    }
    if (root.bar) root.bar.run(Quickshell.env("HOME") + "/.local/bin/vp-setting.sh set bar." + key + " " + (value ? "true" : "false"))
  }

  function verify() {
    root.showSettings()
    if (panelLoader.item) panelLoader.item.verifyPins()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // A plain bar click always lands on Tools; only the gear or the IPC call
  // asks for settings. Resetting on close keeps the next click predictable.
  onOpenedChanged: {
    if (!opened && panelLoader.item) panelLoader.item.showSettings = false
  }

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
    function setBar(key: string, value: bool): void { root.setBar(key, value) }
    function applyTheme(): void { if (panelLoader.item) panelLoader.item.applyCustomTheme() }
    function undoTheme(): void { if (panelLoader.item) panelLoader.item.undoPalette() }
    function redoTheme(): void { if (panelLoader.item) panelLoader.item.redoPalette() }
    function resetTheme(): void { if (panelLoader.item) panelLoader.item.resetPalette() }
    function setRole(role: string, hex: string): void { if (panelLoader.item) panelLoader.item.setRoleFromIpc(role, hex) }
    function generateTheme(mode: string): void {
      if (!panelLoader.item) return
      if (mode === "analogous" || mode === "complement" || mode === "triad")
        panelLoader.item.generateHarmony(mode)
    }
    function deriveNeutrals(): void { if (panelLoader.item) panelLoader.item.deriveNeutrals() }
    function fromWallpaper(): void { if (panelLoader.item) panelLoader.item.themeFromWallpaper() }
    function fromImage(path: string): void {
      if (!panelLoader.item) return
      panelLoader.item.themeImagePath = path
      panelLoader.item.themeFromImage()
    }
    function verify(): void { root.verify() }
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
      color: root.opened ? root.greenColor : (button.tooltipHovered ? "#ffffff" : root.accentColor)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.iconLarge
      Behavior on color { ColorAnimation { duration: 120 } }
    }
  }
}