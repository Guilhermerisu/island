import QtQuick
import "../../../components"

// Segmented control, as macOS's: every choice side by side in a well, the
// current one on a raised chip that glides between them. Chips share one
// width, and the control is at least the view's controlWidth so it lines up
// with the pop-ups. For a handful of short choices; longer lists keep
// SettingsPopUp.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: seg
  required property var view
  property var options: []   // [{ label, value }]
  property var value
  signal picked(var value)
  readonly property int currentIndex: {
    for (var i = 0; i < options.length; i++) if (options[i].value === value) return i
    return -1
  }
  FontMetrics {
    id: segFont
    font.family: seg.view.host.theme.textFontFamily
    font.pixelSize: seg.view.detailFontSize
    font.weight: Font.DemiBold
  }
  readonly property real chipWidth: {
    var widest = 0
    for (var i = 0; i < options.length; i++) widest = Math.max(widest, segFont.advanceWidth(options[i].label))
    return Math.max(30, Math.ceil(widest) + 22, options.length ? (seg.view.controlWidth - 4) / options.length : 0)
  }
  implicitWidth: choices.implicitWidth + 4
  implicitHeight: 28
  radius: 8
  color: seg.view.host.theme.fill("subtle")
  Rectangle {
    readonly property Item at: segItems.itemAt(seg.currentIndex)
    visible: !!at
    x: 2 + (at ? at.x : 0)
    y: 2
    width: at ? at.width : 0
    height: seg.height - 4
    radius: 6
    color: seg.view.host.theme.fill("stronger")
    Behavior on x { MotionAnimation { theme: seg.view.host.theme; pace: "quick" } }
    Behavior on width { MotionAnimation { theme: seg.view.host.theme; pace: "quick" } }
  }
  Row {
    id: choices
    x: 2
    anchors.verticalCenter: parent.verticalCenter
    Repeater {
      id: segItems
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
          color: choice.selected ? seg.view.text : seg.view.textMuted
          Behavior on color { MotionColorAnimation { theme: seg.view.host.theme } }
          font.family: seg.view.host.theme.textFontFamily
          font.letterSpacing: seg.view.host.theme.tracking(seg.view.host.theme.textFontFamily, seg.view.detailFontSize)
          font.pixelSize: seg.view.detailFontSize
          font.weight: choice.selected ? Font.DemiBold : Font.Normal
        }
        scale: choiceMouse.pressed ? 0.96 : 1
        Behavior on scale { MotionAnimation { theme: seg.view.host.theme; pace: choiceMouse.pressed ? "press" : "standard" } }
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
