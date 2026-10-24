import QtQuick
import QtQuick.Effects
import "../../components"

// The round − (remove) or + (add) on a card in edit mode, as macOS's Edit
// Controls: a light disc centred on the curve of the card's top-left corner,
// popping in. `center` is the ControlCenter, for its colours.
Item {
  id: b
  required property var center
  property bool adding: false
  property bool shown: true
  // The card corner's radius: the badge sits on its curve.
  property real cornerRadius: 0
  property bool interactive: true
  property string tip: ""
  readonly property real inset: cornerRadius * (1 - Math.SQRT1_2)
  signal clicked()

  x: inset - width / 2
  y: inset - height / 2
  z: 2
  width: 20
  height: 20
  scale: shown ? (badgeMouse.pressed ? 0.85 : 1) : 0
  visible: scale > 0
  Behavior on scale { MotionAnimation { theme: b.center.host.theme; pace: badgeMouse.pressed ? "press" : "standard" } }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Qt.tint(b.center.well, b.center.host.theme.withAlpha(b.center.text, badgeMouse.containsMouse ? 0.9 : 0.72))
    Behavior on color { MotionColorAnimation { theme: b.center.host.theme } }
    layer.enabled: visible
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.55)
      shadowBlur: 0.4
      shadowVerticalOffset: 1
    }
  }
  Rectangle {
    anchors.centerIn: parent
    width: 9; height: 2; radius: 1
    color: b.center.host.theme.background
  }
  Rectangle {
    visible: b.adding
    anchors.centerIn: parent
    width: 2; height: 9; radius: 1
    color: b.center.host.theme.background
  }
  MouseArea {
    id: badgeMouse
    anchors.fill: parent
    anchors.margins: -4
    enabled: b.interactive
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: b.clicked()
  }
  Tooltip { theme: b.center.host.theme; text: b.interactive ? b.tip : "" }
}
