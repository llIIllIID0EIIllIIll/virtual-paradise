import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "doe.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("doe.media") || bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool isPlaying: hasMedia && activePlayer.isPlaying
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property real maxLabelWidth: Style.spaceReal(180)

  property bool popupOpen: false
  function close() { popupOpen = false }

  property var barValues: [0, 0, 0, 0, 0, 0]
  property bool audioActive: false
  readonly property bool tooltipHovered: visible && mouseArea.containsMouse

  // Live Cava Frequency Spectrum Process
  Process {
    id: cavaProc
    command: ["bash", "-c", "cava -p \"$HOME/.config/cava/config_bar\" 2>/dev/null || cava 2>/dev/null"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var str = line.trim()
        if (str === "") return
        var parts = str.split(";").filter(function(x) { return x !== "" })
        if (parts.length >= 6) {
          var vals = []
          var total = 0
          for (var i = 0; i < 6; i++) {
            var v = parseInt(parts[i], 10) || 0
            vals.push(v)
            total += v
          }
          root.barValues = vals
          root.audioActive = total > 0
        }
      }
    }
  }

  visible: true
  implicitWidth: row.implicitWidth + 24
  implicitHeight: root.barSize

  // Glowing frosted acrylic capsule
  Rectangle {
    id: mediaPill
    anchors.centerIn: parent
    width: parent.width
    height: 28
    radius: 14
    color: (root.audioActive || root.isPlaying || root.popupOpen)
      ? Qt.rgba(0.0, 0.96, 0.83, 0.25)
      : (mouseArea.containsMouse ? Qt.rgba(0.0, 1.0, 0.53, 0.12) : Qt.rgba(1.0, 1.0, 1.0, 0.04))
    border.color: root.popupOpen
      ? "#00ff88"
      : (root.audioActive || root.isPlaying
        ? "#00f5d4"
        : (mouseArea.containsMouse ? "#00ff88" : Qt.rgba(1.0, 1.0, 1.0, 0.15)))
    border.width: (root.audioActive || root.isPlaying || root.popupOpen) ? 2 : 1

    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }
    Behavior on border.width { NumberAnimation { duration: 150 } }

    // Outer Halo Glow Ring when Audio is Playing or Popup is Open
    Rectangle {
      anchors.fill: parent
      anchors.margins: -3
      radius: mediaPill.radius + 3
      color: "transparent"
      border.color: root.popupOpen ? "#00ff88" : "#00f5d4"
      border.width: 1.8
      opacity: 0.85
      visible: root.audioActive || root.isPlaying || root.popupOpen

      SequentialAnimation on opacity {
        running: root.audioActive || root.isPlaying || root.popupOpen
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 0.95; duration: 800; easing.type: Easing.InOutQuad }
      }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 7

    // Play/Pause Icon
    Text {
      id: playGlyph
      anchors.verticalCenter: parent.verticalCenter
      text: root.isPlaying ? "󰏤" : "󰐊"
      color: root.isPlaying || root.audioActive ? "#00f5d4" : "#7091a4"
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true

      Behavior on color { ColorAnimation { duration: 160 } }
    }

    // Real Live Cava Visualizer Bars
    Row {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2.5
      width: 6 * 2.5 + 5 * 2.5
      height: 14

      Repeater {
        model: [
          { color: "#00f5d4" },
          { color: "#00f5d4" },
          { color: "#00ff88" },
          { color: "#00ff88" },
          { color: "#ffb7d5" },
          { color: "#ffb7d5" }
        ]

        Rectangle {
          required property var modelData
          required property int index
          width: 2.5
          height: Math.max(2.5, Math.min(14, (root.barValues[index] / 8) * 14))
          radius: 1.25
          color: modelData.color
          anchors.verticalCenter: parent.verticalCenter

          Behavior on height {
            NumberAnimation { duration: 55; easing.type: Easing.Linear }
          }
        }
      }
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical

      Text {
        id: labelText
        text: root.hasMedia ? (root.title + (root.artist ? "  ·  " + root.artist : "")) : (root.audioActive ? "Live Audio" : "Virtual☆Paradise")
        color: (root.hasMedia || root.audioActive) ? "#ffffff" : "#7091a4"
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: root.hasMedia || root.audioActive
        anchors.verticalCenter: parent.verticalCenter

        property bool needsScroll: implicitWidth > scrollClip.width

        NumberAnimation on x {
          id: scrollAnim
          running: labelText.needsScroll && !root.popupOpen
          loops: Animation.Infinite
          duration: Math.max(5000, labelText.implicitWidth * 30)
          from: 0
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: (root.hasMedia || root.audioActive) ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false)
      } else if (mouse.button === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
      } else {
        if (root.mediaService) root.mediaService.runAction("playPause", false)
      }
    }
    onWheel: function(wheel) {
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
    }
    onEntered: {
      if (root.bar) {
        root.bar.showTooltip(root, root.hasMedia
          ? (root.title + (root.artist ? " — " + root.artist : "") + "\nLeft: Play/Pause | Middle: Next | Right: Media Panel | Scroll: Track")
          : (root.audioActive ? "Live Audio (Playing)\nRight: Media Panel" : "Virtual☆Paradise Sound\nRight: Media Panel"))
      }
    }
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // Detailed Media Controller PopupCard
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: "#00f5d4"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            text: root.title || (root.audioActive ? "Live System Audio" : "Virtual☆Paradise Sound")
            color: "#ffffff"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.artist || (root.audioActive ? "PipeWire Audio Stream" : "No media metadata")
            color: "#7091a4"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: root.isPlaying ? "󰏤" : "󰐊"
          foreground: "#00f5d4"
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
