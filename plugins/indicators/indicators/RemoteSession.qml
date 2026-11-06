import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."

// Ported from Omarchy 4.5. Warns while a remote session (gliff) is connected.
BarIndicator {
  id: root

  property var remoteSessionService: null

  function refreshService() {
    remoteSessionService = root.firstPartyService("omarchy.remote-session")
  }
  onBarChanged: refreshService()
  Component.onCompleted: refreshService()
  readonly property var peers: remoteSessionService && Array.isArray(remoteSessionService.peers) ? remoteSessionService.peers : []

  active: remoteSessionService ? remoteSessionService.active : false
  activeText: "󰢹"
  activeTooltipText: peers.length > 0 ? Commons.I18n.t("bar.remoteSessionFrom").arg(peers.join(", ")) : Commons.I18n.t("bar.remoteSession")
  useActiveColor: true
  activeColor: Commons.Color.urgent
  revealWhenInactive: false

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() {
      if (root.remoteSessionService) root.remoteSessionService.refresh()
    }
  }
}
