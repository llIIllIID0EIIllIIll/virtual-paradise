import QtQuick
import Quickshell
import Quickshell.Wayland

// Virtual☆Paradise — Window Death
//
// Where a window just closed, its own corpse tears apart: the burst shows a
// captured frame of the window - border and all - cut into horizontal slices
// that jump around while a neon static wash burns through, then nothing.
// The window does not fade away politely; it glitches to death on screen,
// border included.
//
// The burst is placed exactly over the captured rectangle
// (VP_DEATH_RECT="x,y,w,h", VP_DEATH_IMAGE=the captured frame) and is
// click-through: it is a corpse, not a surface. It must appear in a single
// frame - the compositor's layer animation is disabled for this namespace
// in hypr/looknfeel.lua, or the glitch would slide in and look fake.

ShellRoot {
  id: root

  property string rectEnv: Quickshell.env("VP_DEATH_RECT") || ""
  property string frameImage: Quickshell.env("VP_DEATH_IMAGE") || ""
  property var rect: (function () {
    var p = rectEnv.split(",")
    if (p.length !== 4) return { x: 0, y: 0, width: 0, height: 0 }
    return { x: +p[0], y: +p[1], width: +p[2], height: +p[3] }
  })()

  // The whole burst lives and dies in four tenths of a second: long
  // enough to read as a death, short enough to stay out of the layout
  // reflow's way.
  Timer {
    interval: 420
    running: true
    onTriggered: Qt.quit()
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
      property bool hit: root.rect.width > 0 && root.rect.height > 0
        && root.rect.x < geo.x + geo.width && root.rect.x + root.rect.width > geo.x
        && root.rect.y < geo.y + geo.height && root.rect.y + root.rect.height > geo.y

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      margins {
        left: Math.max(0, root.rect.x - geo.x)
        top: Math.max(0, root.rect.y - geo.y)
        right: Math.max(0, (geo.x + geo.width) - (root.rect.x + root.rect.width))
        bottom: Math.max(0, (geo.y + geo.height) - (root.rect.y + root.rect.height))
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

      // The corpse fades at the very end, so the burst does not cut.
      Timer {
        interval: 280
        running: win.hit
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

      // The neon wash burns up through the corpse instead of appearing at
      // full strength: the first frames still show the window itself.
      NumberAnimation {
        target: win
        property: "wash"
        from: 0.15
        to: 0.85
        duration: 220
        running: win.hit
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
            source: root.frameImage
            width: corpse.width; height: corpse.height; y: -0
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s2
          width: parent.width; height: parent.height / 6; y: parent.height / 6; clip: true
          Image {
            source: root.frameImage
            width: corpse.width; height: corpse.height; y: -parent.parent.height / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s3
          width: parent.width; height: parent.height / 6; y: parent.height * 2 / 6; clip: true
          Image {
            source: root.frameImage
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 2 / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s4
          width: parent.width; height: parent.height / 6; y: parent.height * 3 / 6; clip: true
          Image {
            source: root.frameImage
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 3 / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s5
          width: parent.width; height: parent.height / 6; y: parent.height * 4 / 6; clip: true
          Image {
            source: root.frameImage
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 4 / 6
            fillMode: Image.Stretch; cache: false
          }
        }
        Item {
          id: s6
          width: parent.width; height: parent.height / 6; y: parent.height * 5 / 6; clip: true
          Image {
            source: root.frameImage
            width: corpse.width; height: corpse.height; y: -parent.parent.height * 5 / 6
            fillMode: Image.Stretch; cache: false
          }
        }

        // Neon static crawling over the corpse, burning up with the wash:
        // the same violet -> magenta -> sakura noise as the login splash.
        Image {
          id: staticLayer
          anchors.fill: parent
          source: Qt.resolvedUrl("noise.jpg")
          fillMode: Image.PreserveAspectCrop
          cache: true
          opacity: win.wash
        }

        // The wash is the gradient itself, not a flat tint: the corpse
        // dies from violet on the left to sakura on the right.
        Rectangle {
          anchors.fill: parent
          opacity: win.wash * 0.55
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#7a1fd0" }
            GradientStop { position: 0.5; color: "#ff2bd6" }
            GradientStop { position: 1.0; color: "#ffb7d5" }
          }
        }

        // Tear bars and a dropout block, heavy while they live.
        Rectangle {
          id: bar1
          width: parent.width
          height: 6
          color: "#ff2bd6"
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
          color: "#ffc4dd"
          opacity: 0.5

          NumberAnimation {
            target: strobe
            property: "opacity"
            to: 0
            duration: 70
            running: true
          }
        }
      }
    }
  }
}
