import QtQuick

// What Enter does on a list's selected row, as a quiet word and a small ↵
// keycap ("Paste ↵", "Open ↵").
Row {
  id: hint
  required property var theme
  property string label: ""
  spacing: 6
  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: hint.label
    color: hint.theme.secondary
    font.family: hint.theme.textFontFamily
    font.letterSpacing: hint.theme.tracking(hint.theme.textFontFamily, hint.theme.px(11))
    font.pixelSize: hint.theme.px(11)
  }
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: 18; height: 18
    radius: 5
    color: hint.theme.tile
    Text {
      anchors.centerIn: parent
      text: "↵"
      color: hint.theme.secondary
      font.family: hint.theme.textFontFamily
      font.pixelSize: hint.theme.px(11)
    }
  }
}
