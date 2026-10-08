import QtQuick
import QtQuick.Effects
import "../../components"
import QtQuick.Layouts

// macOS Control Center slider: a translucent capsule with a white fill that
// ends in a round white knob, and the icon inside on the left. `center` is the
// ControlCenter, for its colours.
Item {
  id: s
  required property var center
  property string icon: ""
  property real value: 0
  signal moved(real value)
  readonly property real clamped: Math.max(0, Math.min(1, value))
  // Animate the level only: the island's changing width must not restart
  // the fill animation or make a fixed volume appear to change.
  property real shownLevel: clamped
  Behavior on shownLevel {
    enabled: !sliderMouse.pressed
    MotionAnimation { theme: center.host.theme; pace: "quick" }
  }

  Layout.fillWidth: true
  Layout.preferredHeight: 38

  Item {
    id: track
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 34
    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: center.host.theme.withAlpha(center.text, sliderMouse.containsMouse ? 0.22 : 0.17)
      border.width: 1
      border.color: center.host.theme.withAlpha(center.text, 0.06)
      Behavior on color { MotionColorAnimation { theme: center.host.theme } }
    }
    Rectangle {
      id: sliderFill
      height: parent.height
      radius: height / 2
      width: height + (parent.width - height) * s.shownLevel
      color: "#ececec"
    }
    // The knob, lifted off the fill by a soft shadow.
    Rectangle {
      id: knob
      x: sliderFill.width - width
      width: parent.height
      height: parent.height
      radius: height / 2
      color: "#ffffff"
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.45)
        shadowBlur: 0.35
        shadowHorizontalOffset: -0.5
        shadowVerticalOffset: 0.5
      }
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 11
      anchors.verticalCenter: parent.verticalCenter
      text: s.icon
      color: sliderFill.width > x + width ? "#5c5c60" : center.textMuted
      font.family: center.iconFont
      font.pixelSize: center.host.theme.px(18)
    }
  }
  MouseArea {
    id: sliderMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    function apply(x) { s.moved(Math.max(0, Math.min(1, (x - track.height / 2) / (track.width - track.height)))) }
    onPressed: function(e) { apply(e.x) }
    onPositionChanged: function(e) { if (pressed) apply(e.x) }
    onWheel: function(e) { s.moved(Math.max(0, Math.min(1, s.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
  }
}
