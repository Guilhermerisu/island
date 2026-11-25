import QtQuick
import QtQuick.Layouts

// A view with nothing to list, as macOS draws it, straight on the island: a
// grey symbol in a round card, a short title and, when there is one, a line
// saying why. Its margins assume the 8 px spacing of the view's column
// around it, which makes 12 px above the circle and 18 px below the text.
ColumnLayout {
  id: empty
  required property var host
  property string glyph: ""
  property string text: ""
  property string detail: ""
  spacing: 0

  Rectangle {
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: 4
    implicitWidth: 44
    implicitHeight: 44
    radius: 22
    color: empty.host.theme.card
    Text {
      anchors.centerIn: parent
      text: empty.glyph
      color: empty.host.theme.tertiary
      font.family: empty.host.theme.fontFamily
      font.pixelSize: empty.host.theme.px(22)
    }
  }
  Text {
    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.bottomMargin: empty.detail !== "" ? 0 : 10
    horizontalAlignment: Text.AlignHCenter
    text: empty.text
    color: empty.host.theme.text
    font.family: empty.host.theme.textFontFamily
    font.letterSpacing: empty.host.theme.tracking(empty.host.theme.textFontFamily, empty.host.theme.px(14))
    font.pixelSize: empty.host.theme.px(14)
    font.weight: Font.DemiBold
  }
  Text {
    visible: empty.detail !== ""
    Layout.fillWidth: true
    Layout.topMargin: 2
    Layout.bottomMargin: 10
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: empty.detail
    color: empty.host.theme.secondary
    font.family: empty.host.theme.textFontFamily
    font.letterSpacing: empty.host.theme.tracking(empty.host.theme.textFontFamily, empty.host.theme.px(12))
    font.pixelSize: empty.host.theme.px(12)
  }
}
