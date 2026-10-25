import QtQuick
import QtQuick.Effects
import "../../../components"
import QtQuick.Layouts

// The small switch System Settings uses in its lists.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: sw
  required property var view
  property bool checked: false
  signal toggled(bool checked)
  implicitWidth: 38
  implicitHeight: 22
  radius: 11
  // Off is a clearly lighter grey than the card, so an off switch still
  // reads as a switch rather than a lone knob.
  color: checked ? sw.view.accent : sw.view.host.theme.solid("stronger")
  Behavior on color { MotionColorAnimation { theme: sw.view.host.theme } }
  // The knob widens while held, as Apple's switches do; anchored by its
  // side, it stretches toward the side it will go to.
  Rectangle {
    width: switchMouse.pressed ? 23 : 18
    Behavior on width { MotionAnimation { theme: sw.view.host.theme; pace: switchMouse.pressed ? "press" : "standard" } }
    height: 18; radius: 9
    y: 2
    // How far across the knob is (0 off, 1 on). Animating this rather than
    // x keeps the knob inside the track while its width changes.
    property real travel: sw.checked ? 1 : 0
    Behavior on travel { MotionAnimation { theme: sw.view.host.theme; pace: "standard" } }
    x: 2 + travel * (sw.width - width - 4)
    color: "#ffffff"
    layer.enabled: visible
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.4)
      shadowBlur: 0.25
      shadowVerticalOffset: 0.5
    }
  }
  MouseArea {
    id: switchMouse
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled(!sw.checked)
  }
}
