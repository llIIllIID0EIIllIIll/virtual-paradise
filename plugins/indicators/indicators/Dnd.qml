import QtQuick
import qs.Commons
import ".."

BarIndicator {
  id: root

  property var notificationService: null

  function refreshService() {
    notificationService = root.firstPartyService("omarchy.notifications")
  }
  onBarChanged: refreshService()
  Component.onCompleted: refreshService()
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂚"
  activeTooltipText: "Do Not Disturb: ON (Notifications Silenced)"
  inactiveTooltipText: "Do Not Disturb: OFF"

  onPressed: function() {
    if (root.notificationService) {
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    }
  }
}
