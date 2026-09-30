import QtQuick
import QtQuick.Layouts

// macOS push button: small rounded rectangle, accent for the default action.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: button
  required property var view
  property string label: ""
  property bool primary: false
  signal clicked()
  implicitWidth: buttonText.implicitWidth + 24
  implicitHeight: 28
  radius: 6
  color: primary ? button.view.accent : buttonMouse.containsMouse ? button.view.wellHover : button.view.well
  Text {
    id: buttonText
    anchors.centerIn: parent
    text: button.label
    color: button.primary ? button.view.accentInk : button.view.text
    font.family: "Adwaita Sans"
    font.pixelSize: button.view.detailFontSize
    font.weight: button.primary ? Font.DemiBold : Font.Normal
  }
  MouseArea {
    id: buttonMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
