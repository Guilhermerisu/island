import QtQuick

// Search row shared by the switchers and list views, styled like the one in
// Settings' sidebar: a rounded grey field with a magnifier glyph and a text
// input with a placeholder. Keys the input doesn't use itself (arrows,
// Enter, Esc, …) are handed to `keyPressed` for the owner to act on.
Rectangle {
  id: field
  required property var host
  property string placeholder: "Search"
  readonly property alias text: input.text
  signal keyPressed(var event)

  function clear() { input.text = "" }
  function focusInput() { input.forceActiveFocus() }

  height: Math.max(36, host.theme.px(14) + 22)
  radius: height / 2
  color: host.theme.fill("subtle")

  Text {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: 11
    anchors.verticalCenter: parent.verticalCenter
    text: "󰍉"
    color: field.host.theme.placeholder
    font.family: field.host.theme.fontFamily
    font.pixelSize: field.host.theme.px(15)
  }
  TextInput {
    id: input
    anchors.left: icon.right
    anchors.leftMargin: 8
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    color: field.host.theme.text
    selectionColor: field.host.theme.accentFill("ring")
    selectedTextColor: field.host.theme.text
    font.family: field.host.theme.textFontFamily
    font.letterSpacing: field.host.theme.tracking(field.host.theme.textFontFamily, field.host.theme.px(14))
    font.pixelSize: field.host.theme.px(14)
    clip: true
    Keys.onPressed: function(event) { field.keyPressed(event) }
    // Starts a hair right of the caret so the caret doesn't sit on the
    // first letter.
    Text {
      anchors.fill: parent
      anchors.leftMargin: 2
      verticalAlignment: Text.AlignVCenter
      visible: input.text === ""
      text: field.placeholder
      color: field.host.theme.placeholder
      font: input.font
      elide: Text.ElideRight
    }
  }
}
