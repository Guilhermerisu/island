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
  signal committed(string value)
  implicitWidth: 200
  implicitHeight: 28
  radius: 6
  color: field.view.host.theme.solid(fieldMouse.containsMouse && !input.activeFocus ? "subtle" : "quiet")
  border.width: 1
  border.color: field.view.host.theme.fill(input.activeFocus ? "strong" : "raised")
  Behavior on color { MotionColorAnimation { theme: field.view.host.theme } }
  // Focus ring: settles in from slightly larger, like macOS's.
  Rectangle {
    anchors.centerIn: parent
    width: parent.width + 6
    height: parent.height + 6
    radius: parent.radius + 3
    color: "transparent"
    border.width: 3
    border.color: field.view.host.theme.accentFill("ring")
    opacity: input.activeFocus ? 1 : 0
    scale: input.activeFocus ? 1 : 1.12
    Behavior on opacity { MotionAnimation { theme: field.view.host.theme; pace: "fade"; curve: "fade" } }
    Behavior on scale { MotionAnimation { theme: field.view.host.theme; pace: "standard" } }
  }

  onValueChanged: if (!input.activeFocus) input.text = value
  Component.onCompleted: input.text = value
  function commit() {
    var next = input.text.trim()
    input.text = next
    if (next !== field.value) field.committed(next)
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
    visible: input.text === ""
    text: field.placeholder
    elide: Text.ElideRight
    color: field.view.textMuted
    font: input.font
  }
  TextInput {
    id: input
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    color: field.view.text
    selectionColor: field.view.accent
    selectedTextColor: field.view.accentInk
    font.family: field.view.host.theme.textFontFamily
    font.letterSpacing: field.view.host.theme.tracking(field.view.host.theme.textFontFamily, field.view.detailFontSize)
    font.pixelSize: field.view.detailFontSize
    onAccepted: { field.commit(); field.view.forceActiveFocus() }
    onActiveFocusChanged: if (!activeFocus) field.commit()
    Keys.onEscapePressed: function(event) {
      text = field.value
      field.view.forceActiveFocus()
      event.accepted = true
    }
  }
}
