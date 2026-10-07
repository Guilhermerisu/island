import QtQuick
import "../../components"
import QtQuick.Layouts

// macOS Control Center slider: a capsule with a white fill that ends in a
// round knob, and the icon inside on the left. `center` is the ControlCenter,
// for its colours.
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

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: sliderMouse.containsMouse ? center.wellHover : center.well
  }
  Rectangle {
    id: sliderFill
    height: parent.height
    radius: height / 2
    width: height + (parent.width - height) * s.shownLevel
    color: center.text
  }
  Rectangle {
    x: sliderFill.width - width
    width: parent.height
    height: parent.height
    radius: height / 2
    color: "#ffffff"
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.14)
  }
  Text {
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    text: s.icon
    color: sliderFill.width - parent.height > x + width ? center.host.theme.background : center.textMuted
    font.family: center.iconFont
    font.pixelSize: center.host.theme.px(18)
  }
  MouseArea {
    id: sliderMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    function apply(x) { s.moved(Math.max(0, Math.min(1, (x - height / 2) / (width - height)))) }
    onPressed: function(e) { apply(e.x) }
    onPositionChanged: function(e) { if (pressed) apply(e.x) }
    onWheel: function(e) { s.moved(Math.max(0, Math.min(1, s.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
  }
}
