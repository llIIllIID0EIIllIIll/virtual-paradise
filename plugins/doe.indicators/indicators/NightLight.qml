import QtQuick
import ".."

BarIndicator {
  id: root

  readonly property var nightlightService: bar?.shell?.firstPartyServiceFor("omarchy.nightlight")

  active: nightlightService ? nightlightService.enabled : false
  activeText: "󰛨"
  inactiveText: "󰛩"
  activeTooltipText: "Night Light: ON (Eye Protection Active)"
  inactiveTooltipText: "Night Light: OFF (Click to Enable)"

  function toggle() {
    if (root.nightlightService) root.nightlightService.setNightlight(!root.active)
  }

  onPressed: function() { root.toggle() }
}
