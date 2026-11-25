import QtQuick
import "../../../components"
import QtQuick.Layouts

// Pop-up button, as macOS's: the current choice in a bordered box with
// up/down chevrons; the choices open in a menu (see popMenu in
// SettingsView).
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
  property real minWidth: view.controlWidth
  signal picked(var value)
  readonly property string currentLabel: {
    if (multiSelect) return options.filter(function(o) { return pop.isSelected(o.value) })
      .map(function(o) { return o.short || o.label }).join(" + ")
    for (var i = 0; i < options.length; i++) if (options[i].value === value) return options[i].short || options[i].label
    return ""
  }
  readonly property bool open: pop.view.menuButton === pop
  implicitWidth: Math.max(pop.minWidth, popLabel.implicitWidth + 44)
  implicitHeight: 28
  radius: 8
  color: pop.view.host.theme.fill(open || popMouse.containsMouse ? "subtle" : "quiet")
  border.width: 1
  border.color: pop.view.host.theme.fill(open ? "stronger" : "raised")
  Behavior on color { MotionColorAnimation { theme: pop.view.host.theme } }
  scale: popMouse.pressed ? 0.98 : 1
  Behavior on scale { id: scaleMotion; MotionAnimation { theme: pop.view.host.theme; pace: towards(scaleMotion.targetValue, popMouse.pressed ? "press" : "standard") } }
  Text {
    id: popLabel
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: pop.currentLabel
    textFormat: Text.PlainText
    color: pop.view.text
    font.family: pop.view.host.theme.textFontFamily
    font.letterSpacing: pop.view.host.theme.tracking(pop.view.host.theme.textFontFamily, pop.view.detailFontSize)
    font.pixelSize: pop.view.detailFontSize
  }
  Column {
    anchors.right: parent.right
    anchors.rightMargin: 10
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
