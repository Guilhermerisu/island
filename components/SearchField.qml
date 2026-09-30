import QtQuick

// Search row shared by the switchers and list views: a magnifier glyph and a
// text input with a placeholder. Keys the input doesn't use itself (arrows,
// Enter, Esc, …) are handed to `keyPressed` for the owner to act on.
Item {
  id: field
  required property var host
  property string placeholder: "Search…"
  property int iconSize: 17
  property int fontSize: 14
  property int inset: 4
  readonly property alias text: input.text
  signal keyPressed(var event)

  function clear() { input.text = "" }
  function focusInput() { input.forceActiveFocus() }

  height: 30

  Text {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: field.inset
    anchors.verticalCenter: parent.verticalCenter
    text: "󰍉"
    color: field.host.theme.muted
    font.family: field.host.theme.fontFamily
    font.pixelSize: field.iconSize
  }
  TextInput {
    id: input
    anchors.left: icon.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: field.inset
    anchors.verticalCenter: parent.verticalCenter
    color: field.host.theme.text
    selectionColor: field.host.theme.withAlpha(field.host.theme.accent, 0.4)
    selectedTextColor: field.host.theme.text
    font.family: "Adwaita Sans"
    font.pixelSize: field.fontSize
    clip: true
    Keys.onPressed: function(event) { field.keyPressed(event) }
    Text {
      anchors.fill: parent
      verticalAlignment: Text.AlignVCenter
      visible: input.text === ""
      text: field.placeholder
      color: field.host.theme.muted
      font: input.font
    }
  }
}
