import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar entry for Vitals: a chip icon that opens the monitor panel. The panel
// itself lives in Panel.qml and is loaded once, so its state (selected tab,
// sort order, history) survives between opens.
//
// Upstream ships a bare BarIconButton, which reads as a flat grey glyph next to
// the themed widgets around it. The pill, halo rings and breathing animation
// below match the house style used by the microphone and clock widgets, and the
// ring shifts to the warning colour while the panel is open so the chip reads as
// "already showing something".
//
// CPU and GPU utilisation sit next to the chip. CPU is differenced from
// /proc/stat through FileView, which costs no subprocess. GPU has no such
// source on a proprietary NVIDIA card - the driver publishes nothing in sysfs -
// so it is polled from nvidia-smi on a slow timer and the label hides itself
// when no usable GPU is present. Upstream deliberately keeps collector.py out
// of the closed-panel path, so this does not reintroduce its per-second cost.
BarWidget {
  id: root
  moduleName: "io.github.woogy7.vitals"

  readonly property color accent: "#00f5d4"
  readonly property color live: "#00ff88"
  readonly property color ringColor: root.opened ? "#ffb7d5" : root.accent

  // --- CPU: /proc/stat deltas, no subprocess ---
  property real cpuPercent: -1
  property real lastBusy: -1
  property real lastTotal: -1
  readonly property int sampleIntervalMs: 2000

  function handleCpuStat(raw) {
    var line = String(raw || "").split("\n")[0]
    if (!line.startsWith("cpu ")) return
    var parts = line.trim().split(/\s+/).slice(1).map(Number)
    var values = Array.isArray(parts) ? parts : []
    var idle = (values[3] || 0) + (values[4] || 0)
    var busy = 0
    for (var i = 0; i < values.length; i++) busy += values[i]
    busy -= idle
    var total = busy + idle
    if (total <= 0) return
    // First sample only establishes the baseline; a percentage from it would
    // be the average since boot.
    if (root.lastTotal >= 0) {
      var dTotal = total - root.lastTotal
      var dBusy = busy - root.lastBusy
      if (dTotal > 0) root.cpuPercent = Math.max(0, Math.min(100, (dBusy / dTotal) * 100))
    }
    root.lastBusy = busy
    root.lastTotal = total
  }

  // --- GPU: nvidia-smi, polled ---
  property real gpuPercent: -1

  function handleGpu(raw) {
    var line = String(raw || "").trim().split("\n")[0].trim()
    if (!line) {
      root.gpuPercent = -1
      return
    }
    var value = Number(line.split(",")[0].trim())
    root.gpuPercent = isFinite(value) && value >= 0 ? Math.min(100, value) : -1
  }

  readonly property bool hasGpu: gpuPercent >= 0

  function percentText(value) {
    return value >= 0 ? String(Math.round(value)) : "—"
  }

  // --- panel plumbing (unchanged from upstream) ---
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing — the bar identifies
  // this widget, not the nested panel (same pattern as the weather plugin).
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

  // Width has to be driven by the pill, because the pill is what carries the
  // readouts. Leaving it to the button let a centred pill overflow its slot on
  // both sides and paint over the clock.
  implicitWidth: pill.width + 8
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

  // /proc/stat is read on every tick rather than watched: the kernel bumps its
  // mtime constantly, so watchChanges would thrash the reload.
  FileView {
    id: statFile
    path: "/proc/stat"
    watchChanges: false
    printErrors: false
    onLoaded: root.handleCpuStat(text())
  }

  Process {
    id: gpuProc
    command: ["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"]
    stdout: StdioCollector {
      waitForEnd: true
      // `text` is a property, not a method - calling it() throws a TypeError
      // and the reading is silently dropped.
      onStreamFinished: root.handleGpu(text)
    }
  }

  Timer {
    id: sampleTimer
    interval: root.sampleIntervalMs
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      statFile.reload()
      gpuProc.running = true
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
    tooltipText: root.hasGpu
      ? "Vitals — CPU " + root.percentText(root.cpuPercent) + "% · GPU " + root.percentText(root.gpuPercent) + "%"
      : "Vitals — CPU " + root.percentText(root.cpuPercent) + "%"

    onPressed: function() { root.togglePanel() }

    Rectangle {
      id: pill
      // Left-anchored, not centred: centring an over-wide pill bleeds it left
      // over the neighbouring widget.
      anchors.left: parent.left
      anchors.leftMargin: 2
      anchors.verticalCenter: parent.verticalCenter
      // One capsule around the chip icon and both readouts. Sizing from the
      // inner Row keeps the halo hugging the content instead of a fixed 30px
      // chip that the percentages would spill out of.
      width: inner.implicitWidth + 18
      height: 28
      radius: 14
      color: button.tooltipHovered || root.opened
        ? Qt.rgba(0.0, 0.96, 0.83, 0.18)
        : Qt.rgba(0.0, 0.96, 0.83, 0.08)
      border.color: root.ringColor
      border.width: 1.6
      scale: button.tooltipHovered ? 1.05 : 1

      Behavior on color { ColorAnimation { duration: 160 } }
      Behavior on border.color { ColorAnimation { duration: 160 } }
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

      // Outer halo. Idle it breathes so the chip is findable without competing
      // with the neighbours; opening the panel settles it into a steady glow.
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: pill.radius + 3
        color: "transparent"
        border.color: root.ringColor
        border.width: 1.6
        opacity: 0.85
        visible: true

        SequentialAnimation on opacity {
          running: !root.opened
          loops: Animation.Infinite
          NumberAnimation { to: 0.32; duration: 1500; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.85; duration: 1500; easing.type: Easing.InOutQuad }
        }
      }

      // Inner echo ring, one step behind the outer one.
      Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: pill.radius + 6
        color: "transparent"
        border.color: root.ringColor
        border.width: 1.2
        opacity: 0.5
        visible: true

        SequentialAnimation on opacity {
          running: !root.opened
          loops: Animation.Infinite
          NumberAnimation { to: 0.18; duration: 1500; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.55; duration: 1500; easing.type: Easing.InOutQuad }
        }
      }

      Row {
        id: inner
        anchors.centerIn: parent
        spacing: 7

        Text {
          text: panelLoader.item ? panelLoader.item.icon : "󰍛"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.icon
          color: root.opened ? "#ffb7d5" : (button.tooltipHovered ? "#ffffff" : root.accent)
          scale: button.tooltipHovered ? 1.12 : 1.0

          Behavior on color { ColorAnimation { duration: 160 } }
          Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        }

        Row {
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: "CPU"
            color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.55)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: root.percentText(root.cpuPercent) + "%"
            color: root.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Row {
          spacing: 2
          visible: root.hasGpu
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: "GPU"
            color: Qt.rgba(root.bar ? root.bar.foreground.r : 1, root.bar ? root.bar.foreground.g : 1, root.bar ? root.bar.foreground.b : 1, 0.55)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: root.percentText(root.gpuPercent) + "%"
            color: root.live
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
