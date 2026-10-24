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
  implicitWidth: 32
  implicitHeight: 18
  radius: 9
  color: checked ? sw.view.accent : sw.view.well
  Behavior on color { MotionColorAnimation { theme: sw.view.host.theme } }
  // The knob widens while held, as Apple's switches do; anchored by its
  // side, it stretches toward the side it will go to.
  Rectangle {
    width: switchMouse.pressed ? 20 : 16
    Behavior on width { MotionAnimation { theme: sw.view.host.theme; pace: switchMouse.pressed ? "press" : "standard" } }
    height: 16; radius: 8
    y: 1
    // How far across the knob is (0 off, 1 on). Animating this rather than
    // x keeps the knob inside the track while its width changes.
    property real travel: sw.checked ? 1 : 0
    Behavior on travel { MotionAnimation { theme: sw.view.host.theme; pace: "standard" } }
    x: 1 + travel * (sw.width - width - 2)
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
