import QtQuick
import qs.Commons
import qs.Ui
import "ui"
import "ui/Format.js" as Format

// Bar entry for X-Ray: a launcher button that opens the inspector panel.
//
// Upstream draws the glyph in the bar's foreground, which is the near-white
// text colour. Every other icon on this bar sits on the theme accent, so the
// X-Ray mark read as a different design rather than another widget. Only the
// glyph colour is changed here; the panel and contract are untouched so they
// keep updating with the plugin.
BarWidget {
  id: root
  objectName: "xrayBarWidget"

  XRayContract { id: contract }
  XRayTheme { id: theme }

  moduleName: contract.pluginId
  implicitWidth: launcher.implicitWidth
  implicitHeight: launcher.implicitHeight

  BarIconButton {
    id: launcher
    objectName: "xrayBarLauncher"

    anchors.fill: parent
    bar: root.bar
    text: Format.icon("xray")
    fontFamily: theme.dataFont
    foreground: Color.accent
    tooltipText: "Trace system activity"
    onPressed: function(button) {
      if (!root.bar || !root.bar.shell)
        return;
      root.bar.shell.toggle(root.moduleName, "{}")
    }
  }
}
