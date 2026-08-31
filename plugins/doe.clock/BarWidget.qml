import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Date/time label for the bar, and the host for the calendar popup.
BarWidget {
  id: root
  moduleName: "doe.clock"

  property date displayDate: clock.date

  readonly property string configuredFormat: vertical
    ? setting("verticalFormat", "HH\n—\nmm")
    : setting("format", "dddd HH:mm")
  readonly property string configuredAltFormat: vertical
    ? setting("verticalFormatAlt", "dd\nMMM\n'W'ww\n''yy")
    : setting("formatAlt", "d MMMM 'W'ww yyyy")

  readonly property var formatRing: Model.clockFormatRing(configuredFormat, configuredAltFormat, Model.clockFormats(vertical))
  readonly property string activeFormat: configuredFormat
  readonly property string displayText: formatted(displayDate)
  readonly property var verticalLines: displayText.split("\n")

  function refresh() {
    displayDate = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleFormat() {
    var current = String(configuredFormat)
    var next = Model.nextClockFormat(formatRing, current)
    if (next === "" || next === current) return

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[vertical ? "verticalFormat" : "format"] = next

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function formatted(date) {
    return Qt.formatDateTime(date, activeFormat.replace(/ww/g, Model.isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate())))
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function toggleWeekStart() {
    if (panelLoader.item) panelLoader.item.toggleWeekStart()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: root.vertical ? button.implicitWidth : (clockPill.width + 8)
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
    onDateChanged: root.displayDate = date
  }

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

  IpcHandler {
    target: "doe.clock"

    function refresh(): void { root.broadcast("refresh") }
    function cycleFormat(): void { root.cycleFormat() }
    function toggleWeekStart(): void { root.toggleWeekStart() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 2
    verticalPadding: 2
    tooltipText: Qt.formatDateTime(root.displayDate, "dddd, d MMMM yyyy • HH:mm:ss") + "\nLeft: Open Calendar | Right: Cycle Format | Middle: Timezone"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else if (b === Qt.MiddleButton) { if (root.bar) root.bar.run("omarchy-menu-timezone") }
      else root.togglePanel()
    }

    // Glowing Neon Cyberpunk Capsule Pill
    Rectangle {
      id: clockPill
      visible: !root.vertical
      anchors.centerIn: parent
      width: clockRow.implicitWidth + 24
      height: 28
      radius: 14
      color: root.opened
        ? Qt.rgba(0.0, 1.0, 0.53, 0.25)
        : (button.tooltipHovered ? Qt.rgba(0.0, 0.96, 0.83, 0.16) : Qt.rgba(0.0, 0.96, 0.83, 0.09))
      border.color: root.opened ? "#00ff88" : (button.tooltipHovered ? "#00f5d4" : Qt.rgba(0.0, 0.96, 0.83, 0.40))
      border.width: root.opened ? 2 : 1

      Behavior on color { ColorAnimation { duration: 180 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }
      Behavior on border.width { NumberAnimation { duration: 150 } }

      // Outer Halo Glow Ring when Calendar Popup is Opened
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: clockPill.radius + 3
        color: "transparent"
        border.color: "#00ff88"
        border.width: 1.8
        opacity: 0.85
        visible: root.opened

        SequentialAnimation on opacity {
          running: root.opened
          loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.95; duration: 800; easing.type: Easing.InOutQuad }
        }
      }

      Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 6

        // Clock Icon
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰥔"
          color: "#00f5d4" // Miku Cyan
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        // Hours : Minutes : Seconds (Compact layout)
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(root.displayDate, "HH:mm")
            color: "#ffffff" // Pure White
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body + 1
            font.bold: true
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ":" + Qt.formatDateTime(root.displayDate, "ss")
            color: "#00f5d4" // Miku Cyan
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
        }

        // Glowing Separator Dot
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "•"
          color: "#00ff88" // Hacker Green
          font.pixelSize: Style.font.body
        }

        // Weekday
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Qt.formatDateTime(root.displayDate, "ddd")
          color: "#ffe066" // Cyber Yellow
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.weight: Font.Medium
        }

        // Day Month Year (Compact date)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Qt.formatDateTime(root.displayDate, "d MMM yyyy")
          color: "#ffb7d5" // Sakura Pastel Pink
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.weight: Font.Medium
        }
      }
    }

    // Vertical layout fallback
    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3
            ? button.fontSize * 0.9
            : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
