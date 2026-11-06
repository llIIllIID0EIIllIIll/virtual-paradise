import QtQuick
import ".."

BarIndicator {
  id: root

  property var idleService: null

  function refreshService() {
    idleService = root.firstPartyService("omarchy.idle")
  }
  onBarChanged: refreshService()
  Component.onCompleted: refreshService()

  active: idleService ? idleService.stayAwake : false
  activeText: "󰅶"
  inactiveText: "󰾪"
  activeTooltipText: "Stay Awake: ON (Screen Sleep Inhibited)"
  inactiveTooltipText: "Stay Awake: OFF (Click to Prevent Sleep)"

  function toggle() {
    if (root.idleService) root.idleService.setIdleEnabled(root.active)
  }

  onPressed: function() { root.toggle() }
}
