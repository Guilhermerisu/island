import QtQuick
import "../../../components"
import QtQuick.Layouts

// Pop-up button, as iOS's: the current choice in grey with up/down
// chevrons, boxed only while hovered or open; the choices open in a menu
// (see popMenu in SettingsView).
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
  implicitWidth: popLabel.implicitWidth + 36
  implicitHeight: 28
  // Nudged into the row's margin so the chevrons line up with the switches
  // and keycaps; the hover box reaches past them.
  transform: Translate { x: 8 }
  radius: 8
  color: open || popMouse.containsMouse ? pop.view.well : pop.view.host.theme.withAlpha(pop.view.well, 0)
  Behavior on color { MotionColorAnimation { theme: pop.view.host.theme } }
  scale: popMouse.pressed ? 0.98 : 1
  Behavior on scale { MotionAnimation { theme: pop.view.host.theme; pace: popMouse.pressed ? "press" : "standard" } }
  Text {
    id: popLabel
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: pop.currentLabel
    color: pop.view.textMuted
    font.family: pop.view.host.theme.textFontFamily
    font.letterSpacing: pop.view.host.theme.tracking(pop.view.host.theme.textFontFamily, pop.view.detailFontSize)
    font.pixelSize: pop.view.detailFontSize
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
        font.pixelSize: pop.view.host.theme.px(10)
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
