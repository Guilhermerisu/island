import QtQuick

// Compact macOS-style volume HUD: speaker, thin green bar, and percentage.
IslandPill {
  id: slider
  shown: host.volumePill
  pillWidth: 240

  VolumeLevel {
    anchors.fill: parent
    theme: slider.host.theme
    level: slider.host.volume
    muted: slider.host.muted
  }
}
