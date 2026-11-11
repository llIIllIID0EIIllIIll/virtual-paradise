import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// One dropdown for the specialized plugins, plus a compact settings/health
// view. The specialized widgets stay in the bar layout but hidden
// (`"hidden": true`), so their panels can still open from the bar; this menu
// is the visible entry point. The gear switches the same panel to settings, so
// the theme gets a GUI for the options that used to require editing shell.json.
Panel {
  id: root

  moduleName: "__USER__.tools"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool showSettings: false
  property bool verifyRunning: false
  property string verifyText: ""

  readonly property string home: Quickshell.env("HOME")
  readonly property color fg: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property var tools: [
    { id: "io.github.randazraik.xray", label: "X-Ray", icon: "󰗇", hint: "Screen lens" },
    { id: "io.github.grichard99.omaproton-vpn", label: "OmaProton VPN", icon: "󰦝", hint: "VPN" },
    { id: "io.github.kristoferlund.webcam", label: "Webcam controls", icon: "󰄀", hint: "Camera" },
    { id: "crmne.hyprmoncfg", label: "Displays", icon: "󰍹", hint: "Monitor config" },
    { id: "io.github.jeffcortez23.omarchy-projector-cast", label: "Projector & Cast", icon: "󰐧", hint: "Screen mirroring" },
    { id: "ssupt.bluetooth-audio", label: "Bluetooth audio", icon: "󰂯", hint: "Devices" }
  ]

  function activate(tool) {
    if (root.bar) root.bar.run("omarchy-shell shell toggle " + tool.id)
    root.close()
  }

  // The weather entry owns autoLocation. Find the live entry instead of
  // assuming it stays in the centre section.
  readonly property var weatherConfig: {
    if (!root.bar || !root.bar.layoutConfig) return null
    var layout = root.bar.layoutConfig
    var sections = [layout.left || [], layout.center || [], layout.right || []]
    for (var s = 0; s < sections.length; s++) {
      for (var i = 0; i < sections[s].length; i++) {
        var entry = sections[s][i]
        if (entry && String(entry.id || "").endsWith(".weather")) return entry
      }
    }
    return null
  }
  readonly property bool weatherAuto: root.weatherConfig ? root.weatherConfig.autoLocation === true : false

  // Write one bar-level key through the host so shell.json stays valid and
  // the host can reload its in-memory copy.
  function setBarOption(key, value) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.mutateShellConfig !== "function") return
    root.bar.shell.mutateShellConfig(function(config) {
      if (!config.bar) config.bar = {}
      config.bar[key] = value
    })
  }

  function setWeatherAuto(value) {
    var entry = root.weatherConfig
    if (!entry || !root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var next = { id: entry.id, autoLocation: value }
    for (var key in entry) {
      if (key !== "id" && key !== "autoLocation") next[key] = entry[key]
    }
    root.bar.shell.updateEntryInline(entry.id, next)
  }

  function run(command) {
    if (root.bar) root.bar.run(command)
  }

  function setVariant(name) {
    root.run(root.home + "/.local/bin/theme-switcher.sh " + name)
  }

  function toggleWallpaper() {
    root.run(root.home + "/.local/bin/toggle_live_wallpaper.sh")
  }

  function toggleSound() {
    root.run(root.home + "/.local/bin/vp-sound.sh toggle")
  }

  function diagnose() {
    root.run("omarchy-launch-terminal --hold " + root.home + "/.local/bin/paradise-diagnose")
  }

  function verifyPins() {
    root.verifyText = "Checking pinned plugins…"
    root.verifyRunning = true
    verifyProc.running = true
  }

  function repairBar() {
    root.run("bash " + root.home + "/.config/omarchy/hooks/post-update.d/virtual-paradise.sh")
  }

  function openLogs() {
    root.run("omarchy-launch-terminal --hold journalctl --user -b -f")
  }

  Process {
    id: verifyProc

    command: ["bash", "-lc", root.home + "/.local/bin/paradise-plugin-update --verify"]
    running: false

    stdout: StdioCollector {
      id: verifyOut
      waitForEnd: true
      onStreamFinished: {
        var value = String(verifyOut.text || "").trim()
        if (value !== "") root.verifyText = value.split("\n").slice(-6).join("\n")
      }
    }

    stderr: StdioCollector {
      id: verifyErr
      waitForEnd: true
    }

    onExited: function(exitCode) {
      root.verifyRunning = false
      if (root.verifyText === "Checking pinned plugins…" && verifyErr.text)
        root.verifyText = String(verifyErr.text).trim()
      if (exitCode !== 0 && root.verifyText === "Checking pinned plugins…")
        root.verifyText = "Verify failed; open Diagnostics for the full report."
    }
  }

  KeyboardPanel {
    id: panel

    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(root.showSettings ? 400 : 330))
    contentHeight: panel.fittedContentHeight(root.showSettings ? 560 : toolsColumn.implicitHeight)

    // ---- Tools view -------------------------------------------------------
    Column {
      id: toolsColumn

      visible: !root.showSettings
      width: parent.width
      spacing: Style.space(4)

      Item {
        width: parent.width
        height: Style.space(20)

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "TOOLS"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          Accessible.name: "Tools"
        }

        PanelActionButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰒓"
          tooltipText: "Open settings"
          foreground: root.fg
          fontFamily: root.ff
          focusable: true
          Accessible.name: "Open settings"
          onClicked: root.showSettings = true
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: root.fg
        opacity: 0.08
      }

      Repeater {
        model: root.tools

        delegate: Rectangle {
          required property var modelData

          width: parent.width
          height: Math.max(Style.space(38), toolRow.implicitHeight + Style.space(4))
          radius: Style.cornerRadius
          color: toolHover.hovered ? Qt.rgba(0, 1, 0.867, 0.10) : "transparent"

          Row {
            id: toolRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Text {
              text: modelData.icon
              color: Color.accent
              font.family: root.ff
              font.pixelSize: Style.font.iconLarge
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              Text {
                text: modelData.label
                color: root.fg
                font.family: root.ff
                font.pixelSize: Style.font.body
              }

              Text {
                text: modelData.hint
                color: Qt.darker(root.fg, 1.5)
                font.family: root.ff
                font.pixelSize: Style.font.caption
              }
            }
          }

          HoverHandler { id: toolHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(modelData)
          }
        }
      }
    }

    // ---- Settings / health view ------------------------------------------
    Flickable {
      id: settingsScroll

      visible: root.showSettings
      anchors.fill: parent
      contentWidth: width
      contentHeight: settingsColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: settingsColumn

        width: settingsScroll.width
        spacing: Style.space(8)

        Item {
          width: parent.width
          height: Style.space(22)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "SETTINGS"
            color: Qt.darker(root.fg, 1.35)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          PanelActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰁍"
            tooltipText: "Back to tools"
            foreground: root.fg
            fontFamily: root.ff
            focusable: true
            Accessible.name: "Back to tools"
            onClicked: root.showSettings = false
          }
        }

        Rectangle {
          width: parent.width
          height: quickColumn.implicitHeight + Style.space(18)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.06)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)

          Column {
            id: quickColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(10)
            spacing: Style.space(3)

            Text {
              text: "Quick start"
              color: root.fg
              font.family: root.ff
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            Text {
              width: parent.width
              text: "SUPER+ALT+N next wallpaper · SUPER+ALT+W live/static · SUPER+ALT+C cooler boost"
              color: Qt.darker(root.fg, 1.45)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Text {
          text: "APPEARANCE"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Toggle {
          width: parent.width
          label: "Gap effects"
          description: "Comet stream, rim scanner and hex drift"
          checked: root.bar ? root.bar.gapEffects !== false : true
          foreground: root.fg
          accent: Color.accent
          fontFamily: root.ff
          onClicked: root.setBarOption("gapEffects", !(root.bar && root.bar.gapEffects !== false))
        }

        Toggle {
          width: parent.width
          label: "Hover glow"
          description: "Lit chrome under the pointer"
          checked: root.bar ? root.bar.hoverGlow !== false : true
          foreground: root.fg
          accent: Color.accent
          fontFamily: root.ff
          onClicked: root.setBarOption("hoverGlow", !(root.bar && root.bar.hoverGlow !== false))
        }

        Toggle {
          width: parent.width
          label: "Reduced motion"
          description: "Keep the effects but stop the travel"
          checked: root.bar ? root.bar.reducedMotion === true : false
          foreground: root.fg
          accent: Color.accent
          fontFamily: root.ff
          onClicked: root.setBarOption("reducedMotion", !(root.bar && root.bar.reducedMotion === true))
        }

        Row {
          spacing: Style.space(6)

          Button {
            text: "Cyberpunk"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.setVariant("cyberpunk")
          }
          Button {
            text: "Sakura"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.setVariant("sakura")
          }
          Button {
            text: "Cozy"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.setVariant("cozy")
          }
        }

        Row {
          spacing: Style.space(6)

          Button {
            text: "Live wallpaper"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.toggleWallpaper()
          }
          Button {
            text: "UI sound"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.toggleSound()
          }
        }

        Text {
          text: "WEATHER"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Toggle {
          width: parent.width
          label: "Automatic location"
          description: "Let wttr.in approximate the location from your IP"
          checked: root.weatherAuto
          foreground: root.fg
          accent: Color.accent
          fontFamily: root.ff
          onClicked: root.setWeatherAuto(!root.weatherAuto)
        }

        Text {
          text: "SYSTEM"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Row {
          spacing: Style.space(6)

          Button {
            text: "Diagnose"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.diagnose()
          }
          Button {
            text: root.verifyRunning ? "Checking…" : "Verify pins"
            focusable: true
            enabled: !root.verifyRunning
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.verifyPins()
          }
          Button {
            text: "Repair bar"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.repairBar()
          }
          Button {
            text: "Logs"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            onClicked: root.openLogs()
          }
        }

        Text {
          visible: root.verifyText !== ""
          width: parent.width
          text: root.verifyText
          color: Qt.darker(root.fg, 1.4)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: "Changes are written to ~/.config/omarchy/shell.json and apply live."
          color: Qt.darker(root.fg, 1.6)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
