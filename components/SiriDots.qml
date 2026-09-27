import QtQuick
import QtQuick.Effects

// Siri's thinking indicator in the Dynamic Island: a ring of white dots that
// shrink around the circle, spinning, with a soft white glow.
Item {
  id: dots
  property bool running: true
  readonly property var sizes: [9, 8.5, 7.5, 6.5, 5, 3.5]
  readonly property real orbit: 12
  implicitWidth: 36
  implicitHeight: 36

  // The glow captures `ring` without its own transform, so the dots spin
  // inside it.
  Item {
    id: ring
    anchors.fill: parent
    visible: false
    Item {
      id: spinner
      anchors.fill: parent
      Repeater {
        model: dots.sizes.length
        delegate: Rectangle {
          required property int index
          // Spread over most of the circle, leaving a gap after the smallest.
          readonly property real angle: -Math.PI * 0.75 + index * (Math.PI * 2 / 7.5)
          width: dots.sizes[index]
          height: width
          radius: width / 2
          color: "#ffffff"
          x: spinner.width / 2 + Math.cos(angle) * dots.orbit - width / 2
          y: spinner.height / 2 + Math.sin(angle) * dots.orbit - height / 2
        }
      }
      // One turn every 2.4 s, stepped ~40 times a second rather than at the
      // display's refresh rate (each frame also re-runs the glow).
      Timer {
        interval: 25
        repeat: true
        running: dots.running && dots.visible
        onTriggered: spinner.rotation = (spinner.rotation + 360 * 25 / 2400) % 360
      }
    }
  }

  MultiEffect {
    source: ring
    anchors.fill: ring
    autoPaddingEnabled: true
    shadowEnabled: true
    shadowColor: "#ffffff"
    shadowOpacity: 0.85
    shadowBlur: 0.7
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
    blurMax: 16
  }
}
