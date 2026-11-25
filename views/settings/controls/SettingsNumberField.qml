import QtQuick
import "../../../components"

// A whole number typed in an inset field, as SettingsTextField is. Enter or
// leaving the field commits it, Esc puts back `value`. `picked` fires with the
// new value, always within from–to.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: field
  required property var view
  property int value: 0
  property int from: 0
  property int to: 100
  // Shown after the number, as "px".
  property string suffix: ""
  signal picked(int value)

  implicitWidth: 72
  implicitHeight: 26
  radius: 7
  color: field.view.insetFill
  border.width: 1
  border.color: field.view.ink(input.activeFocus ? 0.18 : 0.12)
  Behavior on color { MotionColorAnimation { theme: field.view.host.theme } }
  SettingsFocusRing { view: field.view; shown: input.activeFocus }

  onValueChanged: if (!input.activeFocus) input.text = String(value)
  Component.onCompleted: input.text = String(value)
  // An empty field keeps the value; a number past the limits is clamped.
  function commit() {
    var next = input.text === "" ? field.value : Math.max(field.from, Math.min(field.to, Number(input.text)))
    input.text = String(next)
    if (next !== field.value) field.picked(next)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.IBeamCursor
    onClicked: input.forceActiveFocus()
  }
  TextInput {
    id: input
    anchors.left: parent.left
    anchors.leftMargin: 9
    anchors.right: suffixText.visible ? suffixText.left : parent.right
    anchors.rightMargin: suffixText.visible ? 3 : 9
    anchors.verticalCenter: parent.verticalCenter
    horizontalAlignment: TextInput.AlignRight
    clip: true
    // Digits only, any size, so Enter clamps a number past `to` rather than
    // ignoring it.
    validator: RegularExpressionValidator { regularExpression: /[0-9]*/ }
    maximumLength: 4
    inputMethodHints: Qt.ImhDigitsOnly
    color: field.view.text
    selectionColor: field.view.accent
    selectedTextColor: field.view.accentInk
    font.family: field.view.host.theme.textFontFamily
    font.pixelSize: field.view.detailFontSize
    font.features: { "tnum": 1 }
    onAccepted: { field.commit(); field.view.forceActiveFocus() }
    onActiveFocusChanged: if (!activeFocus) field.commit()
    Keys.onEscapePressed: function(event) {
      text = String(field.value)
      field.view.forceActiveFocus()
      event.accepted = true
    }
  }
  Text {
    id: suffixText
    anchors.right: parent.right
    anchors.rightMargin: 9
    anchors.verticalCenter: parent.verticalCenter
    visible: field.suffix !== ""
    text: field.suffix
    color: field.view.textMuted
    font: input.font
  }
}
