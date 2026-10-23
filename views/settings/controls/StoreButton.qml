import QtQuick
import "../../../components"

// App Store's capsule button: "Add" in the accent, "Remove" quieter.
Rectangle {
  id: button
  required property var view
  property bool added: false
  signal clicked()
  implicitWidth: Math.max(68, buttonText.implicitWidth + 28)
  implicitHeight: 26
  radius: height / 2
  color: Qt.rgba(0.46, 0.46, 0.5, buttonMouse.containsMouse ? 0.32 : 0.24)
  Behavior on color { MotionColorAnimation { theme: button.view.host.theme } }
  opacity: buttonMouse.pressed ? 0.5 : 1
  Behavior on opacity { MotionAnimation { theme: button.view.host.theme; pace: buttonMouse.pressed ? "press" : "fade" } }
  Text {
    id: buttonText
    anchors.centerIn: parent
    text: button.added ? "Remove" : "Add"
    color: button.added ? button.view.textMuted : button.view.accent
    font.family: button.view.host.theme.textFontFamily
    font.letterSpacing: button.view.host.theme.tracking(button.view.host.theme.textFontFamily, button.view.host.theme.px(13))
    font.pixelSize: button.view.host.theme.px(13)
    font.weight: button.added ? Font.Medium : Font.DemiBold
  }
  MouseArea {
    id: buttonMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
