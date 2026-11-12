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
  onShowSettingsChanged: {
    if (root.showSettings) root.refreshThemes()
  }
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
  property bool paletteWriteDirty: false
  property bool paletteReady: false
  property bool paletteTouched: false
  property bool paletteQueued: false
  property var paletteBaseline: ({})
  property var paletteHistory: []
  property int paletteHistoryIndex: -1
  property double paletteIgnoreUntil: 0
  property string seedHex: ""
  property string visionMode: "normal"
  property string paletteError: ""
  property int boardFocusIndex: 0
  property var savedThemes: []
  property string themeName: ""
  property string themeImportPath: ""
  property string themeStatus: ""
  property string themeAction: ""
  readonly property var defaultRoleColors: ({
    accent: "#00ffdd",
    secondary: "#ff00ff",
    tertiary: "#00ff88",
    warm: "#ffe066",
    pink: "#ffb7d5",
    hot: "#ff0055",
    background: "#0f081d",
    foreground: "#eafbfa"
  })
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
  readonly property bool canUndo: root.paletteHistoryIndex > 0
  readonly property bool canRedo: root.paletteHistoryIndex >= 0
    && root.paletteHistoryIndex < root.paletteHistory.length - 1
  readonly property color alertColor: (root.bar && root.bar.hotColor !== undefined)
    ? root.bar.hotColor : "#ff0055"
  readonly property real paletteContrast: root.contrastRatio(
    root.roleColor("foreground"), root.roleColor("background"))
  readonly property bool contrastLow: root.paletteContrast < 4.5
  readonly property bool liveTerminals: root.barSettings.liveTerminals !== false

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
    return root.roleColors[role] || root.defaultRoleColors[role] || "#00ffdd"
  }

  function hslHex(h, s, l) {
    var c = Qt.hsla(h / 360, s / 100, l / 100, 1)
    return "#" + root.hexByte(c.r) + root.hexByte(c.g) + root.hexByte(c.b)
  }

  function hexToHsl(hex) {
    var value = String(hex || "").replace("#", "")
    if (!/^[0-9a-fA-F]{6}$/.test(value)) return null
    var r = parseInt(value.substr(0, 2), 16) / 255
    var g = parseInt(value.substr(2, 2), 16) / 255
    var b = parseInt(value.substr(4, 2), 16) / 255
    var max = Math.max(r, g, b)
    var min = Math.min(r, g, b)
    var h = 0
    var s = 0
    var l = (max + min) / 2
    if (max !== min) {
      var d = max - min
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
      if (max === r) h = (g - b) / d + (g < b ? 6 : 0)
      else if (max === g) h = (b - r) / d + 2
      else h = (r - g) / d + 4
      h /= 6
    }
    return { h: h * 360, s: s * 100, l: l * 100 }
  }

  function normalizedHue(value) {
    var h = value % 360
    return h < 0 ? h + 360 : h
  }

  function effectiveSeed() {
    var value = String(root.seedHex || "").trim()
    if (/^#?[0-9a-fA-F]{6}$/.test(value))
      return "#" + value.replace("#", "").toLowerCase()
    return root.roleColor("accent")
  }

  function setSeedHex(text) {
    var value = String(text || "").trim()
    if (/^#?[0-9a-fA-F]{6}$/.test(value)) {
      root.seedHex = "#" + value.replace("#", "").toLowerCase()
    } else {
      root.seedHex = ""
      if (typeof seedField !== "undefined" && seedField) seedField.text = root.effectiveSeed()
    }
  }

  function harmonyOffsets(mode) {
    if (mode === "analogous") return [0, 30, -30, 45, 330, 180]
    if (mode === "complement") return [0, 180, 165, 45, 330, 200]
    return [0, 120, 240, 60, 300, 180]
  }

  function generateHarmony(mode) {
    var seed = root.effectiveSeed()
    var hsl = root.hexToHsl(seed)
    if (!hsl) return
    var offsets = root.harmonyOffsets(mode)
    var next = {}
    for (var i = 0; i < root.roles.length; i++)
      next[root.roles[i].id] = root.roleColors[root.roles[i].id]
    next.accent = seed
    next.secondary = root.hslHex(root.normalizedHue(hsl.h + offsets[1]), 82, 64)
    next.tertiary = root.hslHex(root.normalizedHue(hsl.h + offsets[2]), 82, 54)
    next.warm = root.hslHex(root.normalizedHue(hsl.h + offsets[3]), 95, 65)
    next.pink = root.hslHex(root.normalizedHue(hsl.h + offsets[4]), 72, 74)
    next.hot = root.hslHex(root.normalizedHue(hsl.h + offsets[5]), 88, 55)
    root.seedHex = seed
    root.roleColors = next
    root.commitHistory()
    root.markPaletteChanged()
  }

  function deriveNeutrals() {
    var hsl = root.hexToHsl(root.effectiveSeed())
    if (!hsl) return
    var next = {}
    for (var i = 0; i < root.roles.length; i++)
      next[root.roles[i].id] = root.roleColors[root.roles[i].id]
    next.background = root.hslHex(hsl.h, 38, 8)
    next.foreground = root.hslHex(hsl.h, 16, 93)
    root.seedHex = root.effectiveSeed()
    root.roleColors = next
    root.commitHistory()
    root.markPaletteChanged()
  }

  function simulateVision(hex, mode) {
    if (mode === "normal") return hex
    var value = String(hex || "").replace("#", "")
    if (!/^[0-9a-fA-F]{6}$/.test(value)) return hex
    var r = parseInt(value.substr(0, 2), 16) / 255
    var g = parseInt(value.substr(2, 2), 16) / 255
    var b = parseInt(value.substr(4, 2), 16) / 255
    var matrix = mode === "protan"
      ? [[0.152, 1.053, -0.205], [0.115, 0.786, 0.099], [-0.004, -0.048, 1.052]]
      : [[0.367, 0.861, -0.228], [0.280, 0.673, 0.047], [-0.012, 0.043, 0.969]]
    var nr = matrix[0][0] * r + matrix[0][1] * g + matrix[0][2] * b
    var ng = matrix[1][0] * r + matrix[1][1] * g + matrix[1][2] * b
    var nb = matrix[2][0] * r + matrix[2][1] * g + matrix[2][2] * b
    return "#" + root.hexByte(nr) + root.hexByte(ng) + root.hexByte(nb)
  }

  function roleLabel(role) {
    for (var i = 0; i < root.roles.length; i++)
      if (root.roles[i].id === role) return root.roles[i].label
    return role
  }

  function snapshotColors() {
    // An array of hex strings is stable to compare and to serialize; a QML
    // object map round-trips differently across Qt versions.
    return JSON.stringify(root.currentColors())
  }

  function colorsToRoleMap(colors) {
    var order = ["accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground"]
    var next = {}
    for (var i = 0; i < order.length && i < colors.length; i++)
      next[order[i]] = "#" + String(colors[i]).replace("#", "").toLowerCase()
    return next
  }

  function resetHistory() {
    root.paletteHistory = [root.snapshotColors()]
    root.paletteHistoryIndex = 0
  }

  function commitHistory() {
    var snapshot = root.snapshotColors()
    if (root.paletteHistoryIndex >= 0
        && root.paletteHistory[root.paletteHistoryIndex] === snapshot) return
    var next = root.paletteHistory.slice(0, root.paletteHistoryIndex + 1)
    next.push(snapshot)
    if (next.length > 50) next.shift()
    root.paletteHistory = next
    root.paletteHistoryIndex = next.length - 1
  }

  function ensurePaletteReady() {
    if (root.paletteReady) return
    root.paletteBaseline = JSON.parse(JSON.stringify(root.roleColors))
    root.seedHex = root.roleColor("accent")
    root.paletteReady = true
    root.resetHistory()
  }

  function markPaletteChanged() {
    root.paletteDirty = true
    root.paletteWriteDirty = true
    // A FileView reload may still carry the previous file for a moment after
    // our writer exits. Ignore external loads during that window so undo/redo
    // cannot be reset by our own write.
    root.paletteIgnoreUntil = Date.now() + 1000
    root.paletteTouched = true
    root.currentVariant = "custom"
    paletteDebounce.restart()
    themeDebounce.restart()
  }

  function applyHistory(index) {
    if (index < 0 || index >= root.paletteHistory.length) return
    if (index === root.paletteHistoryIndex) return
    root.paletteHistoryIndex = index
    root.roleColors = root.colorsToRoleMap(JSON.parse(root.paletteHistory[index]))
    root.selectRole(root.selectedRole)
    root.markPaletteChanged()
  }

  function undoPalette() {
    root.applyHistory(root.paletteHistoryIndex - 1)
  }

  function redoPalette() {
    root.applyHistory(root.paletteHistoryIndex + 1)
  }

  function resetPalette() {
    if (!root.paletteBaseline) return
    root.roleColors = JSON.parse(JSON.stringify(root.paletteBaseline))
    root.selectRole(root.selectedRole)
    root.commitHistory()
    root.markPaletteChanged()
  }

  function channelLuminance(value) {
    var c = value / 255
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
  }

  function relativeLuminance(hex) {
    var value = String(hex || "").replace("#", "")
    if (!/^[0-9a-fA-F]{6}$/.test(value)) return 0
    return 0.2126 * root.channelLuminance(parseInt(value.substr(0, 2), 16))
      + 0.7152 * root.channelLuminance(parseInt(value.substr(2, 2), 16))
      + 0.0722 * root.channelLuminance(parseInt(value.substr(4, 2), 16))
  }

  function contrastRatio(a, b) {
    var la = root.relativeLuminance(a)
    var lb = root.relativeLuminance(b)
    var high = Math.max(la, lb)
    var low = Math.min(la, lb)
    return (high + 0.05) / (low + 0.05)
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
    root.commitHistory()
    // Coalesce rapid clicks. One serialized writer per settled state means an
    // older process can never finish last and overwrite the newest color.
    root.markPaletteChanged()
  }

  function writePaletteNow() {
    if (!root.paletteWriteDirty) return
    if (paletteWriter.running) {
      root.paletteQueued = true
      return
    }
    root.paletteWriteDirty = false
    root.paletteQueued = false
    root.paletteError = ""
    var args = [root.home + "/.local/bin/vp-palette.sh", "--seq", String(Date.now())]
    if (root.liveTerminals) args.push("--terminals")
    paletteWriter.command = args.concat(root.currentColors())
    paletteWriter.running = true
  }

  function pickColor(value) {
    root.setRoleColor(root.selectedRole, value)
  }

  function setRoleFromIpc(role, text) {
    var known = false
    for (var i = 0; i < root.roles.length; i++)
      if (root.roles[i].id === role) known = true
    if (!known) return
    var value = String(text || "").trim()
    if (!/^#?[0-9a-fA-F]{6}$/.test(value)) return
    root.selectRole(role)
    root.setRoleColor(role, "#" + value.replace("#", "").toLowerCase())
  }

  function setSelectedHex(text) {
    var value = String(text || "").trim()
    if (!/^#?[0-9a-fA-F]{6}$/.test(value)) {
      if (typeof hexField !== "undefined" && hexField) hexField.text = root.selectedHex
      return
    }
    root.setRoleColor(root.selectedRole, "#" + value.replace("#", "").toLowerCase())
  }

  function flushTheme(skipRefresh) {
    if (!root.paletteDirty) return
    root.paletteDirty = false
    // Rewrites the theme text files (terminal, GTK, Omarchy templates) with the
    // same palette. While the panel is open, skip the shell-wide theme refresh:
    // it tears the panel down, which would make Undo/Redo unusable. The refresh
    // runs when the panel closes.
    // vp-palette.sh owns palette.json; the theme file pass only writes the
    // terminal/GTK/Omarchy templates. This prevents a slower theme pass from
    // overwriting a newer live color.
    var prefix = "VP_SKIP_PALETTE_WRITE=1 "
    if (skipRefresh) prefix += "VP_NO_THEME_REFRESH=1 "
    if (root.liveTerminals) prefix += "VP_RELOAD_CONSUMERS=1 "
    root.run("bash -lc '" + prefix + root.home + "/.local/bin/theme-switcher.sh custom "
      + root.currentColors().join(" ") + "'")
  }

  function loadPalette(text) {
    // Ignore an external reload while our own debounced write is in flight:
    // it may still read the previous palette and would reset the undo history
    // in the middle of undo/redo.
    if (Date.now() < root.paletteIgnoreUntil) return
    if (root.paletteWriteDirty || paletteDebounce.running || paletteWriter.running) return
    try {
      var data = JSON.parse(String(text || "{}"))
      var next = {}
      var same = true
      for (var i = 0; i < root.roles.length; i++) {
        var id = root.roles[i].id
        var value = data[id]
        next[id] = (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value))
          ? value : root.roleColor(id)
        if (next[id].toLowerCase() !== root.roleColor(id).toLowerCase()) same = false
      }
      if (root.paletteReady && same) return
      root.roleColors = next
      root.seedHex = next.accent
      root.paletteBaseline = JSON.parse(JSON.stringify(next))
      if (!root.paletteReady) {
        root.paletteReady = true
        root.resetHistory()
      } else {
        // An external writer changed the palette; the old undo history no
        // longer applies to it.
        root.resetHistory()
      }
      root.selectRole(root.selectedRole)
    } catch (e) {
      // Keep the defaults when the palette file is mid-write.
    }
  }

  function refreshThemes() {
    themeListProc.running = false
    themeListProc.running = true
  }

  function runThemeAction(args) {
    if (themeActionProc.running) return
    root.themeAction = String(args[0] || "")
    root.themeStatus = "Working…"
    themeActionProc.command = [root.home + "/.local/bin/vp-theme.sh"].concat(args)
    themeActionProc.running = true
  }

  function saveTheme() {
    var name = root.themeName.trim()
    if (name === "") {
      root.themeStatus = "Give the theme a name first."
      return
    }
    root.runThemeAction(["save", name])
  }

  function loadTheme(name) {
    root.runThemeAction(["load", String(name)])
  }

  function importTheme() {
    var path = root.themeImportPath.trim()
    if (path === "") {
      root.themeStatus = "Enter the path to a theme JSON file."
      return
    }
    root.runThemeAction(["import", path])
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
    // Kept for the IPC/scripts that used to press Apply; flush both debounced
    // paths so a script can force the final state.
    paletteDebounce.stop()
    root.writePaletteNow()
    root.flushTheme(false)
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
    // A pending custom write must not land after the named palette and undo it.
    paletteDebounce.stop()
    themeDebounce.stop()
    root.paletteDirty = false
    root.paletteWriteDirty = false
    root.paletteTouched = false
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

  Shortcut {
    sequence: "Ctrl+Z"
    onActivated: root.undoPalette()
  }

  Shortcut {
    sequence: "Ctrl+Shift+Z"
    onActivated: root.redoPalette()
  }

  // A failed switcher can leave the buttons disabled; the shell restart
  // normally destroys this panel long before the timeout.
  Timer {
    interval: 20000
    running: root.variantSwitching
    onTriggered: root.variantSwitching = false
  }

  // Coalesce the live palette write and the theme text files separately. The
  // bar only needs the JSON; the terminal/GTK configs can wait longer.
  Timer {
    id: paletteDebounce
    interval: 60
    repeat: false
    onTriggered: root.writePaletteNow()
  }

  Timer {
    id: themeDebounce
    interval: 450
    repeat: false
    onTriggered: root.flushTheme(true)
  }

  Process {
    id: themeListProc

    command: [root.home + "/.local/bin/vp-theme.sh", "list"]
    running: false

    stdout: StdioCollector {
      id: themeListOut
      waitForEnd: true
      onStreamFinished: {
        var lines = String(themeListOut.text || "").split("\n")
        var names = []
        for (var i = 0; i < lines.length; i++) {
          var value = lines[i].trim()
          if (value !== "") names.push(value)
        }
        root.savedThemes = names
      }
    }
  }

  Process {
    id: themeActionProc

    command: []
    running: false

    stdout: StdioCollector {
      id: themeActionOut
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: themeActionErr
      waitForEnd: true
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var detail = String(themeActionErr.text || "").trim()
        root.themeStatus = detail !== "" ? detail.split("\n").slice(-2).join(" · ")
          : "Theme action failed."
        return
      }
      if (root.themeAction === "save") root.themeStatus = "Saved."
      else if (root.themeAction === "load") root.themeStatus = "Loaded."
      else if (root.themeAction === "import") root.themeStatus = "Imported."
      else root.themeStatus = "Done."
      if (root.themeAction === "save") root.themeName = ""
      if (root.themeAction === "import") root.themeImportPath = ""
      root.refreshThemes()
      if (root.themeAction === "load") Qt.callLater(function() { paletteFile.reload() })
    }
  }

  // One writer at a time. If clicks arrive while it runs, keep only the newest
  // request and start it when the current process exits.
  Process {
    id: paletteWriter

    command: []
    running: false

    stderr: StdioCollector {
      id: paletteWriterErr
      waitForEnd: true
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var detail = String(paletteWriterErr.text || "").trim()
        root.paletteError = detail !== "" ? detail.split("\n").slice(-2).join(" · ")
          : "Could not save the custom palette."
      }
      if (root.paletteQueued && root.paletteWriteDirty) {
        root.paletteQueued = false
        root.writePaletteNow()
      }
    }
  }

  Component.onCompleted: root.refreshThemes()

  Component.onDestruction: {
    paletteDebounce.stop()
    if (root.paletteTouched && root.currentVariant === "custom") {
      // The QML Process is about to die; hand the final state to a detached
      // writer. The sequence guard makes this newer than any in-flight write.
      root.paletteWriteDirty = false
      root.run(root.home + "/.local/bin/vp-palette.sh --seq " + Date.now()
        + (root.liveTerminals ? " --terminals " : " ") + root.currentColors().join(" "))
    }
    root.flushTheme(false)
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
    onLoadFailed: {
      root.ensurePaletteReady()
      root.selectRole(root.selectedRole)
    }
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
    contentHeight: panel.fittedContentHeight(root.showSettings ? 900 : toolsColumn.implicitHeight)

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
                activeFocusOnTab: true
                border.width: (root.selectedRole === modelData.id || activeFocus) ? 2 : 1
                border.color: (root.selectedRole === modelData.id || activeFocus)
                  ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.30)
                Accessible.name: modelData.label + " color"
                Accessible.role: Accessible.Button

                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                      || event.key === Qt.Key_Space) {
                    root.selectRole(modelData.id)
                    event.accepted = true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectRole(modelData.id)
                    parent.forceActiveFocus()
                  }
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
          id: colorBoard

          columns: 13
          spacing: Style.space(3)
          activeFocusOnTab: true

          Keys.onPressed: function(event) {
            var count = root.boardColors.length
            if (count === 0) return
            var index = root.boardFocusIndex
            if (event.key === Qt.Key_Left) index = (index - 1 + count) % count
            else if (event.key === Qt.Key_Right) index = (index + 1) % count
            else if (event.key === Qt.Key_Up) index = (index - 13 + count) % count
            else if (event.key === Qt.Key_Down) index = (index + 13) % count
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                     || event.key === Qt.Key_Space) {
              root.pickColor(root.boardColors[root.boardFocusIndex])
              event.accepted = true
              return
            } else {
              return
            }
            root.boardFocusIndex = index
            event.accepted = true
          }

          Repeater {
            model: root.boardColors

            Rectangle {
              required property string modelData
              required property int index

              width: Style.space(22)
              height: Style.space(22)
              radius: Style.space(4)
              color: modelData
              border.width: (root.selectedHex.toLowerCase() === modelData.toLowerCase()
                || (colorBoard.activeFocus && root.boardFocusIndex === index)) ? 2 : 1
              border.color: (root.selectedHex.toLowerCase() === modelData.toLowerCase()
                || (colorBoard.activeFocus && root.boardFocusIndex === index))
                ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22)
              Accessible.name: "Colour " + modelData
              Accessible.role: Accessible.Button

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.boardFocusIndex = index
                  colorBoard.forceActiveFocus()
                  root.pickColor(modelData)
                }
              }
            }
          }
        }

        Row {
          spacing: Style.space(6)

          Button {
            text: "Undo"
            enabled: root.canUndo
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Undo palette change"
            onClicked: root.undoPalette()
          }

          Button {
            text: "Redo"
            enabled: root.canRedo
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Redo palette change"
            onClicked: root.redoPalette()
          }

          Button {
            text: "Reset"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Reset palette to the state when the panel opened"
            onClicked: root.resetPalette()
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
          text: "CONTRAST " + root.paletteContrast.toFixed(1) + ":1"
            + (root.contrastLow ? " — Text is hard to read on this Background" : " — readable")
          color: root.contrastLow ? root.alertColor : Qt.darker(root.fg, 1.45)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: "Pick a role, then click a swatch. Changes apply live — no Apply button. "
            + "Keyboard: Tab to the board, arrows move, Enter picks."
          color: Qt.darker(root.fg, 1.55)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.paletteError !== ""
          width: parent.width
          text: root.paletteError
          color: root.alertColor
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          text: "PREVIEW"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Rectangle {
          width: parent.width
          height: Style.space(62)
          radius: Style.cornerRadius
          color: root.roleColor("background")
          border.width: 1
          border.color: root.roleColor("accent")

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(4)

            Row {
              spacing: Style.space(5)

              Repeater {
                model: ["accent", "secondary", "tertiary"]

                Rectangle {
                  required property string modelData
                  width: Style.space(8)
                  height: Style.space(8)
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: root.roleColor(modelData)
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "14:32  Thu 12 Nov"
                color: root.roleColor("foreground")
                font.family: root.ff
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              spacing: Style.space(5)

              Text {
                text: "→"
                color: root.roleColor("accent")
                font.family: root.ff
                font.pixelSize: Style.font.body
              }
              Text {
                text: "custom theme"
                color: root.roleColor("foreground")
                font.family: root.ff
                font.pixelSize: Style.font.body
              }
              Text {
                text: "build ok"
                color: root.roleColor("tertiary")
                font.family: root.ff
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        Text {
          text: "GENERATE FROM SEED"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Row {
          spacing: Style.space(6)

          TextField {
            id: seedField
            width: Style.space(100)
            text: root.seedHex
            placeholderText: root.roleColor("accent")
            foreground: root.fg
            font.family: root.ff
            font.pixelSize: Style.font.body
            Accessible.name: "Seed colour for palette generation"
            onTextChanged: root.seedHex = text
            onEditingFinished: root.setSeedHex(text)
          }

          Button {
            text: "Use accent"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Use the current accent as the seed"
            onClicked: {
              root.seedHex = root.roleColor("accent")
              seedField.text = root.seedHex
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Button {
            text: "Analogous"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Generate an analogous palette"
            onClicked: root.generateHarmony("analogous")
          }
          Button {
            text: "Complement"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Generate a complementary palette"
            onClicked: root.generateHarmony("complement")
          }
          Button {
            text: "Triad"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Generate a triadic palette"
            onClicked: root.generateHarmony("triad")
          }
          Button {
            text: "BG / Text"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Derive a dark background and readable text from the seed"
            onClicked: root.deriveNeutrals()
          }
        }

        Text {
          text: "COLOR VISION"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Row {
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "normal", label: "Normal" },
              { id: "deutan", label: "Deutan" },
              { id: "protan", label: "Protan" }
            ]

            Button {
              required property var modelData
              text: modelData.label
              selected: root.visionMode === modelData.id
              focusable: true
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.ff
              Accessible.name: "Preview palette with " + modelData.label + " vision"
              onClicked: root.visionMode = modelData.id
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.roles

            Rectangle {
              required property var modelData
              width: Style.space(30)
              height: Style.space(18)
              radius: Style.space(4)
              color: root.simulateVision(root.roleColor(modelData.id), root.visionMode)
              border.width: 1
              border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.25)
              Accessible.name: modelData.label + " in " + root.visionMode + " vision"
            }
          }
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

        Text {
          text: "SAVED THEMES"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Row {
          spacing: Style.space(6)

          TextField {
            width: Style.space(150)
            text: root.themeName
            placeholderText: "Theme name"
            foreground: root.fg
            font.family: root.ff
            font.pixelSize: Style.font.body
            Accessible.name: "Name for the theme to save"
            onTextChanged: root.themeName = text
            onAccepted: root.saveTheme()
          }

          Button {
            text: "Save"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Save the current palette"
            onClicked: root.saveTheme()
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.savedThemes

            Button {
              required property string modelData
              text: modelData
              focusable: true
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.ff
              Accessible.name: "Load saved theme " + modelData
              onClicked: root.loadTheme(modelData)
            }
          }
        }

        Row {
          spacing: Style.space(6)

          TextField {
            width: Style.space(150)
            text: root.themeImportPath
            placeholderText: "Theme JSON path"
            foreground: root.fg
            font.family: root.ff
            font.pixelSize: Style.font.body
            Accessible.name: "Path to a theme JSON file to import"
            onTextChanged: root.themeImportPath = text
            onAccepted: root.importTheme()
          }

          Button {
            text: "Import"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Import a theme JSON file"
            onClicked: root.importTheme()
          }
        }

        Text {
          width: parent.width
          visible: root.themeStatus !== ""
          text: root.themeStatus
          color: Qt.darker(root.fg, 1.45)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: "Saved themes are portable JSON under ~/.local/state/virtual-paradise/themes."
          color: Qt.darker(root.fg, 1.7)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          text: "ARTWORK"
          color: Qt.darker(root.fg, 1.35)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          height: Style.space(16)
        }

        Text {
          width: parent.width
          text: "Build a duotone still from the current wallpaper (video frame or image) using the live Background and Accent. SDDM and Plymouth keep the cyberpunk artwork."
          color: Qt.darker(root.fg, 1.6)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Button {
            text: "Tint wallpaper"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Generate and apply a palette wallpaper"
            onClicked: root.run(root.home + "/.local/bin/vp-wallpaper-tint.sh apply")
          }
          Button {
            text: "Restore"
            focusable: true
            foreground: root.fg
            accent: Color.accent
            fontFamily: root.ff
            Accessible.name: "Restore the wallpaper from before the tint"
            onClicked: root.run(root.home + "/.local/bin/vp-wallpaper-tint.sh restore")
          }
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

        Toggle {
          width: parent.width
          label: "Live terminal palette"
          description: "Recolor open terminals and Cava live"
          checked: root.liveTerminals
          foreground: root.fg
          accent: Color.accent
          fontFamily: root.ff
          onClicked: root.setBarOption("liveTerminals", !root.liveTerminals)
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
