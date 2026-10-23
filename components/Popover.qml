import QtQuick
import QtQuick.Effects

// A macOS-style pop-up panel over a view: raised, edged and shadowed,
// fading and growing in while `open` and only taking input then. Its owner
// places and sizes it; set transformOrigin to where it grows from.
Rectangle {
  id: popover
  required property var theme
  property bool open: false

  visible: opacity > 0.01
  enabled: open
  opacity: open ? 1 : 0
  scale: open ? 1 : 0.96
  Behavior on opacity { MotionAnimation { theme: popover.theme; pace: popover.open ? "fade" : "exit"; curve: "fade" } }
  Behavior on scale { MotionAnimation { theme: popover.theme; pace: popover.open ? "standard" : "exit" } }
  radius: 10
  color: theme.solid("raised")
  border.width: 1
  border.color: theme.fill("raised")
  layer.enabled: visible
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.5)
    shadowBlur: 0.8
    shadowVerticalOffset: 6
  }
}
