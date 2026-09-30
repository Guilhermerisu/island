import QtQuick
import QtQuick.Layouts

// Pop-up button: the current choice with up/down chevrons; the choices open
// in a menu (see popMenu below).
// `view` is the SettingsView, for its colours.
Rectangle {
  id: pop
  required property var view
  property var options: []   // [{ label, value }]
  property var value
  signal picked(var value)
  readonly property string currentLabel: {
    for (var i = 0; i < options.length; i++) if (options[i].value === value) return options[i].label
    return ""
  }
  readonly property bool open: pop.view.menuButton === pop
  implicitWidth: Math.max(96, popLabel.implicitWidth + 40)
  implicitHeight: 24
  radius: 6
  color: open || popMouse.containsMouse ? pop.view.wellHover : pop.view.well
  Text {
    id: popLabel
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: pop.currentLabel
    color: pop.view.text
    font.family: "Adwaita Sans"
    font.pixelSize: 13
  }
  Column {
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: -5
    Repeater {
      model: ["󰅃", "󰅀"]
      delegate: Text {
        required property string modelData
        text: modelData
        color: pop.view.textMuted
        font.family: pop.view.host.theme.fontFamily
        font.pixelSize: 10
      }
    }
  }
  MouseArea {
    id: popMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pop.open ? pop.view.menuButton = null : pop.view.openMenu(pop)
  }
}
