import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "__USER__.memory"

  property string memUsage: "..."
  property bool btopActive: false
  readonly property int ramPercent: {
    var match = root.memUsage.match(/\((\d+)%\)/)
    return match ? parseInt(match[1], 10) : 0
  }
  readonly property bool isRamCritical: ramPercent >= 90

  function refresh() {
    if (!memProc.running) memProc.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 1500
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: memProc
    command: ["bash", "-c", "free -m | awk '/Mem:/ { printf(\"%.1fG (%.0f%%)\\n\", $3/1024, $3/$2*100) }'; if pgrep -x btop >/dev/null 2>&1; then echo 'on'; else echo 'off'; fi"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.trim().split("\n")
        if (lines.length > 0 && lines[0] !== "") {
          root.memUsage = lines[0].trim()
        }
        if (lines.length > 1) {
          root.btopActive = lines[1].trim() === "on"
        }
      }
    }
  }

  visible: true
  implicitWidth: root.vertical ? button.implicitWidth : (memPill.width + 6)
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
    tooltipText: root.isRamCritical
      ? " HIGH RAM USAGE: " + root.memUsage + "\nLeft: Launch Btop | Right: Memory Details"
      : ("󰍛 Memory Usage: " + root.memUsage + (root.btopActive ? " (Btop: ON)" : " (Btop: OFF)") + "\nLeft: Toggle Btop | Right: Memory Details")

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        root.bar.run("~/.local/bin/memory_detail_notify.sh")
      } else {
        root.bar.run("~/.local/bin/toggle_btop.sh")
        refreshTimer.restart()
      }
    }

    Timer {
      id: refreshTimer
      interval: 300
      onTriggered: root.refresh()
    }

    // Glowing Neon Memory Capsule Pill
    Rectangle {
      id: memPill
      visible: !root.vertical
      anchors.centerIn: parent
      width: memRow.implicitWidth + 20
      height: 28
      radius: 14
      color: root.isRamCritical
        ? Qt.rgba(1.0, 0.0, 0.33, 0.32) // Neon Red Warning glow
        : (root.btopActive
          ? Qt.rgba(0.0, 0.96, 0.83, 0.30) // Miku Cyan intense active glow
          : (button.tooltipHovered ? Qt.rgba(0.0, 0.96, 0.83, 0.16) : Qt.rgba(0.0, 0.96, 0.83, 0.09)))
      border.color: root.isRamCritical
        ? "#ff0055" // Neon Warning Red
        : (root.btopActive ? "#00f5d4" : (button.tooltipHovered ? "#00f5d4" : Qt.rgba(0.0, 0.96, 0.83, 0.38)))
      border.width: (root.btopActive || root.isRamCritical) ? 2 : 1

      Behavior on color { ColorAnimation { duration: 180 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }
      Behavior on border.width { NumberAnimation { duration: 150 } }

      // Intense Outer Halo Glow Ring 1 (Immediate Bright Aura)
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: memPill.radius + 3
        color: "transparent"
        border.color: root.isRamCritical ? "#ff0055" : "#00f5d4"
        border.width: 2.0
        opacity: 0.90
        visible: root.btopActive || root.isRamCritical

        SequentialAnimation on opacity {
          running: root.btopActive && !root.isRamCritical
          loops: Animation.Infinite
          NumberAnimation { to: 0.40; duration: 800; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
        }
      }

      // Intense Outer Halo Glow Ring 2 (Diffuse Cyan/Green Aura)
      Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: memPill.radius + 6
        color: "transparent"
        border.color: root.isRamCritical ? "#ff0055" : "#00ff88"
        border.width: 1.5
        opacity: 0.60
        visible: root.btopActive || root.isRamCritical

        SequentialAnimation on opacity {
          running: root.btopActive && !root.isRamCritical
          loops: Animation.Infinite
          NumberAnimation { to: 0.20; duration: 800; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.75; duration: 800; easing.type: Easing.InOutQuad }
        }
      }

      SequentialAnimation on opacity {
        running: root.isRamCritical
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
      }

      Row {
        id: memRow
        anchors.centerIn: parent
        spacing: 6

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰍛"
          color: root.isRamCritical ? "#ff0055" : "#00f5d4"
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body + 1

          Behavior on color { ColorAnimation { duration: 180 } }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.memUsage !== "" ? root.memUsage : "RAM"
          color: root.isRamCritical ? "#ff0055" : (root.btopActive ? "#00f5d4" : "#ffffff")
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true

          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }
    }
  }
}
