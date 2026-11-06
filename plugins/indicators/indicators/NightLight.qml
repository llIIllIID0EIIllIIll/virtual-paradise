import QtQuick
import ".."

BarIndicator {
  id: root

  property var nightlightService: null

  function refreshService() {
    nightlightService = root.firstPartyService("omarchy.nightlight")
  }
  onBarChanged: refreshService()
  Component.onCompleted: refreshService()

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
