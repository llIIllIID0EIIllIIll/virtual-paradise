pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Japanese numeral workspace switcher.
//
// Replaces io.github.tyrichards.workspaces-jap. Same read model - the first
// five workspaces are always listed, any occupied one up to ten is added - but
// the chrome follows this theme instead of a fixed teal border, and the active
// workspace is marked with the accent plus an underline rather than a colour
// alone, so it still reads for anyone who cannot tell the hues apart.
BarWidget {
  id: root
  moduleName: "__USER__.workspaces"

  readonly property int baseCount: Number(setting("baseWorkspaces", 5))
  readonly property int maxWorkspace: Number(setting("maxWorkspace", 10))
  readonly property bool showNumerals: setting("numerals", true) !== false

  readonly property real outerPad: Style.space(3)
  readonly property real gap: Style.space(1)

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++)
      if (values[i].id === id) return values[i]
    return null
  }

  function workspaceIds() {
    var ids = []
    for (var i = 1; i <= baseCount; i++) ids.push(i)
    var values = Hyprland.workspaces.values
    for (var j = 0; j < values.length; j++) {
      var id = values[j].id
      if (id > 0 && id <= maxWorkspace && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function (left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch "
      + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function labelFor(id) {
    if (showNumerals && id >= 1 && id <= 10)
      return ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][id]
    return String(id)
  }

  function occupied(id) {
    var ws = workspaceById(id)
    return ws !== null && ws.toplevels.values.length > 0
  }

  function focused(id) {
    return Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === id
  }

  implicitWidth: root.vertical ? root.barSize : pill.width
  implicitHeight: root.vertical ? pill.height : root.barSize

  Rectangle {
    id: pill

    anchors.centerIn: parent
    width: root.vertical ? root.barSize : row.implicitWidth + root.outerPad * 2
    height: root.vertical ? column.implicitHeight + root.outerPad * 2 : 28
    radius: 14
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.06)
    border.width: 1
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)

    Column {
      id: column

      anchors.centerIn: parent
      spacing: root.gap
      visible: root.vertical

      Repeater {
        model: root.workspaceIds()
        delegate: workspaceButton
      }
    }

    Row {
      id: row

      anchors.centerIn: parent
      spacing: root.gap
      visible: !root.vertical

      Repeater {
        model: root.workspaceIds()
        delegate: workspaceButton
      }
    }

    Component {
      id: workspaceButton

      WidgetButton {
        id: wsBtn

        required property int modelData

        readonly property bool isFocused: root.focused(modelData)
        readonly property bool isOccupied: root.occupied(modelData)

        bar: root.bar
        text: root.labelFor(modelData)
        labelVisible: false
        hasVisualContent: true
        horizontalMargin: 0
        verticalPadding: 0
        fixedWidth: root.vertical ? root.barSize : 24
        fixedHeight: root.vertical ? 24 : 26
        tooltipText: "Workspace " + modelData
          + (isFocused ? " (active)" : (isOccupied ? " (occupied)" : " (empty)"))
          + "\nClick to switch"

        onPressed: function () { root.focusWorkspace(modelData) }

        Item {
          anchors.fill: parent

          Text {
            id: numeral

            anchors.centerIn: parent
            text: root.labelFor(wsBtn.modelData)
            // Three states from the palette alone: the shell's Color singleton
            // has no green, so occupied is full foreground and empty is the
            // same colour at reduced alpha, with accent reserved for active.
            color: wsBtn.isFocused
              ? Color.accent
              : wsBtn.tooltipHovered
                ? (root.bar ? root.bar.barForeground : Color.foreground)
                : wsBtn.isOccupied
                  ? (root.bar ? root.bar.barForeground : Color.foreground)
                  : Qt.rgba(Color.foreground.r, Color.foreground.g,
                      Color.foreground.b, 0.45)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: wsBtn.isFocused ? Style.font.body : Style.font.caption
            font.bold: wsBtn.isFocused || wsBtn.isOccupied
            renderType: Text.NativeRendering
            scale: wsBtn.tooltipHovered ? 1.15 : 1.0

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
          }

          // Underline carries the active state on its own, so the accent colour
          // is decoration rather than the only signal.
          Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 14
            height: 2
            radius: 1
            color: Color.accent
            visible: wsBtn.isFocused
          }
        }
      }
    }
  }
}
