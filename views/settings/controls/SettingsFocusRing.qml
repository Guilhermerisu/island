import QtQuick
import "../../../components"

// An inset field's focus ring: settles in from slightly larger, like macOS's.
// A child of the field, which it rings.
Rectangle {
  required property var view
  property bool shown: false
  anchors.centerIn: parent
  width: parent.width + 6
  height: parent.height + 6
  radius: parent.radius + 3
  color: "transparent"
  border.width: 3
  border.color: view.host.theme.accentFill("ring")
  opacity: shown ? 1 : 0
  scale: shown ? 1 : 1.12
  Behavior on opacity { MotionAnimation { theme: view.host.theme; pace: "fade"; curve: "fade" } }
  Behavior on scale { MotionAnimation { theme: view.host.theme; pace: "standard" } }
}
