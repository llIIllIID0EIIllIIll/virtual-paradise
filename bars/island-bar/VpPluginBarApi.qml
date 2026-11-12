import QtQuick

// Bar surface exposed to an installed widget. This is the upstream Ui
// PluginBarApi plus one addition: `firstPartyService(id)`, which resolves the
// narrow first-party service proxies (idle, nightlight, notifications, media,
// remote session) for the widget this bar hosts.
//
// The package facade gates those proxies on the *widget* manifest carrying the
// "bar" kind, which no bar widget does, so a hosted indicator could never
// reach its service. The trusted built-in bar resolves the proxies itself and
// hands them to its widgets through this accessor.
QtObject {
  id: api

  required property string pluginId
  required property string moduleName
  property var shell: null

  property color foreground: "transparent"
  property color barForeground: "transparent"
  property color background: "transparent"
  property color urgent: "transparent"
  // Semantic palette written by theme-switcher.sh / vp-palette.sh. Widgets
  // read these through root.bar.* so a live custom palette recolors them
  // without a shell restart.
  property color accentColor: "transparent"
  property color secondaryColor: "transparent"
  property color greenColor: "transparent"
  property color warmColor: "transparent"
  property color pinkColor: "transparent"
  property color hotColor: "transparent"
  property color paletteForeground: "transparent"
  property string fontFamily: ""
  property string position: "top"
  property bool vertical: false
  property int barSize: 0
  property bool transparent: false
  property bool foregroundAnimationEnabled: true
  property bool centerSectionRevealHeld: false
  property bool traySectionDragActive: false
  property bool traySectionPopoutOpen: false
  property bool _centerHoverRevealSuppressed: false
  readonly property bool centerHoverRevealSuppressed: _centerHoverRevealSuppressed
  property var activePopout: null
  property var clickTargets: []
  property var layoutConfig: ({})
  readonly property var foreignPopoutMarker: ({ foreign: true })

  property var _showTooltip: null
  property var _hideTooltip: null
  property var _registerClickTarget: null
  property var _unregisterClickTarget: null
  property var _requestPopout: null
  property var _releasePopout: null
  property var _notePopoutCard: null
  property var _popoutCardFor: null
  property var _switchPanelFrom: null
  property var _targetBelongsToWindow: null
  property var _moduleWidgets: null
  property var _run: null
  property var _setCenterHoverRevealSuppressed: null
  property var _firstPartyService: null

  function setCenterHoverRevealSuppressed(value) {
    if (_setCenterHoverRevealSuppressed) _setCenterHoverRevealSuppressed(!!value)
  }

  function showTooltip(target, text) {
    if (_showTooltip) _showTooltip(target, String(text || ""))
  }

  function hideTooltip(target) {
    if (_hideTooltip) _hideTooltip(target)
  }

  function registerClickTarget(target) {
    if (_registerClickTarget) _registerClickTarget(target)
  }

  function unregisterClickTarget(target) {
    if (_unregisterClickTarget) _unregisterClickTarget(target)
  }

  function requestPopout(owner) {
    if (_requestPopout) _requestPopout(owner)
  }

  function releasePopout(owner) {
    if (_releasePopout) _releasePopout(owner)
  }

  function notePopoutCard(card) {
    if (_notePopoutCard) _notePopoutCard(card)
  }

  // Where the last panel's card stood, if it was in this owner's section.
  function popoutCardFor(owner) {
    return _popoutCardFor ? _popoutCardFor(owner) : null
  }

  function switchPanelFrom(owner, direction) {
    return _switchPanelFrom ? _switchPanelFrom(owner, direction) : false
  }

  function targetBelongsToWindow(target, window) {
    return _targetBelongsToWindow ? _targetBelongsToWindow(target, window) : false
  }

  function moduleWidgets(id) {
    return _moduleWidgets ? _moduleWidgets(String(id || "")) : []
  }

  function run(command) {
    if (_run) _run(String(command || ""))
  }

  // Narrow service proxy for this widget; null while the service is absent.
  function firstPartyService(id) {
    return _firstPartyService ? _firstPartyService(String(id || "")) : null
  }
}
