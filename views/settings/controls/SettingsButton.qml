import QtQuick
import "../../../components"
import QtQuick.Layouts

// macOS push button: 26 tall, radius 7, 12 medium text 12 in from each
// side, grey (#2c2c2e), or the accent for the default action. `small` is
// kept for the rows that ask for it; every button is this size now.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: button
  required property var view
  property string label: ""
  property bool primary: false
  property bool small: false
  readonly property int textSize: button.view.host.theme.px(12)
  signal clicked()
  implicitWidth: buttonText.implicitWidth + 24
  implicitHeight: Math.max(26, buttonText.implicitHeight + 8)
  radius: 7
  color: primary ? button.view.accent
    : buttonMouse.containsMouse ? Qt.lighter(button.view.controlFill, 1.15) : button.view.controlFill
  Behavior on color { MotionColorAnimation { theme: button.view.host.theme } }
  scale: buttonMouse.pressed ? 0.97 : 1
  Behavior on scale { id: scaleMotion; MotionAnimation { theme: button.view.host.theme; pace: towards(scaleMotion.targetValue, buttonMouse.pressed ? "press" : "standard") } }
  Text {
    id: buttonText
    anchors.centerIn: parent
    text: button.label
    color: button.primary ? button.view.accentInk : button.view.text
    font.family: button.view.host.theme.textFontFamily
    font.letterSpacing: button.view.host.theme.tracking(button.view.host.theme.textFontFamily, button.textSize)
    font.pixelSize: button.textSize
    font.weight: button.primary ? Font.DemiBold : Font.Medium
  }
  MouseArea {
    id: buttonMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
