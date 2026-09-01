import QtQuick
import qs.Commons
import qs.Ui

BarIconButton {
  id: root

  property string moduleName: ""
  property var settings: ({})
  property string activeText: ""
  property string inactiveText: activeText
  property string activeTooltipText: ""
  property string inactiveTooltipText: activeTooltipText
  property string indicatorBlock: "single"
  property var indicatorHost: null
  property var activeOverride: null
  readonly property bool effectiveActive: activeOverride === null || activeOverride === undefined ? active : activeOverride === true
  readonly property bool belongsInBlock: indicatorBlock === "active" ? effectiveActive : (indicatorBlock === "inactive" ? !effectiveActive : true)
  readonly property bool inactiveRevealed: !effectiveActive && !!indicatorHost && indicatorHost.revealInactiveIndicators

  function extractData(raw) {
    return Util.parseModuleJson(raw)
  }

  function syncIndicatorOpacity() {
    root.opacity = !belongsInBlock ? 0 : (effectiveActive ? 1.0 : (inactiveRevealed ? 0.70 : (tooltipHovered ? 1.0 : 0.65)))
  }

  Component.onCompleted: syncIndicatorOpacity()
  onActiveChanged: syncIndicatorOpacity()
  onEffectiveActiveChanged: syncIndicatorOpacity()
  onBarChanged: syncIndicatorOpacity()
  onBelongsInBlockChanged: syncIndicatorOpacity()
  onInactiveRevealedChanged: syncIndicatorOpacity()
  onIndicatorBlockChanged: syncIndicatorOpacity()
  onTooltipHoveredChanged: syncIndicatorOpacity()

  visible: belongsInBlock && (text !== "" || keepSpace)
  text: effectiveActive ? activeText : inactiveText
  tooltipText: effectiveActive ? activeTooltipText : inactiveTooltipText
  keepSpace: true
  dimmed: false
  concealed: false
  interactive: true
  useActiveColor: true
  activeColor: "#00f5d4"
  foreground: effectiveActive ? (tooltipHovered ? "#00ff88" : "#00f5d4") : (tooltipHovered ? "#ffffff" : "#7091a4")
  maintainIndicatorReveal: indicatorBlock === "inactive"
  revealHost: indicatorHost
  fontSize: Style.font.caption + 1
  horizontalMargin: 2
  verticalPadding: 2
  scale: tooltipHovered ? 1.15 : 1.0

  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
