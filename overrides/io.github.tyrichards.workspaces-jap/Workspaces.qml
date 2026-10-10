import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.tyrichards.workspaces-jap"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++)
      if (values[i].id === id) return values[i]
    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function workspaceLabel(id) {
    return ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][id]
  }

  readonly property real outerPadding: Style.spaceReal(6)
  readonly property real workspaceGap: Style.spaceReal(2)

  implicitWidth: root.vertical ? root.barSize : dock.width
  implicitHeight: root.vertical ? dock.height : root.barSize

  Rectangle {
    id: dock
    anchors.centerIn: parent
    width: root.vertical ? root.barSize : row.implicitWidth + outerPadding * 2
    height: root.vertical ? column.implicitHeight + outerPadding * 2 : 28
    radius: 14
    color: Qt.rgba(1.0, 1.0, 1.0, 0.04)
    border.color: Qt.rgba(0.0, 0.96, 0.83, 0.28)
    border.width: 1

    Column {
      id: column
      anchors.centerIn: parent
      spacing: workspaceGap
      visible: root.vertical

      Repeater {
        model: root.workspaceIds()
        delegate: workspaceButton
      }
    }

    Row {
      id: row
      anchors.centerIn: parent
      spacing: workspaceGap
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
        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: root.workspaceLabel(modelData)
        labelVisible: false
        hasVisualContent: true
        horizontalMargin: 0
        verticalPadding: 0
        fixedWidth: root.vertical ? root.barSize : 22
        fixedHeight: root.vertical ? 22 : 26
        opacity: focused || occupied ? 1.0 : 0.55
        tooltipText: "Workspace " + text + (focused ? " (Active)" : (occupied ? " (Occupied)" : " (Empty)")) + "\nClick to Switch"
        onPressed: function() { root.focusWorkspace(modelData) }

        Item {
          anchors.fill: parent

          Text {
            anchors.centerIn: parent
            text: root.workspaceLabel(modelData)
            color: wsBtn.focused
              ? Color.accent
              : (wsBtn.tooltipHovered
                ? (root.bar ? root.bar.barForeground : Color.foreground)
                : (wsBtn.occupied
                  ? "#00ff88"
                  : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.8)))
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: wsBtn.focused ? Style.font.body : Style.font.caption
            font.bold: wsBtn.focused || wsBtn.occupied
            renderType: Text.NativeRendering
            scale: wsBtn.tooltipHovered ? 1.15 : 1.0

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
          }

          Rectangle {
            visible: wsBtn.focused
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 14
            height: 2
            radius: 1
            color: Color.accent
          }
        }
      }
    }
  }
}
