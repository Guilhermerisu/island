import QtQuick
import "../../../components"

// App Store's capsule button: "+ Add" on a tint of the accent; "Remove"
// smaller on a faint grey, its text brightening only under the pointer, so
// the destructive choice isn't the loudest thing on the row.
Rectangle {
  id: button
  required property var view
  property bool added: false
  signal clicked()
  implicitWidth: Math.max(button.added ? 64 : 72, label.implicitWidth + (button.added ? 24 : 32))
  implicitHeight: button.added ? 26 : 30
  radius: height / 2
  color: button.added ? Qt.rgba(0.46, 0.46, 0.5, buttonMouse.containsMouse ? 0.24 : 0.14)
    : button.view.host.theme.accentFill(buttonMouse.containsMouse ? "medium" : "soft")
  Behavior on color { MotionColorAnimation { theme: button.view.host.theme } }
  opacity: buttonMouse.pressed ? 0.5 : 1
  Behavior on opacity { MotionAnimation { theme: button.view.host.theme; pace: buttonMouse.pressed ? "press" : "fade" } }
  Row {
    id: label
    anchors.centerIn: parent
    spacing: 6
    Text {
      visible: !button.added
      anchors.verticalCenter: parent.verticalCenter
      text: "󰐕"
      color: button.view.accent
      font.family: button.view.host.theme.fontFamily
      font.pixelSize: button.view.host.theme.px(14)
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: button.added ? "Remove" : "Add"
      color: button.added ? (buttonMouse.containsMouse ? button.view.text : button.view.textMuted) : button.view.accent
      Behavior on color { MotionColorAnimation { theme: button.view.host.theme } }
      readonly property int size: button.view.host.theme.px(button.added ? 12 : 13)
      font.family: button.view.host.theme.textFontFamily
      font.letterSpacing: button.view.host.theme.tracking(button.view.host.theme.textFontFamily, size)
      font.pixelSize: size
      font.weight: button.added ? Font.Medium : Font.DemiBold
    }
  }
  MouseArea {
    id: buttonMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
