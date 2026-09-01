import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "__USER__.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
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

  implicitWidth: wsContainer.width + 4
  implicitHeight: root.barSize

  // Single elegant unified workspace dock
  Rectangle {
    id: wsContainer
    anchors.centerIn: parent
    width: rowLayout.implicitWidth + 16
    height: 26
    radius: 13
    color: Qt.rgba(1.0, 1.0, 1.0, 0.04)
    border.color: Qt.rgba(0.0, 0.96, 0.83, 0.25)
    border.width: 1

    Row {
      id: rowLayout
      anchors.centerIn: parent
      spacing: 6

      Repeater {
        model: root.workspaceIds()

        WidgetButton {
          id: wsBtn
          required property int modelData

          readonly property var workspace: root.workspaceById(modelData)
          readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
          readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

          bar: root.bar
          text: ""
          labelVisible: false
          hasVisualContent: true
          tooltipText: "Workspace " + modelData + (focused ? " (Active)" : (occupied ? " (" + (workspace ? workspace.toplevels.values.length : 0) + " windows)" : " (Empty)")) + "\nClick to Switch"
          horizontalMargin: 0
          verticalPadding: 0
          fixedWidth: 20
          fixedHeight: 24
          onPressed: function() { root.focusWorkspace(modelData) }

          // Clean, unboxed minimalist typography
          Item {
            anchors.fill: parent

            Text {
              anchors.centerIn: parent
              text: wsBtn.focused
                ? ("★" + (modelData === 10 ? "0" : String(modelData)))
                : (wsBtn.occupied ? ("●" + (modelData === 10 ? "0" : String(modelData))) : String(modelData))
              color: wsBtn.focused
                ? "#00f5d4"
                : (wsBtn.tooltipHovered ? "#ffffff" : (wsBtn.occupied ? "#00ff88" : "#556d7d"))
              font.family: root.bar.fontFamily
              font.pixelSize: wsBtn.focused ? (Style.font.body - 1) : (Style.font.caption)
              font.bold: wsBtn.focused || wsBtn.occupied
              scale: wsBtn.tooltipHovered ? 1.15 : 1.0

              Behavior on color { ColorAnimation { duration: 150 } }
              Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }

            // Glowing underline indicator on active workspace
            Rectangle {
              visible: wsBtn.focused
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottomMargin: 1
              width: 12
              height: 2
              radius: 1
              color: "#00f5d4"
            }
          }
        }
      }
    }
  }
}
