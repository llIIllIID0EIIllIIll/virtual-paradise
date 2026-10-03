import QtQuick
import qs.Commons
import qs.Ui

// Floating island surface drawn behind one bar section.
//
// Everything here is derived from Color tokens, so the islands re-tint with
// the active theme. The island only becomes its own opaque surface when the
// bar asks for it; a transparent bar keeps the rim and drops the fill so the
// desktop shows through.
Item {
  id: root

  // Which edge of the bar this island hugs. Drives the rim gradient so the
  // brightest accent always sits on the outer edge of the island.
  property string edge: "center"
  property real radius: 0
  property real fillOpacity: 1

  readonly property bool filled: fillOpacity > 0

  Rectangle {
    id: surface

    anchors.fill: parent
    radius: root.radius
    color: Color.bar.background
    opacity: root.fillOpacity
  }

  // A one-stop sheen along the leading edge. Cheap depth cue: it reads as a
  // light source catching the top of the island without a blur pass.
  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: Math.max(0, root.radius - 1)
    color: "transparent"
    opacity: 0.55
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop {
        position: 0.0
        color: Qt.alpha(Color.foreground, 0.07)
      }
      GradientStop {
        position: 0.45
        color: "transparent"
      }
    }
  }

  // Accent rim. Colour pairs come from the theme rather than literals so a
  // palette swap carries over to the bar chrome.
  BorderOverlay {
    radius: root.radius
    borderSpec: ({
      color: Color.accent,
      widths: { top: 1, right: 1, bottom: 1, left: 1 },
      gradient: {
        enabled: true,
        angle: root.parent && root.parent.vertical ? 90 : 0,
        colors: root.edge === "left"
          ? [Qt.alpha(Color.accent, 0.55), Qt.alpha(Color.muted, 0.22)]
          : root.edge === "right"
            ? [Qt.alpha(Color.muted, 0.22), Qt.alpha(Color.accent, 0.55)]
            : [Qt.alpha(Color.accent, 0.5), Qt.alpha(Color.muted, 0.3), Qt.alpha(Color.accent, 0.5)]
      }
    })
  }
}