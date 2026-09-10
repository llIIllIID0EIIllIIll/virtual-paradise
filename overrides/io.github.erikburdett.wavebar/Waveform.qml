pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  property var samples: []
  property int barCount: 18
  property bool active: false
  property bool live: false
  property color foreground: "#00f5d4"
  property real gap: 1.5
  property real minimumBarHeight: 3

  implicitWidth: 72
  implicitHeight: 20

  property real idlePhase: 0
  NumberAnimation on idlePhase {
    running: !root.live
    from: 0
    to: 6.283
    duration: 2600
    loops: Animation.Infinite
  }

  function sampleAt(index) {
    if (!samples || samples.length === 0 || !live) {
      if (active) {
        return 0.15 + 0.10 * Math.sin(idlePhase + index * 0.52)
      }
      // Gentle subtle breathing wave even when paused / no media
      return 0.08 + 0.05 * Math.sin(idlePhase + index * 0.45)
    }
    var sourceIndex = Math.min(samples.length - 1,
      Math.floor(index * samples.length / Math.max(1, barCount)))
    var raw = Math.max(0, Math.min(1, Number(samples[sourceIndex]) || 0))
    // Non-linear power boost for punchy, reactive motion (CAVA style)
    return Math.min(1.0, Math.pow(raw, 0.80) * 1.20)
  }

  // Theme gradient ratio: 40% Cyan (#00f5d4), 20% Green (#00ff88), 40% Pink (#ffb7d5)
  function horizontalTint(index) {
    var h = index / Math.max(1, root.barCount - 1)
    if (h <= 0.40) {
      // First 40%: Cyan #00f5d4 -> subtle blend towards Green at edge
      var t = h / 0.40
      return Qt.rgba(0.0, 0.96 + 0.04 * t, 0.83 - 0.20 * t, 1.0)
    } else if (h <= 0.60) {
      // Middle 20%: Cyber Lime Green #00ff88
      var t2 = (h - 0.40) / 0.20
      return Qt.rgba(t2 * 0.7, 1.0 - 0.12 * t2, 0.53 + 0.15 * t2, 1.0)
    } else {
      // Last 40%: Sakura Pink #ffb7d5
      var t3 = (h - 0.60) / 0.40
      return Qt.rgba(0.75 + 0.25 * t3, 0.88 - 0.16 * t3, 0.68 + 0.16 * t3, 1.0)
    }
  }

  Repeater {
    model: root.barCount

    Rectangle {
      id: barItem
      required property int index
      readonly property real level: root.sampleAt(index)
      readonly property real slotWidth: root.width / Math.max(1, root.barCount)

      x: index * slotWidth + root.gap / 2
      width: Math.max(2, slotWidth - root.gap)
      height: Math.max(root.minimumBarHeight, Math.round(root.height * (0.08 + level * 0.92)))
      // Wave ngang centered vertically like original wavebar (oscilloscope style)
      y: Math.round((root.height - height) / 2)
      radius: Math.max(1, width / 2)
      opacity: root.live ? (level > 0.75 ? 1.0 : 0.95) : (root.active ? 0.70 : 0.45)

      // Theme Gradient: 40% Pink (top) -> 20% Green (mid) -> 40% Cyan (base)
      gradient: Gradient {
        // Top 40%: Sakura Pink (#ffb7d5)
        GradientStop {
          position: 0.00
          color: root.active ? "#ffb7d5" : "#c4a1ff"
        }
        GradientStop {
          position: 0.40
          color: root.active ? "#ffb7d5" : "#c4a1ff"
        }
        // Center 20%: Cyber Lime Green (#00ff88)
        GradientStop {
          position: 0.48
          color: root.active ? "#00ff88" : "#8a66e0"
        }
        GradientStop {
          position: 0.52
          color: root.active ? "#00ff88" : "#8a66e0"
        }
        // Bottom 40%: Miku Cyan (#00f5d4)
        GradientStop {
          position: 0.60
          color: root.active ? "#00f5d4" : "#5d3ebc"
        }
        GradientStop {
          position: 1.00
          color: root.active ? "#00f5d4" : "#5d3ebc"
        }
      }

      Behavior on height {
        NumberAnimation { duration: 38; easing.type: Easing.OutCubic }
      }
      Behavior on opacity { NumberAnimation { duration: 140 } }
    }
  }
}
