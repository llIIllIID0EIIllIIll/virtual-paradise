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
    running: root.active && !root.live
    from: 0
    to: 6.283
    duration: 2200
    loops: Animation.Infinite
  }

  function sampleAt(index) {
    if (!samples || samples.length === 0 || !live) {
      if (active) {
        return 0.14 + 0.10 * Math.sin(idlePhase + index * 0.52)
      }
      return 0.05
    }
    var sourceIndex = Math.min(samples.length - 1,
      Math.floor(index * samples.length / Math.max(1, barCount)))
    var raw = Math.max(0, Math.min(1, Number(samples[sourceIndex]) || 0))
    // Non-linear power boost for punchy, reactive motion (CAVA style)
    return Math.min(1.0, Math.pow(raw, 0.80) * 1.20)
  }

  // CAVA 3-Color Horizontal & Vertical Spectrum:
  // Top: Sakura Pink #ffb7d5 -> Magenta #ff70a6
  // Mid: Cyber Lime Green #00ff88
  // Base: Miku Cyan #00f5d4
  function topColorAt(index) {
    if (!root.active) return "#c4a1ff"
    var h = index / Math.max(1, root.barCount - 1)
    // Left: #ffb7d5 -> Right: #ff70b8
    return Qt.rgba(1.0, 0.72 - 0.14 * h, 0.84 - 0.12 * h, 1.0)
  }

  function midColorAt(index) {
    if (!root.active) return "#8a66e0"
    return "#00ff88"
  }

  function baseColorAt(index) {
    if (!root.active) return "#5d3ebc"
    var h = index / Math.max(1, root.barCount - 1)
    // Bass on left is deep pure cyan #00f5d4, transitioning softly
    return Qt.rgba(0.0, 0.96, 0.83 - 0.15 * h, 1.0)
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
      // Grow upwards from baseline like CAVA equalizer
      y: root.height - height
      radius: Math.max(1, width / 2)
      opacity: root.live ? (level > 0.75 ? 1.0 : 0.94) : (root.active ? 0.70 : 0.35)

      // CAVA 3-Color Full Vertical Gradient on every bar:
      // Top: Sakura Pink #ffb7d5 (Peak)
      // Mid: Cyber Lime Green #00ff88 (Mid)
      // Base: Miku Cyan #00f5d4 (Base)
      gradient: Gradient {
        GradientStop {
          position: 0.0
          color: root.topColorAt(barItem.index)
        }
        GradientStop {
          position: 0.42
          color: root.midColorAt(barItem.index)
        }
        GradientStop {
          position: 1.0
          color: root.baseColorAt(barItem.index)
        }
      }

      Behavior on height {
        NumberAnimation { duration: 38; easing.type: Easing.OutCubic }
      }
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
  }
}
