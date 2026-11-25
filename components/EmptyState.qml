import QtQuick
import QtQuick.Layouts

// A view with nothing to list, as macOS draws it, straight on the island: a
// grey symbol, a short title and, when there is one, a line saying why.
// Its margins assume the 8 px spacing of the view's column around it, which
// makes about 20 px above the block and 22 px below.
ColumnLayout {
  id: empty
  required property var host
  property string glyph: ""
  property string text: ""
  property string detail: ""
  spacing: 0

  Text {
    Layout.fillWidth: true
    Layout.topMargin: 12
    horizontalAlignment: Text.AlignHCenter
    text: empty.glyph
    color: empty.host.theme.secondary
    font.family: empty.host.theme.fontFamily
    font.pixelSize: empty.host.theme.px(28)
  }
  Text {
    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.bottomMargin: empty.detail !== "" ? 0 : 14
    horizontalAlignment: Text.AlignHCenter
    text: empty.text
    color: empty.host.theme.text
    font.family: empty.host.theme.textFontFamily
    font.letterSpacing: empty.host.theme.tracking(empty.host.theme.textFontFamily, empty.host.theme.size.body)
    font.pixelSize: empty.host.theme.size.body
    font.weight: Font.DemiBold
  }
  Text {
    visible: empty.detail !== ""
    Layout.fillWidth: true
    Layout.topMargin: 3
    Layout.bottomMargin: 14
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: empty.detail
    color: empty.host.theme.secondary
    font.family: empty.host.theme.textFontFamily
    font.letterSpacing: empty.host.theme.tracking(empty.host.theme.textFontFamily, empty.host.theme.size.callout)
    font.pixelSize: empty.host.theme.size.callout
  }
}
