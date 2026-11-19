import QtQuick
import Quickshell.Widgets

// Dynamic Island–style "now playing" on the resting pill: the album art in a
// rounded square on the left and a sound wave on the right, tinted with the
// art's own color (the theme accent when there's no art). The clock stays in
// the middle. Clicking either side opens the player.
IslandPill {
  id: media
  property Item shape: null
  shown: host.mediaPill && (!shape || !shape.isGlanceExpanded)
  pillWidth: 240
  keepsClock: true
  function clicked(mouse) { host.view = mouse.x < 56 || mouse.x > width - 72 ? "player" : "controls" }

  PillReveal { id: reveal; theme: media.host.theme; shown: media.shown }

  ClippingRectangle {
    id: art
    opacity: reveal.leadingIn
    PillPart { target: art; progress: reveal.leadingIn }
    anchors.left: parent.left
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    width: 30; height: 30; radius: 8
    color: "transparent"
    CoverArt { anchors.fill: parent; host: media.host; imageSize: 60 }
  }

  SoundWave {
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    color: media.host.nowPlaying.tint
    playing: media.shown
  }
}
