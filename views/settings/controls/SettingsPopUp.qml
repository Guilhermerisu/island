import QtQuick
import "../../../components"
import QtQuick.Layouts

// Pop-up button, as macOS's list pop-ups: at rest just the current choice
// in the secondary grey with up/down chevrons, no box; the box shows only
// on hover or while the menu is open. The choices open in a menu (see
// popMenu in SettingsView).
// `view` is the SettingsView, for its colours.
Rectangle {
  id: pop
  required property var view
  // [{ label, value, short }]: the menu lists each label; the button shows
  // the current choice's short label when it has one.
  property var options: []
  property var value
  property bool multiSelect: false
  readonly property var selectedValues: typeof value === "string" ? [value] : Array.from(value || [])
  function isSelected(candidate) {
    return multiSelect ? selectedValues.indexOf(candidate) >= 0 : value === candidate
  }
  function pick(candidate, additive) {
    if (!multiSelect) { picked(candidate); return }
    var next = selectedValues.slice()
    var index = next.indexOf(candidate)
    if (!additive) next = [candidate]
    else if (index < 0) next.push(candidate)
    else if (next.length > 1) next.splice(index, 1)
    picked(next)
  }
  // Hugs its choice unless a row asks for more (an addon's options line
  // their controls up).
  property real minWidth: 0
  signal picked(var value)
  readonly property string currentLabel: {
    if (multiSelect) return options.filter(function(o) { return pop.isSelected(o.value) })
      .map(function(o) { return o.short || o.label }).join(" + ")
    for (var i = 0; i < options.length; i++) if (options[i].value === value) return options[i].short || options[i].label
    return ""
  }
  readonly property bool open: pop.view.menuButton === pop
  readonly property bool boxed: open || popMouse.containsMouse
  implicitWidth: Math.max(pop.minWidth, popLabel.implicitWidth + 8 + 4 + chevrons.width + 8)
  implicitHeight: 28
  radius: 8
  color: boxed ? pop.view.host.theme.fill("subtle") : pop.view.host.theme.withAlpha(pop.view.host.theme.fill("subtle"), 0)
  border.width: 1
  border.color: boxed ? pop.view.host.theme.fill(open ? "stronger" : "raised") : "transparent"
  Behavior on color { MotionColorAnimation { theme: pop.view.host.theme } }
  scale: popMouse.pressed ? 0.98 : 1
  Behavior on scale { id: scaleMotion; MotionAnimation { theme: pop.view.host.theme; pace: towards(scaleMotion.targetValue, popMouse.pressed ? "press" : "standard") } }
  Text {
    id: popLabel
    anchors.right: chevrons.left
    anchors.rightMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    text: pop.currentLabel
    textFormat: Text.PlainText
    color: pop.boxed ? pop.view.text : pop.view.textMuted
    Behavior on color { MotionColorAnimation { theme: pop.view.host.theme } }
    font.family: pop.view.host.theme.textFontFamily
    font.letterSpacing: pop.view.host.theme.tracking(pop.view.host.theme.textFontFamily, pop.view.detailFontSize)
    font.pixelSize: pop.view.detailFontSize
  }
  Column {
    id: chevrons
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: -5
    Repeater {
      model: ["󰅃", "󰅀"]
      delegate: Text {
        required property string modelData
        text: modelData
        color: pop.view.textMuted
        font.family: pop.view.host.theme.fontFamily
        font.pixelSize: pop.view.host.theme.px(10)
      }
    }
  }
  MouseArea {
    id: popMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pop.open ? pop.view.menuButton = null : pop.view.openMenu(pop)
  }
}
