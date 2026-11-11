import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

BarIconButton {
  id: root

  property string moduleName: ""
  // Palette from the island bar; fallbacks keep the component usable alone.
  readonly property color accentColor: root.bar && root.bar.accentColor !== undefined ? root.bar.accentColor : Color.accent
  readonly property color greenColor: root.bar && root.bar.greenColor !== undefined ? root.bar.greenColor : "#00ff88"
  readonly property color warmColor: root.bar && root.bar.warmColor !== undefined ? root.bar.warmColor : "#ffe066"
  readonly property color pinkColor: root.bar && root.bar.pinkColor !== undefined ? root.bar.pinkColor : "#ffb7d5"
  readonly property color hotColor: root.bar && root.bar.hotColor !== undefined ? root.bar.hotColor : "#ff0055"
  property var settings: ({})
  property string activeText: ""
  property string inactiveText: activeText
  property string activeTooltipText: ""
  property string inactiveTooltipText: activeTooltipText
  property string indicatorBlock: "single"
  property var indicatorHost: null
  property var activeOverride: null
  // Upstream API: an indicator can opt out of the hover reveal (a remote
  // session that is off should stay hidden rather than show as inactive).
  property bool revealWhenInactive: true
  readonly property bool effectiveActive: activeOverride === null || activeOverride === undefined ? active : activeOverride === true
  readonly property bool belongsInBlock: indicatorBlock === "active" ? effectiveActive : (indicatorBlock === "inactive" ? !effectiveActive : true)
  readonly property bool inactiveRevealed: !effectiveActive && revealWhenInactive && !!indicatorHost && indicatorHost.revealInactiveIndicators

  function extractData(raw) {
    return Util.parseModuleJson(raw)
  }

  // First-party service proxy for this widget. The theme bar resolves it
  // directly because the package facade gates the proxies on the widget
  // manifest carrying the "bar" kind; fall back to the facade for older
  // bar builds.
  function firstPartyService(id) {
    if (bar && typeof bar.firstPartyService === "function") return bar.firstPartyService(id)
    if (bar && bar.shell && typeof bar.shell.firstPartyServiceFor === "function")
      return bar.shell.firstPartyServiceFor(id)
    return null
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
  activeColor: root.accentColor
  foreground: effectiveActive ? (tooltipHovered ? root.greenColor : root.accentColor) : (tooltipHovered ? "#ffffff" : "#9684c0")
  maintainIndicatorReveal: indicatorBlock === "inactive"
  revealHost: indicatorHost
  fontSize: Style.font.caption + 1
  horizontalMargin: 2
  verticalPadding: 2
  scale: tooltipHovered ? 1.15 : 1.0

  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

  // An active indicator glows and breathes, so a state that is easy to miss in
  // a row of glyphs still reads at a glance.
  RectangularShadow {
    anchors.fill: parent
    anchors.margins: -2
    radius: Math.min(width, height) / 2
    blur: 10
    spread: 0
    offset: Qt.vector2d(0, 0)
    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
    visible: root.effectiveActive
    z: -1

    SequentialAnimation on opacity {
      running: root.effectiveActive
      loops: Animation.Infinite
      NumberAnimation {
        from: 0.55; to: 1.0
        duration: 1400; easing.type: Easing.InOutSine
      }
      NumberAnimation {
        from: 1.0; to: 0.55
        duration: 1400; easing.type: Easing.InOutSine
      }
    }
  }
}
