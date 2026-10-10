import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Battery level, charge state and power profile.
//
// Replaces onlyvishesh.power-manager's bar entry. Upstream's panel does a lot
// more - battery health, cycle count, per-source profiles - but the bar itself
// exists to answer one question, so this reads the two sysfs files that answer
// it and cycles the profile on click. Everything is read from sysfs; the only
// command is the profile setter, which is Omarchy's own wrapper.
//
// Profile is cycled rather than picked: a bar click has no room to be a menu,
// and the three profiles are cheap to step through.
BarWidget {
  id: root
  moduleName: "__USER__.power"

  // Overridable so a second battery or a differently named one still works.
  readonly property string batteryName: String(setting("battery", "BAT1"))
  readonly property string acName: String(setting("acAdapter", "ACAD"))
  readonly property int pollMs: Number(setting("refreshMs", 5000))

  readonly property int warnPercent: Number(setting("warningPercent", 20))
  readonly property int criticalPercent: Number(setting("criticalPercent", 10))

  readonly property bool hasBattery: capacity >= 0
  readonly property bool charging: status === "Charging" || status === "Full"
  readonly property bool low: hasBattery && !charging && capacity <= warnPercent
  readonly property bool critical: hasBattery && !charging && capacity <= criticalPercent

  property int capacity: -1
  property string status: ""
  property bool onAc: false
  property string profile: ""

  // Ordered from least to most battery-friendly, so a click walks toward
  // power saving and wraps back to performance.
  readonly property var profileCycle: ["performance", "balanced", "power-saver"]

  function nextProfile() {
    var index = profileCycle.indexOf(profile)
    return profileCycle[(index + 1) % profileCycle.length]
  }

  function cycleProfile() {
    if (!root.bar || !hasBattery) return
    var target = nextProfile()
    // Omarchy stores a profile per power source, so the source has to be named.
    root.bar.run("omarchy-powerprofiles-set "
      + (onAc ? "ac" : "battery") + " " + Util.shellQuote(target))
    profile = target
  }

  function glyph() {
    if (!hasBattery) return "󰁹"
    if (charging) return "󰂄"
    if (capacity <= criticalPercent) return "󰁺"
    if (capacity <= warnPercent) return "󰁻"
    if (capacity <= 50) return "󰁽"
    if (capacity <= 80) return "󰁿"
    return "󰁹"
  }

  function text() {
    if (!hasBattery) return ""
    var base = capacity + "%"
    if (profile === "performance") base += " 󰓅"
    else if (profile === "power-saver") base += " 󰾆"
    return base
  }

  visible: true
  implicitWidth: root.vertical ? button.implicitWidth
    : (pill.width + (button.tooltipHovered ? 4 : 0))
  implicitHeight: button.implicitHeight

  // One poll for all four readings. FileView with watchChanges is unreliable on
  // sysfs - the kernel does not bump the attribute mtime the way a regular file
  // does - so the values are read together on a timer instead.
  Process {
    id: pollProc

    command: ["bash", "-c",
      'b="/sys/class/power_supply/$1"; a="/sys/class/power_supply/$2"; '
      + 'cat "$b/capacity" 2>/dev/null || echo -1; '
      + 'cat "$b/status" 2>/dev/null || echo ""; '
      + 'cat "$a/online" 2>/dev/null || echo 0; '
      + 'powerprofilesctl get 2>/dev/null || echo ""',
      "vp-power", root.batteryName, root.acName]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text).split("\n")
        var cap = parseInt(lines[0], 10)
        root.capacity = isFinite(cap) ? cap : -1
        root.status = String(lines[1] || "").trim()
        root.onAc = String(lines[2] || "").trim() === "1"
        var prof = String(lines[3] || "").trim()
        if (prof !== "") root.profile = prof
      }
    }
  }

  Timer {
    interval: root.pollMs
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!pollProc.running) pollProc.running = true
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
    tooltipText: root.hasBattery
      ? "Battery " + root.capacity + "% (" + (root.charging ? "charging" : "discharging")
        + ")\nProfile: " + (root.profile || "unknown") + "\nClick to cycle profile"
      : "No battery detected"

    onPressed: function () { root.cycleProfile() }

    Rectangle {
      id: pill
      anchors.centerIn: parent
      width: root.vertical ? 28 : (row.implicitWidth + 18)
      height: 28
      radius: 14
      color: button.tooltipHovered
        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
        : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.07)
      border.width: 1.5
      border.color: root.critical
        ? Color.urgent
        : root.low
          ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.7)
          : Color.accent

      Behavior on border.color { ColorAnimation { duration: 200 } }
      Behavior on color { ColorAnimation { duration: 160 } }

      Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        visible: !root.vertical

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.glyph()
          color: root.critical ? Color.urgent : Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.icon
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.text()
          visible: root.hasBattery
          color: root.critical
            ? Color.urgent
            : (root.bar ? root.bar.barForeground : Color.foreground)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Text {
        anchors.centerIn: parent
        visible: root.vertical
        text: root.glyph()
        color: root.critical ? Color.urgent : Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.icon
      }
    }
  }
}
