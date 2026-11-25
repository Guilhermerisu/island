import QtQuick
import "../../../components"
import QtQuick.Layouts

// macOS push button: small rounded rectangle, accent for the default action.
// `small` is the compact one set in a row (Speed Test's Start): 12 medium,
// 5/12 padding, radius 8.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: button
  required property var view
  property string label: ""
  property bool primary: false
  property bool small: false
  readonly property int textSize: small ? button.view.host.theme.size.callout : button.view.detailFontSize
  signal clicked()
  implicitWidth: buttonText.implicitWidth + 24
  implicitHeight: small ? buttonText.implicitHeight + 10 : 28
  radius: small ? 8 : 6
  color: primary ? button.view.accent : buttonMouse.containsMouse ? button.view.wellHover : button.view.well
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
    font.weight: button.primary ? Font.DemiBold : button.small ? Font.Medium : Font.Normal
  }
  MouseArea {
    id: buttonMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
