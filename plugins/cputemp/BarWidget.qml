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
  // Middle tier: warm enough to warn, not yet throttling.
  readonly property bool isWarm: tempValue >= 70 && tempValue < 85

  // The thermal zone is resolved once, then read with one cheap cat each
  // tick. The cooler state is asked from the hardware every 30s, not every
  // 1.5s, and a click still reconciles it instantly through refresh(). The old
  // command re-scanned every thermal zone and ran the full cooler-boost
  // detector on every tick - the heaviest poll on the bar.
  property string thermalPath: ""

  Component.onCompleted: zoneProbe.running = true

  Process {
    id: zoneProbe
    command: ["bash", "-c", "for z in /sys/class/thermal/thermal_zone*; do case $(cat $z/type 2>/dev/null) in *x86_pkg_temp*|*coretemp*|*k10temp*|*cpu*|*CPU*) [ -f $z/temp ] && { echo $z/temp; exit 0; } ;; esac; done; echo /sys/class/thermal/thermal_zone0/temp"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var p = text.trim()
        if (p !== "") {
          root.thermalPath = p
          if (!tempProc.running) tempProc.running = true
        }
      }
    }
  }

  // One cheap read of the resolved zone. Nothing to loop, nothing else to
  // spawn.
  Process {
    id: tempProc
    command: ["cat", root.thermalPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = text.trim()
        if (t !== "" && t !== "0") root.cpuTemp = (Math.round(parseInt(t, 10) / 1000)) + "°C"
      }
    }
  }

  Timer {
    interval: 1500
    running: root.thermalPath !== ""
    repeat: true
    onTriggered: if (!tempProc.running) tempProc.running = true
  }

  // The fan is only asked from the hardware every 30s instead of every 1.5s;
  // a click re-runs the detector immediately, so the answer stays current.
  Process {
    id: coolerProc
    command: ["bash", "-c", "~/.local/bin/toggle_cooler_boost.sh state 2>/dev/null || echo off"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.coolerActive = text.trim() === "on"
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!coolerProc.running) coolerProc.running = true
  }

  function refresh() {
    if (root.thermalPath !== "" && !tempProc.running) tempProc.running = true
    if (!coolerProc.running) coolerProc.running = true
  }

  visible: true
  implicitWidth: root.vertical ? button.implicitWidth
    : (tempPill.width + 6 + (button.tooltipHovered ? 4 : 0))
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
    Accessible.name: "CPU temperature"
    Accessible.role: Accessible.Button
    Accessible.description: "Toggle Cooler Boost"
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
        : (root.isWarm
          ? Qt.rgba(1.0, 0.88, 0.40, 0.24) // Amber warning glow
          : (root.coolerActive
            ? Qt.rgba(0.0, 1.0, 0.53, 0.20) // Hacker Green active glow, kept dim so it
            //                    does not outshine the themed widgets beside it
            : (button.tooltipHovered ? Qt.rgba(1.0, 0.72, 0.84, 0.16) : Qt.rgba(1.0, 0.72, 0.84, 0.09))))
      border.color: root.isOverheating
        ? "#ff0055" // Neon Warning Red
        : (root.isWarm
          ? "#ffe066" // Amber
          : (root.coolerActive
            ? "#00ff88"
            : (button.tooltipHovered ? "#ffb7d5" : Qt.rgba(1.0, 0.72, 0.84, 0.38))))
      border.width: (root.coolerActive || root.isOverheating || root.isWarm) ? 1.6 : 1
      scale: button.tooltipHovered ? 1.04 : 1

      Behavior on color { ColorAnimation { duration: 180 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }
      Behavior on border.width { NumberAnimation { duration: 150 } }
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

      // Intense Outer Halo Glow Ring 1 (Immediate Bright Aura)
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: tempPill.radius + 3
        color: "transparent"
        border.color: root.isOverheating ? "#ff0055" : "#00ff88"
        border.width: 1.6
        opacity: 0.62
        visible: root.coolerActive || root.isOverheating || button.tooltipHovered

        SequentialAnimation on opacity {
          running: root.coolerActive && !root.isOverheating
          loops: Animation.Infinite
          NumberAnimation { to: 0.34; duration: 1500; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.72; duration: 1500; easing.type: Easing.InOutQuad }
        }
      }

      // Intense Outer Halo Glow Ring 2 (Diffuse Cyber Lime Aura)
      Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: tempPill.radius + 6
        color: "transparent"
        border.color: root.isOverheating ? "#ff0055" : "#00ff88"
        border.width: 1.2
        opacity: 0.40
        visible: root.coolerActive || root.isOverheating || button.tooltipHovered

        SequentialAnimation on opacity {
          running: root.coolerActive && !root.isOverheating
          loops: Animation.Infinite
          NumberAnimation { to: 0.16; duration: 1500; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.48; duration: 1500; easing.type: Easing.InOutQuad }
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
            color: root.isOverheating ? "#ff0055" : (root.isWarm ? "#ffe066" : (root.coolerActive ? "#00ff88" : "#ffb7d5"))
            font.family: (root.bar ? root.bar.fontFamily : Style.font.family)
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
          color: root.isOverheating ? "#ff0055" : (root.isWarm ? "#ffe066" : (root.coolerActive ? "#00ff88" : "#ffffff"))
          font.family: (root.bar ? root.bar.fontFamily : Style.font.family)
          font.pixelSize: Style.font.body
          font.bold: true

          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }
    }
  }
}
