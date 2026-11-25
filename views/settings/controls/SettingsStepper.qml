import QtQuick
import "../../../components"

// Number field with up and down arrows beside it, as macOS's stepper. Type a
// number (Enter or leaving the field commits it), click or hold an arrow, press
// ↑/↓ in the field or scroll over it. `picked` fires with the new value,
// always whole and within from–to.
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
  implicitHeight: 28

  function clamp(v) { return Math.max(stepper.from, Math.min(stepper.to, Math.round(v))) }
  function pick(v) {
    var next = clamp(v)
    input.text = String(next)
    if (next !== stepper.value) stepper.picked(next)
  }
  function nudge(dir) { pick((input.activeFocus ? Number(input.text) || stepper.value : stepper.value) + dir * stepper.step) }

  onValueChanged: if (!input.activeFocus) input.text = String(value)
  Component.onCompleted: input.text = String(value)

  Rectangle {
    id: field
    anchors.left: parent.left
    anchors.right: arrows.left
    anchors.rightMargin: 4
    height: parent.height
    radius: 6
    color: stepper.view.host.theme.solid(fieldMouse.containsMouse && !input.activeFocus ? "subtle" : "quiet")
    border.width: 1
    border.color: stepper.view.host.theme.fill(input.activeFocus ? "strong" : "raised")
    Behavior on color { MotionColorAnimation { theme: stepper.view.host.theme } }
    // Focus ring: settles in from slightly larger, like macOS's.
    Rectangle {
      anchors.centerIn: parent
      width: parent.width + 6
      height: parent.height + 6
      radius: parent.radius + 3
      color: "transparent"
      border.width: 3
      border.color: stepper.view.host.theme.accentFill("ring")
      opacity: input.activeFocus ? 1 : 0
      scale: input.activeFocus ? 1 : 1.12
      Behavior on opacity { MotionAnimation { theme: stepper.view.host.theme; pace: "fade"; curve: "fade" } }
      Behavior on scale { MotionAnimation { theme: stepper.view.host.theme; pace: "standard" } }
    }

    MouseArea {
      id: fieldMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.IBeamCursor
      onClicked: input.forceActiveFocus()
      onWheel: function(wheel) {
        if (wheel.angleDelta.y !== 0) stepper.nudge(wheel.angleDelta.y > 0 ? 1 : -1)
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
      validator: IntValidator { bottom: 0; top: stepper.to }
      inputMethodHints: Qt.ImhDigitsOnly
      color: stepper.view.text
      selectionColor: stepper.view.accent
      selectedTextColor: stepper.view.accentInk
      font.family: stepper.view.host.theme.textFontFamily
      font.pixelSize: stepper.view.detailFontSize
      font.features: { "tnum": 1 }
      onAccepted: { stepper.pick(Number(text) || stepper.from); stepper.view.forceActiveFocus() }
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
    radius: 6
    color: stepper.view.host.theme.solid("quiet")
    border.width: 1
    border.color: stepper.view.host.theme.fill("raised")

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 6
      height: 1
      color: stepper.view.host.theme.fill("raised")
    }

    component Arrow: MouseArea {
      id: arrow
      required property int dir
      readonly property bool atEnd: dir > 0 ? stepper.value >= stepper.to : stepper.value <= stepper.from
      width: arrows.width
      height: arrows.height / 2
      hoverEnabled: true
      enabled: !atEnd
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
