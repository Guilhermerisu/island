import QtQuick
import QtQuick.Effects
import "../../../components"
import QtQuick.Layouts

// The switch, iOS-sized (42 × 26, a 22 knob with a soft shadow): accent
// when on, a dark grey (#3a3a3a on the black island) when off.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: sw
  required property var view
  property bool checked: false
  signal toggled(bool checked)
  implicitWidth: 42
  implicitHeight: 26
  radius: 13
  // Off is a clearly lighter grey than the card, so an off switch still
  // reads as a switch rather than a lone knob.
  color: checked ? sw.view.accent : Qt.tint(sw.view.host.theme.background, sw.view.host.theme.withAlpha(sw.view.host.theme.text, 0.25))
  Behavior on color { MotionColorAnimation { theme: sw.view.host.theme } }
  // The knob widens while held, as Apple's switches do; anchored by its
  // side, it stretches toward the side it will go to.
  Rectangle {
    width: switchMouse.pressed ? 27 : 22
    Behavior on width { id: widthMotion; MotionAnimation { theme: sw.view.host.theme; pace: towards(widthMotion.targetValue, switchMouse.pressed ? "press" : "standard") } }
    height: 22; radius: 11
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
      shadowColor: Qt.rgba(0, 0, 0, 0.3)
      shadowBlur: 0.4
      shadowVerticalOffset: 1
    }
  }
  MouseArea {
    id: switchMouse
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled(!sw.checked)
  }
}
