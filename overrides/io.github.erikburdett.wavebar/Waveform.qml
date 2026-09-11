pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  property var samples: []
  property int barCount: 18
  property bool active: false
  property bool live: false
  property int frameSerial: 0
  property color foreground: "#00f5d4"
  property real gap: 1.5
  property real minimumBarHeight: 3

  // Bump when samples/live flip so Repeater delegates re-read levels.
  property int samplesEpoch: 0

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

  onSamplesChanged: samplesEpoch++
  onLiveChanged: samplesEpoch++
  onActiveChanged: samplesEpoch++
  onBarCountChanged: samplesEpoch++
  onFrameSerialChanged: samplesEpoch++

  // Reusable theme gradients to avoid 108 redundant GradientStop instances
  readonly property Gradient activeGradient: Gradient {
    GradientStop { position: 0.00; color: "#ffb7d5" }
    GradientStop { position: 0.40; color: "#ffb7d5" }
    GradientStop { position: 0.48; color: "#00ff88" }
    GradientStop { position: 0.52; color: "#00ff88" }
    GradientStop { position: 0.60; color: "#00f5d4" }
    GradientStop { position: 1.00; color: "#00f5d4" }
  }

  readonly property Gradient idleGradient: Gradient {
    GradientStop { position: 0.00; color: "#c4a1ff" }
    GradientStop { position: 0.40; color: "#c4a1ff" }
    GradientStop { position: 0.48; color: "#8a66e0" }
    GradientStop { position: 0.52; color: "#8a66e0" }
    GradientStop { position: 0.60; color: "#5d3ebc" }
    GradientStop { position: 1.00; color: "#5d3ebc" }
  }

  function sampleAt(index) {
    if (!samples || samples.length === 0 || !live) {
      if (active) {
        return 0.15 + 0.10 * Math.sin(idlePhase + index * 0.52)
      }
      // Gentle subtle breathing wave even when paused / no media
      return 0.08 + 0.05 * Math.sin(idlePhase + index * 0.45)
    }
    var numSamples = samples.length
    if (numSamples === 1) return Math.max(0, Math.min(1.0, Number(samples[0]) || 0))
    // Linear continuous resampling across spectrum bins (no skipped bins or aliasing)
    var pos = index * (numSamples - 1) / Math.max(1, root.barCount - 1)
    var i0 = Math.floor(pos)
    var i1 = Math.min(numSamples - 1, i0 + 1)
    var frac = pos - i0
    var s0 = Number(samples[i0]) || 0
    var s1 = Number(samples[i1]) || 0
    var raw = s0 * (1.0 - frac) + s1 * frac
    return Math.max(0, Math.min(1.0, raw))
  }

  Repeater {
    model: root.barCount

    Rectangle {
      id: barItem
      required property int index

      readonly property real level: {
        var epoch = root.samplesEpoch
        var phase = root.idlePhase
        return root.sampleAt(index)
      }
      readonly property real slotWidth: root.width / Math.max(1, root.barCount)
      readonly property real goalHeight: Math.max(
        root.minimumBarHeight, root.height * (0.08 + level * 0.92))

      x: index * slotWidth + root.gap / 2
      width: Math.max(2, slotWidth - root.gap)

      // Center-anchored vertically (oscilloscope wave)
      height: goalHeight
      y: (root.height - height) / 2

      radius: Math.max(1, width / 2)
      opacity: root.live ? (level > 0.75 ? 1.0 : 0.95) : (root.active ? 0.70 : 0.45)

      gradient: root.active ? root.activeGradient : root.idleGradient

      // Sub-frame 120Hz continuous interpolation:
      // Eliminates PipeWire IPC jitter and ensures buttery-smooth 60-120fps motion.
      Behavior on height {
        NumberAnimation {
          duration: root.live ? 26 : 90
          easing.type: root.live ? Easing.OutCubic : Easing.InOutSine
        }
      }
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
  }
}
