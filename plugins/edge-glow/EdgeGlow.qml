import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Screen-edge neon flash on workspace changes and notifications.
//
// Listens to Hyprland's event socket (line-based, so a plain SplitParser is
// enough) and flashes a soft edge band in cyan for a workspace change and in
// magenta when a notification layer opens. Click-through everywhere, overlay
// layer, so it never steals input.
Item {
  id: root

  property color glowColor: Color.accent !== undefined ? Color.accent : "#00ffdd"
  property int generation: 0

  readonly property string eventSocket: {
    var runtime = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    var signature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
    return signature ? runtime + "/hypr/" + signature + "/.socket2.sock" : ""
  }

  Socket {
    path: root.eventSocket
    connected: root.eventSocket !== ""

    parser: SplitParser {
      onRead: function (line) {
        var text = String(line)
        if (text.indexOf("workspace>>") === 0) {
          root.glowColor = "#00ffdd"
          root.generation++
        } else if (text.indexOf("openlayer>>omarchy-notifications") === 0) {
          root.glowColor = "#ff2bd6"
          root.generation++
          // Soft notification ping. Best-effort and opt-out through the same
          // flag vp-sound.sh checks.
          Quickshell.execDetached(["vp-sound.sh", "notify"])
        }
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }
        color: "transparent"
        WlrLayershell.namespace: "vp-edge-glow"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        Item {
          id: edge

          anchors.fill: parent
          opacity: 0

          readonly property color tint: root.glowColor

          Rectangle {
            anchors {
              top: parent.top
              left: parent.left
              right: parent.right
            }
            height: 48
            gradient: Gradient {
              orientation: Gradient.Vertical
              GradientStop { position: 0.0; color: edge.tint }
              GradientStop { position: 0.18; color: Qt.rgba(edge.tint.r, edge.tint.g, edge.tint.b, 0.35) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }

          Rectangle {
            anchors {
              bottom: parent.bottom
              left: parent.left
              right: parent.right
            }
            height: 48
            gradient: Gradient {
              orientation: Gradient.Vertical
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.82; color: Qt.rgba(edge.tint.r, edge.tint.g, edge.tint.b, 0.35) }
              GradientStop { position: 1.0; color: edge.tint }
            }
          }

          Rectangle {
            anchors {
              top: parent.top
              bottom: parent.bottom
              left: parent.left
            }
            width: 48
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: edge.tint }
              GradientStop { position: 0.18; color: Qt.rgba(edge.tint.r, edge.tint.g, edge.tint.b, 0.35) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }

          Rectangle {
            anchors {
              top: parent.top
              bottom: parent.bottom
              right: parent.right
            }
            width: 48
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.82; color: Qt.rgba(edge.tint.r, edge.tint.g, edge.tint.b, 0.35) }
              GradientStop { position: 1.0; color: edge.tint }
            }
          }

          SequentialAnimation {
            id: flash

            NumberAnimation {
              target: edge
              property: "opacity"
              from: 0.0; to: 0.45
              duration: 90
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              target: edge
              property: "opacity"
              to: 0.0
              duration: 520
              easing.type: Easing.InCubic
            }
          }
        }

        Connections {
          target: root

          function onGenerationChanged() {
            flash.restart()
          }
        }
      }
    }
  }
}
