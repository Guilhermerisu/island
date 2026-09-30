import QtQuick
import QtQuick.Layouts

// The small switch System Settings uses in its lists.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: sw
  required property var view
  property bool checked: false
  signal toggled(bool checked)
  implicitWidth: 34
  implicitHeight: 20
  radius: 10
  color: checked ? sw.view.accent : sw.view.well
  Behavior on color { ColorAnimation { duration: sw.view.animDuration; easing.type: Easing.OutCubic } }
  Rectangle {
    width: 16; height: 16; radius: 8
    y: 2
    x: sw.checked ? sw.width - width - 2 : 2
    color: "#ffffff"
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.12)
    Behavior on x { NumberAnimation { duration: sw.view.animDuration; easing.type: Easing.OutCubic } }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled(!sw.checked)
  }
}
