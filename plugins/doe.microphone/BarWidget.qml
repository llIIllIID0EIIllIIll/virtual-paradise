import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "doe.microphone"

  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool muted: source && source.audio ? source.audio.muted : true
  readonly property real volume: source && source.audio ? source.audio.volume : 0
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  readonly property var activeStreams: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (node && node.isStream && node.isSink === false && !node.audio?.muted) list.push(node)
    }
    return list
  }

  readonly property bool inUse: activeStreams.length > 0 && !muted

  visible: source !== null
  implicitWidth: 32
  implicitHeight: button.implicitHeight

  function toggleMute() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  PwObjectTracker { objects: root.source ? [root.source] : [] }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 2
    verticalPadding: 2
    tooltipText: root.muted
      ? "Microphone: Muted (Left: Unmute | Right: Config)"
      : ("Microphone: Live (" + Math.round(root.volume * 100) + "%)\nLeft: Toggle Mute | Right: Dictation Config | Scroll: Volume")

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.bar.run("omarchy-shell shell toggle omarchy.audio")
      else if (b === Qt.RightButton) root.bar.run("~/.local/bin/toggle_voxtype_config.sh")
      else root.toggleMute()
    }
    onWheelMoved: function(delta) {
      if (!root.source || !root.source.audio) return
      var step = 0.05
      root.source.audio.volume = Math.max(0, Math.min(1, root.volume + (delta > 0 ? step : -step)))
    }

    Item {
      anchors.centerIn: parent
      width: 24
      height: 24

      Text {
        anchors.centerIn: parent
        text: root.muted ? "󰍭" : "󰍬"
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.icon
        color: !root.muted ? (button.tooltipHovered ? "#00ff88" : "#00f5d4") : (button.tooltipHovered ? "#ffffff" : "#7091a4")
        scale: button.tooltipHovered ? 1.15 : 1.0

        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
      }
    }
  }
}
