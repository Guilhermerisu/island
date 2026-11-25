import QtQuick
import "../../../components"

// Segmented control, as macOS's: every choice side by side in a track
// (#2c2c2e, 2 in), the current one on a lighter chip (#636366) that glides
// between them, its label semibold white; the rest secondary. Chips share one
// width, and the control is at least the view's controlWidth so it lines up
// with the pop-ups. For a handful of short choices; longer lists keep
// SettingsPopUp.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: seg
  required property var view
  property var options: []   // [{ label, value }]
  property var value
  // The narrowest it gets; the rows of an addon's options line their
  // controls up wider than the General pane's.
  property real minWidth: view.controlWidth
  signal picked(var value)
  // The choice matching the value; for numbers, the nearest one, so a value
  // set by hand in island.json (1.2) still shows a choice picked.
  readonly property int currentIndex: {
    for (var i = 0; i < options.length; i++) if (options[i].value === value) return i
    if (typeof value !== "number" || isNaN(value)) return -1
    var nearest = -1
    for (var j = 0; j < options.length; j++) {
      if (typeof options[j].value !== "number") return -1
      if (nearest < 0 || Math.abs(options[j].value - value) < Math.abs(options[nearest].value - value)) nearest = j
    }
    return nearest
  }
  FontMetrics {
    id: segFont
    font.family: seg.view.host.theme.textFontFamily
    font.pixelSize: seg.view.calloutFontSize
    font.weight: Font.DemiBold
  }
  readonly property real chipWidth: {
    var widest = 0
    for (var i = 0; i < options.length; i++) widest = Math.max(widest, segFont.advanceWidth(options[i].label))
    return Math.max(30, Math.ceil(widest) + 20, options.length ? (seg.minWidth - 4) / options.length : 0)
  }
  implicitWidth: choices.implicitWidth + 4
  implicitHeight: 26
  radius: 7
  color: seg.view.controlFill
  // The chip: clearly lighter, with a faint shadow a pixel under it, as
  // macOS's selected segment, so the choice doesn't rest on the bold label.
  // Placed by index, since every chip is chipWidth wide: looking the item
  // up with itemAt() found none while the Repeater was still building, so
  // a control opened with its value set showed no chip at all.
  Item {
    id: chip
    visible: seg.currentIndex >= 0
    x: 2 + Math.max(0, seg.currentIndex) * seg.chipWidth
    y: 2
    width: seg.chipWidth
    height: seg.height - 4
    Behavior on x { MotionAnimation { theme: seg.view.host.theme; pace: "quick" } }
    Behavior on width { MotionAnimation { theme: seg.view.host.theme; pace: "quick" } }
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 1
      anchors.bottomMargin: -1
      radius: 5
      color: Qt.rgba(0, 0, 0, 0.35)
    }
    Rectangle {
      anchors.fill: parent
      radius: 5
      color: seg.view.segmentChip
    }
  }
  Row {
    id: choices
    x: 2
    anchors.verticalCenter: parent.verticalCenter
    Repeater {
      model: seg.options
      delegate: Item {
        id: choice
        required property var modelData
        required property int index
        readonly property bool selected: index === seg.currentIndex
        implicitWidth: seg.chipWidth
        implicitHeight: seg.height - 4
        Text {
          id: choiceText
          anchors.centerIn: parent
          text: choice.modelData.label
          textFormat: Text.PlainText
          color: choice.selected ? (seg.view.dark ? "#ffffff" : seg.view.text) : seg.view.textMuted
          Behavior on color { MotionColorAnimation { theme: seg.view.host.theme } }
          font.family: seg.view.host.theme.textFontFamily
          font.letterSpacing: seg.view.host.theme.tracking(seg.view.host.theme.textFontFamily, seg.view.calloutFontSize)
          font.pixelSize: seg.view.calloutFontSize
          font.weight: choice.selected ? Font.DemiBold : Font.Normal
        }
        scale: choiceMouse.pressed ? 0.96 : 1
        Behavior on scale { id: scaleMotion; MotionAnimation { theme: seg.view.host.theme; pace: towards(scaleMotion.targetValue, choiceMouse.pressed ? "press" : "standard") } }
        MouseArea {
          id: choiceMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: if (!choice.selected) seg.picked(choice.modelData.value)
        }
      }
    }
  }
}
