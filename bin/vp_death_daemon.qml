import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Virtual☆Paradise — Window Death daemon
//
// Keeps the death burst warm. Spawning a Quickshell per death costs a
// quarter of a second of startup, which either delayed the close or left
// the burst trailing behind it as an afterimage. This shell stays resident
// with its panels hidden and watches the trigger file: the moment a death
// is announced the panels map in a single frame - in the same breath as
// the close - and tear the captured corpse apart.
//
// Trigger format, one line: "x,y,w,h /path/to/frame.png"

ShellRoot {
  id: root

  property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  property int rx: 0
  property int ry: 0
  property int rw: 0
  property int rh: 0
  property string frame: ""
  property bool armed: false
  // True only while a real change is being reloaded. The initial load of a
  // leftover trigger file must not fire a stale burst at login.
  property bool pending: false
  // Bumped on every death so a burst can re-arm even if the previous one
  // is still on screen (mashing SUPER+W must not swallow a death).
  property int generation: 0

  FileView {
    id: trigger
    path: root.runtime + "/vp_death_trigger"
    watchChanges: true
    printErrors: false
    // A watched file only announces that it changed: the view keeps its
    // old (empty) text until reload() is called. Read the new payload in
    // onTextChanged, which fires once the reload lands.
    onFileChanged: {
      root.pending = true
      trigger.reload()
    }
    onTextChanged: {
      if (!root.pending) return
      root.pending = false
      var parts = text().trim().split(" ")
      if (parts.length < 2) return
      var p = parts[0].split(",")
      if (p.length !== 4) return
      root.rx = +p[0]
      root.ry = +p[1]
      root.rw = +p[2]
      root.rh = +p[3]
      root.frame = parts.slice(1).join(" ")
      root.armed = true
      root.generation++
      hideTimer.restart()
    }
  }

  Timer {
    id: hideTimer
    interval: 430
    onTriggered: root.armed = false
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      // Quickshell 0.3.2 screens expose x/y/width/height directly; older
      // builds used a geometry object. Accept both so the burst lands on
      // the right monitor either way.
      property var geo: (function () {
        var s = modelData
        if (s.geometry) return s.geometry
        return { x: s.x || 0, y: s.y || 0, width: s.width || 0, height: s.height || 0 }
      })()
      property bool hit: root.armed && root.rw > 0 && root.rh > 0
        && root.rx < geo.x + geo.width && root.rx + root.rw > geo.x
        && root.ry < geo.y + geo.height && root.ry + root.rh > geo.y

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      margins {
        left: Math.max(0, root.rx - geo.x)
        top: Math.max(0, root.ry - geo.y)
        right: Math.max(0, (geo.x + geo.width) - (root.rx + root.rw))
        bottom: Math.max(0, (geo.y + geo.height) - (root.ry + root.rh))
      }

      color: "transparent"
      visible: win.hit
      WlrLayershell.namespace: "vp-window-death"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      property real fade: 1
      property real wash: 0.15

      // Re-arm every timeline beat the instant a death is announced.
      Connections {
        target: root
        function onGenerationChanged() {
          if (!root.armed || !win.hit) return
          win.fade = 1
          win.wash = 0.15
          strobe.opacity = 0.5
          strobeAnim.restart()
          washAnim.restart()
          fadeTimer.restart()
        }
      }

      Timer {
        id: fadeTimer
        interval: 280
        onTriggered: fadeAnim.start()
      }

      NumberAnimation {
        id: fadeAnim
        target: win
        property: "fade"
        to: 0
        duration: 120
        easing.type: Easing.InQuad
      }

      NumberAnimation {
        id: washAnim
        target: win
        property: "wash"
        from: 0.15
        to: 0.85
        duration: 220
        easing.type: Easing.InQuad
      }

      Item {
        id: corpse
        anchors.fill: parent
        opacity: win.fade
        clip: true

        // The window's own frame, torn into six slices. Every slice shows
        // the same capture shifted to its band; the jitter timer throws them
        // sideways every tick, border pixels included, so the whole window
        // reads as shaking itself apart.
        Timer {
          interval: 40
          repeat: true
          running: win.hit && win.fade > 0
          onTriggered: {
            var amp = 26
            s1.x = (Math.random() - 0.5) * amp
            s2.x = (Math.random() - 0.5) * amp * 1.4
            s3.x = (Math.random() - 0.5) * amp
            s4.x = (Math.random() - 0.5) * amp * 1.2
            s5.x = (Math.random() - 0.5) * amp
            s6.x = (Math.random() - 0.5) * amp * 0.8
            bar1.y = Math.random() * corpse.height
            bar1.opacity = Math.random() < 0.7 ? 0.85 : 0
            bar2.y = Math.random() * corpse.height
            bar2.opacity = Math.random() < 0.6 ? 0.8 : 0
            drop1.y = Math.random() * corpse.height
            drop1.opacity = Math.random() < 0.5 ? 0.95 : 0
            staticLayer.x = (Math.random() - 0.5) * 40
          }
        }

        Item {
          id: s1
          width: parent.width; height: parent.height / 6; y: 0; clip: true
          Image {
            source: root.frame
            width: corpse.width; height: corpse.height; y: 0
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s2
          width: parent.width; height: parent.height / 6; y: parent.height / 6; clip: true
          Image {
            source: root.frame
            width: corpse.width; height: corpse.height; y: -parent.parent.height / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s3
          width: parent.width; height: parent.height / 6; y: parent.height * 2 / 6; clip: true
          Image {
            source: root.frame
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 2 / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s4
          width: parent.width; height: parent.height / 6; y: parent.height * 3 / 6; clip: true
          Image {
            source: root.frame
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 3 / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s5
          width: parent.width; height: parent.height / 6; y: parent.height * 4 / 6; clip: true
          Image {
            source: root.frame
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 4 / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s6
          width: parent.width; height: parent.height / 6; y: parent.height * 5 / 6; clip: true
          Image {
            source: root.frame
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 5 / 6
            fillMode: Image.Stretch; cache: false
          }
        }

        // Red static crawling over the corpse, burning up with the wash.
        Image {
          id: staticLayer
          anchors.fill: parent
          source: Qt.resolvedUrl("noise.jpg")
          fillMode: Image.PreserveAspectCrop
          cache: true
          opacity: win.wash
        }

        Rectangle {
          anchors.fill: parent
          color: "#ff2244"
          opacity: win.wash * 0.55
        }

        // Tear bars and a dropout block, heavy while they live.
        Rectangle {
          id: bar1
          width: parent.width
          height: 6
          color: "#ff003c"
          opacity: 0
        }
        Rectangle {
          id: bar2
          width: parent.width * 0.8
          height: 4
          color: "#00ffdd"
          opacity: 0
        }
        Rectangle {
          id: drop1
          width: parent.width * 0.55
          x: parent.width * 0.2
          height: 20
          color: "#05000a"
          opacity: 0
        }

        // The first frame is a strobe: the moment of death is bright.
        Rectangle {
          id: strobe
          anchors.fill: parent
          color: "#ff8899"
          opacity: 0

          NumberAnimation {
            id: strobeAnim
            target: strobe
            property: "opacity"
            to: 0
            duration: 70
          }
        }
      }
    }
  }
}
