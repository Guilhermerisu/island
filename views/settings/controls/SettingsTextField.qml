import QtQuick
import "../../../components"

// One-line text field, inset as macOS's, with its focus ring. `committed` fires with the trimmed text on Enter or
// when the field loses focus, only if it changed; Esc puts back `value`.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: field
  required property var view
  property string value: ""
  property string placeholder: ""
  // Shows dots, for a password.
  property bool secret: false
  // Forgets the text once committed: a password that's written, never shown.
  property bool writeOnly: false
  // A glyph before the text (a pin for a place), or none.
  property string icon: ""
  // A value set in its row (the hostname): 160 wide, the text to the right.
  property bool inline: false
  signal committed(string value)
  // As it's typed, before it's committed.
  signal edited(string value)
  implicitWidth: inline ? 160 : 200
  implicitHeight: 26
  radius: 7
  color: field.view.insetFill
  border.width: 1
  border.color: field.view.ink(input.activeFocus ? 0.18 : 0.12)
  Behavior on color { MotionColorAnimation { theme: field.view.host.theme } }
  SettingsFocusRing { view: field.view; shown: input.activeFocus }

  onValueChanged: if (!input.activeFocus) input.text = value
  Component.onCompleted: input.text = value
  function commit() {
    // A password's spaces are its own.
    var next = field.secret ? input.text : input.text.trim()
    input.text = next
    if (next !== field.value) field.committed(next)
    if (field.writeOnly) input.text = ""
  }

  MouseArea {
    id: fieldMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.IBeamCursor
    onClicked: input.forceActiveFocus()
  }
  Text {
    anchors.fill: input
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: input.horizontalAlignment
    visible: input.text === ""
    text: field.placeholder
    elide: Text.ElideRight
    color: field.view.textMuted
    font: input.font
  }
  Text {
    id: fieldIcon
    visible: field.icon !== ""
    anchors.left: parent.left
    anchors.leftMargin: 9
    anchors.verticalCenter: parent.verticalCenter
    text: field.icon
    color: field.view.textMuted
    font.family: field.view.host.theme.fontFamily
    font.pixelSize: field.view.host.theme.px(14)
  }
  TextInput {
    id: input
    anchors.left: parent.left
    anchors.leftMargin: field.icon !== "" ? 30 : 9
    anchors.right: parent.right
    anchors.rightMargin: 9
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    echoMode: field.secret ? TextInput.Password : TextInput.Normal
    horizontalAlignment: field.inline ? TextInput.AlignRight : TextInput.AlignLeft
    color: field.view.text
    selectionColor: field.view.accent
    selectedTextColor: field.view.accentInk
    font.family: field.view.host.theme.textFontFamily
    readonly property int textSize: field.view.host.theme.px(13)
    font.letterSpacing: field.view.host.theme.tracking(field.view.host.theme.textFontFamily, textSize)
    font.pixelSize: textSize
    onTextEdited: field.edited(field.secret ? text : text.trim())
    onAccepted: { field.commit(); field.view.forceActiveFocus() }
    onActiveFocusChanged: if (!activeFocus) field.commit()
    Keys.onEscapePressed: function(event) {
      text = field.value
      field.view.forceActiveFocus()
      event.accepted = true
    }
  }
}
