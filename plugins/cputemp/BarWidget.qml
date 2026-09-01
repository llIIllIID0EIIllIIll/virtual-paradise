import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "__USER__.cputemp"

  property string cpuTemp: "--°C"
  property bool coolerActive: false
  readonly property int tempValue: parseInt(root.cpuTemp.replace("°C", ""), 10) || 0
  readonly property bool isOverheating: tempValue >= 85

  function refresh() {
    if (!tempProc.running) tempProc.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 1500
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: tempProc
    command: ["bash", "-c", "for z in /sys/class/thermal/thermal_zone*; do type=$(cat $z/type 2>/dev/null); case $type in *x86_pkg_temp*|*coretemp*|*k10temp*|*cpu*|*CPU*) t=$(cat $z/temp 2>/dev/null); if [ -n \"$t\" ] && [ \"$t\" -gt 0 ]; then echo $((t/1000)); break; fi ;; esac; done; if [ -z \"$t\" ]; then t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0); echo $((t/1000)); fi; cat /tmp/cooler_boost_state 2>/dev/null || echo off"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.trim().split("\n")
        if (lines.length > 0 && lines[0] !== "" && lines[0] !== "0") {
          root.cpuTemp = lines[0] + "°C"
        }
        if (lines.length > 1) {
          root.coolerActive = lines[1].trim() === "on"
        }
      }
    }
  }

  visible: true
  implicitWidth: root.vertical ? button.implicitWidth : (tempPill.width + 6)
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
    tooltipText: root.isOverheating
      ? " CPU OVERHEATING: " + root.cpuTemp + " (Cooler Boost: " + (root.coolerActive ? "ON" : "OFF") + ")\nLeft: Toggle Cooler Boost | Right: Sensor Details"
      : (" CPU Temp: " + root.cpuTemp + (root.coolerActive ? " (Cooler Boost: ON)" : " (Cooler Boost: OFF)") + "\nLeft: Toggle Cooler Boost | Right: Sensor Details")

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        root.bar.run("notify-send -u normal ' Sensor Details' \"$(sensors 2>/dev/null)\"")
      } else {
        root.bar.run("bash -c ~/.local/bin/toggle_cooler_boost.sh")
        refreshTimer.restart()
      }
    }

    Timer {
      id: refreshTimer
      interval: 300
      onTriggered: root.refresh()
    }

    // Glowing Neon Temp & Cooler Capsule Pill
    Rectangle {
      id: tempPill
      visible: !root.vertical
      anchors.centerIn: parent
      width: tempRow.implicitWidth + 20
      height: 28
      radius: 14
      color: root.isOverheating
        ? Qt.rgba(1.0, 0.0, 0.33, 0.32) // Neon Red Warning glow
        : (root.coolerActive
          ? Qt.rgba(0.0, 1.0, 0.53, 0.32) // Intense Hacker Green active glow
          : (button.tooltipHovered ? Qt.rgba(1.0, 0.72, 0.84, 0.16) : Qt.rgba(1.0, 0.72, 0.84, 0.09)))
      border.color: root.isOverheating
        ? "#ff0055" // Neon Warning Red
        : (root.coolerActive
          ? "#00ff88"
          : (button.tooltipHovered ? "#ffb7d5" : Qt.rgba(1.0, 0.72, 0.84, 0.38)))
      border.width: (root.coolerActive || root.isOverheating) ? 2 : 1

      Behavior on color { ColorAnimation { duration: 180 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }
      Behavior on border.width { NumberAnimation { duration: 150 } }

      // Intense Outer Halo Glow Ring 1 (Immediate Bright Aura)
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: tempPill.radius + 3
        color: "transparent"
        border.color: root.isOverheating ? "#ff0055" : "#00ff88"
        border.width: 2.0
        opacity: 0.90
        visible: root.coolerActive || root.isOverheating

        SequentialAnimation on opacity {
          running: root.coolerActive && !root.isOverheating
          loops: Animation.Infinite
          NumberAnimation { to: 0.40; duration: 750; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
        }
      }

      // Intense Outer Halo Glow Ring 2 (Diffuse Cyber Lime Aura)
      Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: tempPill.radius + 6
        color: "transparent"
        border.color: root.isOverheating ? "#ff0055" : "#39ff14"
        border.width: 1.5
        opacity: 0.60
        visible: root.coolerActive || root.isOverheating

        SequentialAnimation on opacity {
          running: root.coolerActive && !root.isOverheating
          loops: Animation.Infinite
          NumberAnimation { to: 0.20; duration: 750; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.75; duration: 750; easing.type: Easing.InOutQuad }
        }
      }

      SequentialAnimation on opacity {
        running: root.isOverheating
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
      }

      Row {
        id: tempRow
        anchors.centerIn: parent
        spacing: 6

        Item {
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: 16

          Text {
            id: tempIcon
            anchors.centerIn: parent
            text: root.isOverheating ? "󰈸" : (root.coolerActive ? "󰈐" : "")
            color: root.isOverheating ? "#ff0055" : (root.coolerActive ? "#00ff88" : "#ffb7d5")
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body + 1
            rotation: (!root.isOverheating && root.coolerActive) ? fanRotation : 0

            property real fanRotation: 0

            NumberAnimation on fanRotation {
              running: !root.isOverheating && root.coolerActive
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 700
            }

            Behavior on color { ColorAnimation { duration: 180 } }
          }
        }

        Text {
          id: tempLabel
          anchors.verticalCenter: parent.verticalCenter
          text: root.cpuTemp
          color: root.isOverheating ? "#ff0055" : (root.coolerActive ? "#00ff88" : "#ffffff")
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true

          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }
    }
  }
}
