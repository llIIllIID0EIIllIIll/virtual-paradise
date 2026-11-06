import QtQuick
import Quickshell.Io
import ".."

BarIndicator {
  id: root

  property string state: "idle"
  property string icon: ""

  active: state === "recording"
  activeText: icon !== "" ? icon : "󰔱"
  inactiveText: "󰔊" // Audio Waveform (distinct from Microphone 󰍬)
  activeTooltipText: "Voice Dictation: Recording (Left: Stop | Right: Toggle Config)"
  inactiveTooltipText: "Voice Dictation: Ready (Left: Start | Right: Toggle Config)"

  function update(raw) {
    var data = extractData(raw)

    state = String(data.alt || data.class || "idle")
    if (state === "recording") icon = "󰔱"
    else if (state === "transcribing") icon = "󰔟"
    else icon = ""
  }

  Process {
    // Prefer Omarchy's status wrapper; without the omarchy-voxtype package it
    // is missing, so fall back to the voxtype CLI's own status.
    command: ["bash", "-c", "if command -v omarchy-voxtype-status >/dev/null 2>&1; then omarchy-voxtype-status; else s=$(voxtype status 2>/dev/null || true); case \"$s\" in *recording*) printf '{\"alt\":\"recording\"}\\n' ;; *transcribing*) printf '{\"alt\":\"transcribing\"}\\n' ;; *) printf '{\"alt\":\"idle\"}\\n' ;; esac; fi"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.update(data) }
    }
  }

  onPressed: function(b) {
    if (!root.bar) return
    if (b === Qt.RightButton) {
      root.bar.run("~/.local/bin/toggle_voxtype_config.sh")
    } else {
      root.bar.run("bash -c 'if ! systemctl --user is-active --quiet voxtype; then systemctl --user start voxtype; sleep 0.1; fi; voxtype record toggle'")
    }
  }
}
