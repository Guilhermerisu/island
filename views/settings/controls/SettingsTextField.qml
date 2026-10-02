import QtQuick
import "../../../components"

// One-line text field. `committed` fires with the trimmed text on Enter or
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
  color: input.activeFocus || fieldMouse.containsMouse ? field.view.wellHover : field.view.well
  border.width: input.activeFocus ? 2 : 0
  border.color: field.view.host.theme.withAlpha(field.view.accent, 0.6)
  Behavior on color { MotionColorAnimation { theme: field.view.host.theme } }

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
    font.family: "Adwaita Sans"
    font.pixelSize: field.view.detailFontSize - 1
    onAccepted: { field.commit(); field.view.forceActiveFocus() }
    onActiveFocusChanged: if (!activeFocus) field.commit()
    Keys.onEscapePressed: function(event) {
      text = field.value
      field.view.forceActiveFocus()
      event.accepted = true
    }
  }
}
