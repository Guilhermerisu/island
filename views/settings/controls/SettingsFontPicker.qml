import QtQuick
import "../../../components"

// A button showing the chosen custom font; clicking opens the searchable list
// of installed families (see SettingsView's fontPanel). `view` is the
// SettingsView, for its colours.
Rectangle {
  id: picker
  required property var view
  property string value: ""
  readonly property bool open: picker.view.fontPickerButton === picker
  implicitWidth: Math.max(140, label.implicitWidth + 32)
  implicitHeight: 28
  radius: 6
  color: open || pickMouse.containsMouse ? picker.view.wellHover : picker.view.well
  Behavior on color { MotionColorAnimation { theme: picker.view.host.theme } }
  Text {
    id: label
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.right: chevron.left
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    text: picker.value !== "" ? picker.value : "Pick a font"
    elide: Text.ElideRight
    color: picker.value !== "" ? picker.view.text : picker.view.textMuted
    font.family: picker.view.host.theme.textFontFamily
    font.pixelSize: picker.view.detailFontSize
  }
  Text {
    id: chevron
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    text: "󰅀"
    color: picker.view.textMuted
    font.family: picker.view.host.theme.fontFamily
    font.pixelSize: picker.view.host.theme.px(12)
  }
  MouseArea {
    id: pickMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: picker.open ? picker.view.fontPickerButton = null : picker.view.openFontPicker(picker)
  }
}
