import QtQuick

// What Enter does on a list's selected row, as a quiet word and a small ↵
// keycap ("Paste ↵", "Open ↵"): the word 12 px tertiary, the keycap 22 px
// tall and at least as wide, a shade lighter than the selected row's well
// so it doesn't vanish into it.
Row {
  id: hint
  required property var theme
  property string label: ""
  spacing: 6
  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: hint.label
    color: hint.theme.tertiary
    font.family: hint.theme.textFontFamily
    font.letterSpacing: hint.theme.tracking(hint.theme.textFontFamily, hint.theme.px(12))
    font.pixelSize: hint.theme.px(12)
  }
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(22, keyLabel.implicitWidth + 14)
    height: 22
    radius: 6
    color: hint.theme.wellHover
    Text {
      id: keyLabel
      anchors.centerIn: parent
      text: "↵"
      color: "#d1d1d6"
      font.family: hint.theme.textFontFamily
      font.pixelSize: hint.theme.px(11)
      font.weight: Font.Medium
    }
  }
}
