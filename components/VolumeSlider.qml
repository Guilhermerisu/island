import QtQuick

// Compact macOS-style volume HUD: speaker, thin green bar, and percentage.
Item {
  id: slider
  required property var host
  opacity: host.volumePill ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: host.theme; pace: "fade"; curve: "fade" } }

  VolumeLevel {
    anchors.fill: parent
    theme: slider.host.theme
    level: slider.host.volume
    muted: slider.host.muted
  }
}
