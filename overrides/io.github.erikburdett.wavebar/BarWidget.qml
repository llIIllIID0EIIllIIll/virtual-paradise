import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.erikburdett.wavebar"

  readonly property var waveformService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var activePlayer: waveformService ? waveformService.activePlayer : null
  readonly property bool hasMedia: waveformService ? waveformService.hasMedia : false
  readonly property bool playing: waveformService ? waveformService.playing : false
  // All seven toggles parse the same way. `shell.json` is hand-editable, so a
  // toggle can arrive as the string "true" rather than a boolean; comparing
  // with `=== true` would read that as off here while the panel's own switch
  // read it as on, and the widget would disagree with its settings UI.
  readonly property bool showControls: String(setting("showControls", true)).toLowerCase() === "true"
  readonly property bool showTitle: String(setting("showTitle", true)).toLowerCase() === "true"
  readonly property bool showArtist: String(setting("showArtist", false)).toLowerCase() === "true"
  readonly property bool showFullTitle: String(setting("showFullTitle", false)).toLowerCase() === "true"
  readonly property bool groupControls: String(setting("groupControls", false)).toLowerCase() === "true"
  readonly property bool showCover: String(setting("showCover", false)).toLowerCase() === "true"
  readonly property bool hideWhenPaused: String(setting("hideWhenPaused", false)).toLowerCase() === "true"
  readonly property real waveformWidth: Math.min(240,
    Math.max(40, Number(setting("waveformWidth", 72)) || 72))
  readonly property string artUrl: waveformService ? waveformService.trackArtUrl : ""
  readonly property real maxTitleWidth: Math.min(320,
    Math.max(60, Number(setting("maxTitleWidth", 150)) || 150))

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool shouldShow: !hideWhenPaused || playing || hasMedia

  visible: shouldShow
  implicitWidth: shouldShow
    ? (vertical ? button.implicitWidth : mediaPill.width + 6 + (button.tooltipHovered ? 4 : 0))
    : 0
  implicitHeight: button.implicitHeight

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.settings = root.settings
    panelLoader.item.anchorItem = root
    panelLoader.item.hostWidget = root
    panelLoader.item.service = root.waveformService
  }

  function actionEnabled(action) {
    var player = activePlayer
    if (!player) return false
    if (action === "previous") return !!player.canGoPrevious
    if (action === "next") return !!player.canGoNext
    return !!(player.canTogglePlaying || player.canPlay || player.canPause)
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onWaveformServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // ─── Main Widget Button (standard pattern matching all other pills) ───────
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 2
    verticalPadding: 2
    tooltipText: (root.waveformService && root.hasMedia && root.waveformService.title)
      ? (root.waveformService.title
          + (root.waveformService.artist ? " — " + root.waveformService.artist : "")
          + "\nLeft: Open Player | Scroll: Prev/Next")
      : "No media\nLeft: Open Player"

    onPressed: function(b) {
      root.toggle()
    }
    onWheelMoved: function(delta) {
      if (!root.waveformService) return
      root.waveformService.runAction(delta > 0 ? "previous" : "next")
    }

    // ─── Glowing Neon Media Capsule Pill (same spec as clock/weather/cputemp) ─
    Rectangle {
      id: mediaPill
      visible: !root.vertical
      anchors.centerIn: parent
      width: mediaRow.implicitWidth + 20
      height: 28
      radius: 14

      // Playing → Miku Cyan glow / Idle → Neon Purple ghost
      color: root.playing
        ? Qt.rgba(0.0, 0.96, 0.83, 0.22)            // #00f5d4 Miku Cyan active glow
        : (button.tooltipHovered
          ? Qt.rgba(0.68, 0.53, 1.0, 0.16)           // #ad88ff Purple hover glow
          : Qt.rgba(0.68, 0.53, 1.0, 0.09))          // #ad88ff Purple resting ghost
      border.color: root.playing
        ? "#00f5d4"                                   // Miku Cyan border when playing
        : (root.opened
          ? "#ad88ff"                                 // Purple when panel open
          : (button.tooltipHovered ? "#ad88ff" : Qt.rgba(0.68, 0.53, 1.0, 0.40)))
      border.width: (root.playing || root.opened) ? 2 : 1
      scale: button.tooltipHovered ? 1.04 : 1

      Behavior on color { ColorAnimation { duration: 180 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }
      Behavior on border.width { NumberAnimation { duration: 150 } }
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

      // Outer Halo Glow Ring 1 — pulse when playing or panel open
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: mediaPill.radius + 3
        color: "transparent"
        border.color: root.playing ? "#00f5d4" : "#ad88ff"
        border.width: 1.8
        opacity: 0.85
        visible: root.playing || root.opened || button.tooltipHovered

        SequentialAnimation on opacity {
          running: root.playing || root.opened
          loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.95; duration: 800; easing.type: Easing.InOutQuad }
        }
      }

      // Outer Halo Glow Ring 2 — diffuse aura
      Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: mediaPill.radius + 6
        color: "transparent"
        border.color: root.playing ? "#00f5d4" : "#ad88ff"
        border.width: 1.5
        opacity: 0.60
        visible: root.playing || root.opened || button.tooltipHovered

        SequentialAnimation on opacity {
          running: root.playing || root.opened || button.tooltipHovered
          loops: Animation.Infinite
          NumberAnimation { to: 0.20; duration: 800; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.75; duration: 800; easing.type: Easing.InOutQuad }
        }
      }

      // ─── Pill Content Row ────────────────────────────────────────────────
      Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: 6

        // Prev button (shown left of waveform when !groupControls)
        Item {
          visible: root.showControls && !root.groupControls
          width: visible ? prevLeftBtn.implicitWidth : 0
          height: 18
          anchors.verticalCenter: parent.verticalCenter

          Button {
            id: prevLeftBtn
            anchors.fill: parent
            enabled: root.actionEnabled("previous")
            opacity: enabled ? 1 : 0.35
            iconText: "󰒮"
            foreground: root.playing ? "#00f5d4" : "#ad88ff"
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            iconSize: Style.font.body
            horizontalPadding: 2
            verticalPadding: 0
            onClicked: if (root.waveformService) root.waveformService.runAction("previous")
          }
        }

        // Waveform visualizer
        Waveform {
          width: root.waveformWidth
          height: 18
          barCount: Math.min(48, Math.max(10, Math.round(width / 4)))
          samples: root.waveformService ? root.waveformService.samples : []
          active: root.playing
          live: root.waveformService ? root.waveformService.receivingFrames : false
          foreground: root.playing ? "#00f5d4" : "#ad88ff"
          anchors.verticalCenter: parent.verticalCenter
        }

        // Album art (optional)
        Item {
          visible: root.showCover && root.artUrl !== "" && !root.vertical
          width: 18
          height: 18
          clip: true
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.artUrl
          }
        }

        // Track title
        Item {
          visible: root.showTitle && !root.vertical
          width: visible ? (root.showFullTitle
            ? titleText.implicitWidth
            : Math.min(root.maxTitleWidth, titleText.implicitWidth)) : 0
          height: titleText.implicitHeight
          clip: true
          anchors.verticalCenter: parent.verticalCenter

          MarqueeText {
            id: titleText
            width: parent.width
            height: implicitHeight
            text: {
              if (root.waveformService && root.hasMedia && root.waveformService.title) {
                var title = root.waveformService.title || ""
                if (root.showArtist && root.waveformService.artist) {
                  return title + " \u2014 " + root.waveformService.artist
                }
                return title
              }
              return "No media"
            }
            foreground: "#ffffff"
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            fontPixelSize: Style.font.bodySmall
            active: !root.opened && !root.showFullTitle
          }
        }

        // Play/Pause button
        Item {
          visible: root.showControls
          width: visible ? playBtn.implicitWidth : 0
          height: 18
          anchors.verticalCenter: parent.verticalCenter

          Button {
            id: playBtn
            anchors.fill: parent
            enabled: root.actionEnabled("playPause")
            opacity: enabled ? 1 : 0.35
            iconText: root.playing ? "󰏤" : "󰐊"
            foreground: root.playing ? "#00f5d4" : "#ad88ff"
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            iconSize: Style.font.body
            horizontalPadding: 2
            verticalPadding: 0
            onClicked: if (root.waveformService) root.waveformService.runAction("playPause")
          }
        }

        // Next button (grouped controls only)
        Item {
          visible: root.showControls && root.groupControls
          width: visible ? nextBtn.implicitWidth : 0
          height: 18
          anchors.verticalCenter: parent.verticalCenter

          Button {
            id: nextBtn
            anchors.fill: parent
            enabled: root.actionEnabled("next")
            opacity: enabled ? 1 : 0.35
            iconText: "󰒭"
            foreground: root.playing ? "#00f5d4" : "#ad88ff"
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            iconSize: Style.font.body
            horizontalPadding: 2
            verticalPadding: 0
            onClicked: if (root.waveformService) root.waveformService.runAction("next")
          }
        }
      }
    }

    // ─── Vertical layout fallback ─────────────────────────────────────────
    Column {
      visible: root.vertical
      anchors.centerIn: parent
      spacing: 3

      Button {
        visible: root.showControls
        enabled: root.actionEnabled("playPause")
        iconText: root.playing ? "󰏤" : "󰐊"
        foreground: root.playing ? "#00f5d4" : "#ad88ff"
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        iconSize: Style.font.body
        horizontalPadding: 3
        verticalPadding: 2
        onClicked: if (root.waveformService) root.waveformService.runAction("playPause")
      }

      Item {
        width: 20
        height: 54

        Waveform {
          anchors.centerIn: parent
          width: parent.height
          height: parent.width
          rotation: 90
          barCount: 13
          samples: root.waveformService ? root.waveformService.samples : []
          active: root.playing
          live: root.waveformService ? root.waveformService.receivingFrames : false
          foreground: root.playing ? "#00f5d4" : "#ad88ff"
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggle()
        }
      }
    }
  }
}
