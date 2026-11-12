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
  property bool variantSwitching: false
  property string verifyText: ""
  property string currentVariant: "cyberpunk"
  property var shellConfig: ({})

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/omarchy/shell.json"
  readonly property color fg: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family

  // Accent palettes mirrored from Omarchy's own themes plus Dracula and Rose
  // Pine Moon. The switcher and this list must stay in sync.
  readonly property var variants: [
    { id: "cyberpunk", label: "Cyberpunk" },
    { id: "neon", label: "Neon" },
    { id: "monochrome", label: "Mono" },
    { id: "catppuccin", label: "Catppuccin" },
    { id: "tokyo-night", label: "Tokyo" },
    { id: "gruvbox", label: "Gruvbox" },
    { id: "nord", label: "Nord" },
    { id: "everforest", label: "Everforest" },
    { id: "kanagawa", label: "Kanagawa" },
    { id: "rose-pine", label: "Rosé" },
    { id: "hackerman", label: "Hackerman" },
    { id: "dracula", label: "Dracula" }
  ]

  // Custom theme editor. Pick a role, then click a colour on the board. Every
  // pick writes palette.json immediately (the bar watches that file, so it
  // recolors on the next frame) and debounces the theme text files.
  property string selectedRole: "accent"
  property var roleColors: ({
    accent: "#00ffdd",
    secondary: "#ff00ff",
    tertiary: "#00ff88",
    warm: "#ffe066",
    pink: "#ffb7d5",
    hot: "#ff0055",
    background: "#0f081d",
    foreground: "#eafbfa"
  })
  property bool paletteDirty: false
  readonly property var roles: [
    { id: "accent", label: "Accent" },
    { id: "secondary", label: "Secondary" },
    { id: "tertiary", label: "Tertiary" },
    { id: "warm", label: "Warm" },
    { id: "pink", label: "Pink" },
    { id: "hot", label: "Urgent" },
    { id: "background", label: "BG" },
    { id: "foreground", label: "Text" }
  ]
  readonly property string selectedHex: root.roleColor(root.selectedRole)

  // The visual board: thirteen hues across, seven tones down, then a neutral
  // ramp for backgrounds and text. No hex knowledge required.
  readonly property var boardHues: [0, 20, 40, 60, 90, 140, 170, 190, 215, 250, 280, 310, 335]
  readonly property var boardTones: [
    { s: 45, l: 90 },
    { s: 65, l: 78 },
    { s: 85, l: 66 },
    { s: 100, l: 54 },
    { s: 95, l: 42 },
    { s: 85, l: 30 },
    { s: 70, l: 20 }
  ]
  readonly property var boardNeutrals: [
    "#0b0b0b", "#161616", "#222222", "#303030", "#424242", "#585858",
    "#737373", "#909090", "#adadad", "#cacaca", "#e8e8e8", "#ffffff"
  ]
  readonly property var boardColors: {
    var list = []
    for (var r = 0; r < root.boardTones.length; r++)
      for (var c = 0; c < root.boardHues.length; c++)
        list.push(root.hslHex(root.boardHues[c], root.boardTones[r].s, root.boardTones[r].l))
    for (var n = 0; n < root.boardNeutrals.length; n++)
      list.push(root.boardNeutrals[n])
    return list
  }

  function hexByte(value) {
    var n = Math.round(Math.max(0, Math.min(1, value)) * 255)
    return (n < 16 ? "0" : "") + n.toString(16)
  }

  function roleColor(role) {
    return root.roleColors[role] || "#00ffdd"
  }

  function hslHex(h, s, l) {
    var c = Qt.hsla(h / 360, s / 100, l / 100, 1)
    return "#" + root.hexByte(c.r) + root.hexByte(c.g) + root.hexByte(c.b)
  }

  function roleLabel(role) {
    for (var i = 0; i < root.roles.length; i++)
      if (root.roles[i].id === role) return root.roles[i].label
    return role
  }

  function selectRole(role) {
    root.selectedRole = role || "accent"
    Qt.callLater(function() {
      if (typeof hexField !== "undefined" && hexField) hexField.text = root.selectedHex
    })
  }

  function currentColors() {
    var order = ["accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground"]
    var colors = []
    for (var i = 0; i < order.length; i++)
      colors.push(String(root.roleColor(order[i])).replace("#", "").toLowerCase())
    return colors
  }

  function setRoleColor(role, value) {
    var next = {}
    for (var i = 0; i < root.roles.length; i++) {
      var id = root.roles[i].id
      next[id] = root.roleColors[id]
    }
    next[role || root.selectedRole] = value
    root.roleColors = next
    if (typeof hexField !== "undefined" && hexField) hexField.text = value
    root.paletteDirty = true
    // The bar reads palette.json directly, so this is the realtime path.
    root.run(root.home + "/.local/bin/vp-palette.sh " + root.currentColors().join(" "))
    themeDebounce.restart()
  }

  function pickColor(value) {
    root.setRoleColor(root.selectedRole, value)
  }

  function setSelectedHex(text) {
    var value = String(text || "").trim()
    if (!/^#?[0-9a-fA-F]{6}$/.test(value)) {
      if (typeof hexField !== "undefined" && hexField) hexField.text = root.selectedHex
      return
    }
    root.setRoleColor(root.selectedRole, "#" + value.replace("#", "").toLowerCase())
  }

  function flushTheme() {
    if (!root.paletteDirty) return
    root.paletteDirty = false
    // Rewrites the theme text files (terminal, GTK, Omarchy templates) with the
    // same palette. No shell restart: the bar already changed through the JSON.
    root.run("bash -lc '" + root.home + "/.local/bin/theme-switcher.sh custom "
      + root.currentColors().join(" ") + "'")
  }

  function loadPalette(text) {
    try {
      var data = JSON.parse(String(text || "{}"))
      var next = {}
      for (var i = 0; i < root.roles.length; i++) {
        var id = root.roles[i].id
        next[id] = typeof data[id] === "string" ? data[id] : root.roleColors[id]
      }
      root.roleColors = next
      root.selectRole(root.selectedRole)
    } catch (e) {
      // Keep the defaults when the palette file is mid-write.
    }
  }

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
  // The panel reads shell.json itself: the injected bar object is null while
  // the shell rebuilds, and the toggles used to show stale/default values.
  readonly property var barSettings: (root.shellConfig && root.shellConfig.bar) ? root.shellConfig.bar : ({})

  readonly property var weatherConfig: {
    var layout = root.barSettings.layout
    if (!layout) return null
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

  function refreshShellConfig(text) {
    try {
      var parsed = JSON.parse(String(text || "{}"))
      root.shellConfig = (parsed && typeof parsed === "object") ? parsed : ({})
    } catch (e) {
      // Keep the last good copy; the writer validates JSON before replacing.
    }
  }

  // Optimistic local update so a click is visible immediately; the FileView
  // and the host reload reconcile it with the file a moment later.
  function setBarOption(key, value) {
    root.run(root.home + "/.local/bin/vp-setting.sh set bar." + key + " " + (value ? "true" : "false"))
    var next = JSON.parse(JSON.stringify(root.shellConfig || ({})))
    if (!next.bar || typeof next.bar !== "object") next.bar = {}
    next.bar[key] = value
    root.shellConfig = next
  }

  function applyCustomTheme() {
    // Kept for the IPC/scripts that used to press Apply; now it just flushes
    // the debounced theme files. The bar is already using the new palette.
    root.flushTheme()
  }

  function setWeatherAuto(value) {
    root.run(root.home + "/.local/bin/vp-setting.sh set weather.autoLocation " + (value ? "true" : "false"))
    var next = JSON.parse(JSON.stringify(root.shellConfig || ({})))
    var layout = next.bar && next.bar.layout ? next.bar.layout : null
    if (!layout) return
    var sections = [layout.left || [], layout.center || [], layout.right || []]
    for (var s = 0; s < sections.length; s++) {
      for (var i = 0; i < sections[s].length; i++) {
        var entry = sections[s][i]
        if (entry && String(entry.id || "").endsWith(".weather")) {
          entry.autoLocation = value
          root.shellConfig = next
          return
        }
      }
    }
  }

  function run(command) {
    // Do not depend on the injected bar: the panel stays alive across a
    // shell/theme reload and `bar` can be null while a toggle is clicked.
    Util.execDetached(command)
  }

  function setVariant(name) {
    if (root.variantSwitching) return
    root.variantSwitching = true
    // Restart through the single-flight wrapper: two fast clicks used to spawn
    // two supervisors and two bars. Color is read at shell startup, so the
    // restart is still required.
    root.run("bash -lc '" + root.home + "/.local/bin/theme-switcher.sh " + name
      + " && " + root.home + "/.local/bin/vp-restart-shell.sh'")
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

  Shortcut {
    sequence: "Escape"
    onActivated: root.close()
  }

  // A failed switcher can leave the buttons disabled; the shell restart
  // normally destroys this panel long before the timeout.
  Timer {
    interval: 20000
    running: root.variantSwitching
    onTriggered: root.variantSwitching = false
  }

  // Debounce only the text-file side: rapid swatch clicks should not rewrite
  // the terminal/GTK configs on every pixel.
  Timer {
    id: themeDebounce
    interval: 450
    repeat: false
    onTriggered: root.flushTheme()
  }

  Component.onDestruction: root.flushTheme()

  Process {
    id: verifyProc

    command: ["bash", "-lc", root.home + "/.local/bin/paradise-plugin-update --verify"]
    running: false

    stdout: StdioCollector {
      id: verifyOut
      waitForEnd: true
      onStreamFinished: {
        var value = String(verifyOut.text || "").trim()
        if (value === "") return
        if (value.indexOf("All pinned plugins match") !== -1)
          root.verifyText = "All pinned plugins match."
        else if (value.indexOf("DRIFT") !== -1)
          root.verifyText = "Drift detected — open Diagnostics."
        else
          root.verifyText = value.split("\n").slice(-2).join(" · ")
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

  FileView {
    id: shellConfigFile

    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.refreshShellConfig(text())
    onLoadFailed: root.refreshShellConfig("{}")
  }

  FileView {
    id: paletteFile

    path: root.home + "/.local/state/virtual-paradise/palette.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadPalette(text())
    onLoadFailed: root.selectRole(root.selectedRole)
  }

  FileView {
    id: variantFile

    path: root.home + "/.local/state/virtual-paradise/current_variant"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.currentVariant = String(text()).trim() || "cyberpunk"
    onLoadFailed: root.currentVariant = "cyberpunk"
  }

  KeyboardPanel {
    id: panel

    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(root.showSettings ? 400 : 330))
    contentHeight: panel.fittedContentHeight(root.showSettings ? 640 : toolsColumn.implicitHeight)

    // ---- Tools view -------------------------------------------------------
    Column {
      id: toolsColumn

      visible: !root.showSettings
      width: parent.width
      spacing: Style.space(4)
      Keys.onEscapePressed: root.close()

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
      Keys.onEscapePressed: root.close()

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
          text: "CUSTOM THEME"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.roles

            Column {
              required property var modelData

              width: Style.space(58)
              spacing: 2

              Rectangle {
                width: Style.space(32)
                height: Style.space(24)
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Style.space(6)
                color: root.roleColor(modelData.id)
                border.width: root.selectedRole === modelData.id ? 2 : 1
                border.color: root.selectedRole === modelData.id
                  ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.30)
                Accessible.name: modelData.label + " color"
                Accessible.role: Accessible.Button

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectRole(modelData.id)
                }
              }

              Text {
                width: parent.width
                text: modelData.label
                color: root.selectedRole === modelData.id
                  ? root.fg : Qt.darker(root.fg, 1.55)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }
          }
        }

        Grid {
          columns: 13
          spacing: Style.space(3)

          Repeater {
            model: root.boardColors

            Rectangle {
              required property string modelData

              width: Style.space(22)
              height: Style.space(22)
              radius: Style.space(4)
              color: modelData
              border.width: root.selectedHex.toLowerCase() === modelData.toLowerCase() ? 2 : 1
              border.color: root.selectedHex.toLowerCase() === modelData.toLowerCase()
                ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22)
              Accessible.name: "Colour " + modelData
              Accessible.role: Accessible.Button

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pickColor(modelData)
              }
            }
          }
        }

        Row {
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "SELECTED"
            color: Qt.darker(root.fg, 1.45)
            font.family: root.ff
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            width: Style.space(28)
            height: Style.space(22)
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.space(4)
            color: root.selectedHex
            border.width: 1
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.35)
          }

          TextField {
            id: hexField
            width: Style.space(92)
            text: root.selectedHex
            foreground: root.fg
            font.family: root.ff
            font.pixelSize: Style.font.body
            Accessible.name: "Selected role hex"
            onEditingFinished: root.setSelectedHex(text)
          }
        }

        Text {
          width: parent.width
          text: "Pick a role, then click a swatch. Changes apply live — no Apply button."
          color: Qt.darker(root.fg, 1.55)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          text: "PALETTES"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.variants

            Button {
              required property var modelData
              text: modelData.label
              selected: root.currentVariant === modelData.id
              enabled: !root.variantSwitching
              focusable: true
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.ff
              Accessible.name: "Accent variant " + modelData.label
              onClicked: root.setVariant(modelData.id)
            }
          }
        }

        Text {
          text: "Current variant: " + root.currentVariant
          color: Qt.darker(root.fg, 1.55)
          font.family: root.ff
          font.pixelSize: Style.font.caption
        }

        Text {
          width: parent.width
          text: "Accent variants recolor the chrome, terminals and bar widgets; the wallpaper/Plymouth/SDDM artwork stays cyberpunk for now."
          color: Qt.darker(root.fg, 1.7)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Flow {
          width: parent.width
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

        Text {
          visible: root.verifyText !== ""
          width: parent.width
          text: root.verifyText
          color: Qt.darker(root.fg, 1.4)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Flow {
          width: parent.width
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
