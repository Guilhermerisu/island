import QtQuick
import QtQuick.Layouts

// A device in a card's picker, as macOS's Sound output list: a round badge,
// lit for the one in use, and the device's name. `center` is the
// ControlCenter, for its colours.
Rectangle {
  id: row
  required property var center
  required property var device
  property bool selected: false
  // The badge's glyph when the name doesn't say headphones.
  property string icon: "󰓃"
  signal picked()
  readonly property string name: String(device.description || device.nickname || device.name || "")

  Layout.fillWidth: true
  Layout.preferredHeight: 32
  radius: height / 2
  color: rowMouse.pressed ? center.host.theme.fill("raised") : rowMouse.containsMouse ? center.host.theme.fill("subtle") : "transparent"

  Rectangle {
    id: badge
    anchors.left: parent.left
    anchors.leftMargin: 3
    anchors.verticalCenter: parent.verticalCenter
    width: 26; height: 26; radius: 13
    color: row.selected ? row.center.accent : row.center.well
    Text {
      anchors.centerIn: parent
      text: /head|ear|buds|airpods/i.test(row.name) ? "󰋋" : row.icon
      color: row.selected ? row.center.badgeOnInk : row.center.text
      font.family: row.center.iconFont
      font.pixelSize: row.center.host.theme.px(14)
    }
  }
  Text {
    anchors.left: badge.right
    anchors.leftMargin: 9
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: row.name
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: row.center.text
    font.family: row.center.host.theme.textFontFamily
    font.letterSpacing: row.center.host.theme.tracking(row.center.host.theme.textFontFamily, row.center.host.theme.px(12))
    font.pixelSize: row.center.host.theme.px(12)
    font.weight: row.selected ? Font.Medium : Font.Normal
  }
  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.picked()
  }
}
