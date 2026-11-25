import QtQuick
import "../../../components"

// Number field with up and down arrows beside it, as macOS's stepper. Type a
// number (Enter or leaving the field commits it), click or hold an arrow, press
// ↑/↓ in the field or scroll over it (not while the page is scrolling past
// it). `picked` fires with the new value, always whole and within from–to.
// `view` is the SettingsView, for its colours.
Item {
  id: stepper
  required property var view
  property int value: 0
  property int from: 0
  property int to: 100
  property int step: 1
  // Shown after the number, as "px".
  property string suffix: ""
  signal picked(int value)

  implicitWidth: 96
  implicitHeight: 26

  function clamp(v) { return Math.max(stepper.from, Math.min(stepper.to, Math.round(v))) }
  function pick(v) {
    var next = clamp(v)
    input.text = String(next)
    if (next !== stepper.value) stepper.picked(next)
  }
  // What's typed, or the value while the field is empty or not being edited.
  function current() { return input.activeFocus && input.text !== "" ? Number(input.text) : stepper.value }
  function nudge(steps) { pick(current() + steps * stepper.step) }
  // Wheel travel not yet a whole notch (120), so a touchpad's stream of small
  // deltas steps as a mouse wheel's clicks do.
  property real wheelRest: 0

  onValueChanged: if (!input.activeFocus) input.text = String(value)
  Component.onCompleted: input.text = String(value)

  Rectangle {
    id: field
    anchors.left: parent.left
    anchors.right: arrows.left
    anchors.rightMargin: 4
    height: parent.height
    // Inset as SettingsTextField is.
    radius: 7
    color: stepper.view.insetFill
    border.width: 1
    border.color: stepper.view.ink(input.activeFocus ? 0.18 : 0.12)
    Behavior on color { MotionColorAnimation { theme: stepper.view.host.theme } }
    SettingsFocusRing { view: stepper.view; shown: input.activeFocus }

    MouseArea {
      id: fieldMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.IBeamCursor
      onClicked: input.forceActiveFocus()
      // A scroll that's moving the page (or a sideways one) goes on to it.
      onWheel: function(wheel) {
        var dy = wheel.angleDelta.y
        if (dy === 0 || stepper.view.pageScrolling) {
          stepper.wheelRest = 0
          wheel.accepted = false
          return
        }
        if (stepper.wheelRest * dy < 0) stepper.wheelRest = 0
        stepper.wheelRest += dy
        var steps = Math.trunc(stepper.wheelRest / 120)
        if (steps !== 0) {
          stepper.wheelRest -= steps * 120
          stepper.nudge(steps)
        }
      }
    }
    TextInput {
      id: input
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: suffixText.left
      anchors.rightMargin: 3
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: TextInput.AlignRight
      clip: true
      // Digits only, any size: Enter clamps a number past `to` rather than
      // ignoring it.
      validator: RegularExpressionValidator { regularExpression: /[0-9]*/ }
      maximumLength: 4
      inputMethodHints: Qt.ImhDigitsOnly
      color: stepper.view.text
      selectionColor: stepper.view.accent
      selectedTextColor: stepper.view.accentInk
      font.family: stepper.view.host.theme.textFontFamily
      font.pixelSize: stepper.view.detailFontSize
      font.features: { "tnum": 1 }
      onAccepted: { stepper.pick(stepper.current()); stepper.view.forceActiveFocus() }
      onActiveFocusChanged: if (!activeFocus) stepper.pick(text === "" ? stepper.value : Number(text))
      Keys.onUpPressed: stepper.nudge(1)
      Keys.onDownPressed: stepper.nudge(-1)
      Keys.onEscapePressed: function(event) {
        text = String(stepper.value)
        stepper.view.forceActiveFocus()
        event.accepted = true
      }
    }
    Text {
      id: suffixText
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      visible: stepper.suffix !== ""
      text: stepper.suffix
      color: stepper.view.textMuted
      font: input.font
    }
  }

  // The arrows, one above the other in a well, as the field's.
  Rectangle {
    id: arrows
    anchors.right: parent.right
    width: 18
    height: parent.height
    radius: 7
    color: stepper.view.insetFill
    border.width: 1
    border.color: stepper.view.ink(0.12)

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 6
      height: 1
      color: stepper.view.ink(0.12)
    }

    component Arrow: MouseArea {
      id: arrow
      required property int dir
      readonly property bool atEnd: dir > 0 ? stepper.value >= stepper.to : stepper.value <= stepper.from
      width: arrows.width
      height: arrows.height / 2
      hoverEnabled: true
      enabled: !atEnd
      // It can reach its end while held: stop there, whether or not taking
      // `enabled` away mid-press cancels it.
      onAtEndChanged: if (atEnd) repeat.stop()
      // Held down, it keeps stepping after a beat, as a key repeats.
      onPressed: { stepper.nudge(arrow.dir); repeat.interval = 400; repeat.start() }
      onReleased: repeat.stop()
      onCanceled: repeat.stop()
      Timer {
        id: repeat
        repeat: true
        onTriggered: { interval = 60; stepper.nudge(arrow.dir) }
      }
      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 4
        color: stepper.view.host.theme.fill(arrow.pressed ? "strong" : "subtle")
        opacity: arrow.containsMouse || arrow.pressed ? 1 : 0
      }
      Chevron {
        anchors.centerIn: parent
        theme: stepper.view.host.theme
        pixelSize: 11
        angle: arrow.dir > 0 ? -90 : 90
        color: arrow.atEnd ? stepper.view.textMuted : stepper.view.text
        opacity: arrow.atEnd ? 0.5 : 1
      }
    }
    Arrow { dir: 1; anchors.top: parent.top }
    Arrow { dir: -1; anchors.bottom: parent.bottom }
  }
}
