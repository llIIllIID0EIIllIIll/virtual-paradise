pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  property var samples: []
  property int barCount: 18
  property bool active: false
  property bool live: false
  property color foreground: "#00f5d4"
  property real gap: 2
  property real minimumBarHeight: 3

  implicitWidth: 72
  implicitHeight: 20

  property real idlePhase: 0
  NumberAnimation on idlePhase {
    running: root.active && !root.live
    from: 0
    to: 6.283
    duration: 2200
    loops: Animation.Infinite
  }

  function sampleAt(index) {
    if (!samples || samples.length === 0 || !live) {
      if (active) {
        return 0.12 + 0.09 * Math.sin(idlePhase + index * 0.52)
      }
      return 0.05
    }
    var sourceIndex = Math.min(samples.length - 1,
      Math.floor(index * samples.length / Math.max(1, barCount)))
    var raw = Math.max(0, Math.min(1, Number(samples[sourceIndex]) || 0))
    // Non-linear power boost for punchy, reactive motion (CAVA style)
    return Math.min(1.0, Math.pow(raw, 0.85) * 1.15)
  }

  // CAVA-style vertical gradient color mapping:
  // Base (0.0): Miku Cyan #00f5d4
  // Mid  (0.5): Cyber Lime Green #00ff88
  // Peak (1.0): Sakura Pink #ffb7d5
  function topColorForLevel(lvl) {
    if (!root.active) return "#ad88ff"
    if (lvl < 0.35) {
      var t = lvl / 0.35
      return Qt.rgba(0.0, 0.96 + 0.04 * t, 0.83 - 0.30 * t, 1.0)
    } else if (lvl < 0.72) {
      var t = (lvl - 0.35) / 0.37
      return Qt.rgba(0.0 + 1.0 * t, 1.0 - 0.28 * t, 0.53 + 0.31 * t, 1.0)
    } else {
      var t = Math.min(1.0, (lvl - 0.72) / 0.28)
      return Qt.rgba(1.0, 0.72 + 0.08 * t, 0.84 + 0.06 * t, 1.0)
    }
  }

  function midColorForLevel(lvl) {
    if (!root.active) return "#8a66e0"
    if (lvl < 0.40) return "#00f5d4"
    return "#00ff88"
  }

  Repeater {
    model: root.barCount

    Rectangle {
      id: barItem
      required property int index
      readonly property real level: root.sampleAt(index)
      readonly property real slotWidth: root.width / Math.max(1, root.barCount)

      x: index * slotWidth + root.gap / 2
      width: Math.max(1.5, slotWidth - root.gap)
      height: Math.max(root.minimumBarHeight, Math.round(root.height * (0.06 + level * 0.94)))
      // Grow upwards from baseline like CAVA equalizer
      y: root.height - height
      radius: Math.max(1, width / 2)
      opacity: root.live ? (level > 0.8 ? 1.0 : 0.94) : (root.active ? 0.65 : 0.35)

      // CAVA 3-Color Dynamic Gradient
      gradient: Gradient {
        GradientStop {
          position: 0.0
          color: root.topColorForLevel(barItem.level)
        }
        GradientStop {
          position: 0.5
          color: root.midColorForLevel(barItem.level)
        }
        GradientStop {
          position: 1.0
          color: root.active ? "#00f5d4" : "#6a4bc2"
        }
      }

      Behavior on height {
        NumberAnimation { duration: 38; easing.type: Easing.OutCubic }
      }
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
  }
}
