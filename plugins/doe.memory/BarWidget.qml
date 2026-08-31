import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "doe.memory"

  property string memUsage: "..."
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
    interval: 3000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: memProc
    command: ["bash", "-c", "free -m | awk '/Mem:/ { printf(\"%.1fG (%.0f%%)\", $3/1024, $3/$2*100) }'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = text.trim()
        if (str !== "") root.memUsage = str
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
      ? "⚠️ HIGH RAM USAGE: " + root.memUsage + "\nLeft: Launch Btop | Right: Memory Details"
      : ("Memory Usage: " + root.memUsage + "\nLeft: Toggle Btop | Right: Memory Details")

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        root.bar.run("~/.local/bin/memory_detail_notify.sh")
      } else {
        root.bar.run("~/.local/bin/toggle_btop.sh")
      }
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
        ? Qt.rgba(1.0, 0.0, 0.33, 0.22) // Neon Red Warning glow
        : Qt.rgba(0.0, 0.96, 0.83, 0.09) // Miku Cyan frosted tint
      border.color: root.isRamCritical
        ? "#ff0055" // Neon Warning Red
        : (button.tooltipHovered ? "#00f5d4" : Qt.rgba(0.0, 0.96, 0.83, 0.38))
      border.width: 1

      Behavior on color { ColorAnimation { duration: 180 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }

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
          color: root.isRamCritical ? "#ff0055" : "#ffffff"
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true

          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }
    }
  }
}
