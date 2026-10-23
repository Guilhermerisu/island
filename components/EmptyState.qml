import QtQuick
import QtQuick.Layouts

// A view with nothing to list, as macOS draws it: a large dimmed symbol over
// a short message, centred in the space the list would take.
ColumnLayout {
  id: empty
  required property var host
  property string glyph: ""
  property string text: ""
  spacing: 8

  Text {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    Layout.topMargin: 18
    text: empty.glyph
    color: empty.host.theme.fill("strong")
    font.family: empty.host.theme.fontFamily
    font.pixelSize: empty.host.theme.px(34)
  }
  Text {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    Layout.bottomMargin: 18
    text: empty.text
    color: empty.host.theme.secondary
    font.family: empty.host.theme.textFontFamily
    font.letterSpacing: empty.host.theme.tracking(empty.host.theme.textFontFamily, empty.host.theme.px(13))
    font.pixelSize: empty.host.theme.px(13)
  }
}
