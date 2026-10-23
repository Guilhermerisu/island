import QtQuick
import Quickshell.Widgets

// Dynamic Island–style "now playing" on the resting pill: the album art in a
// rounded square on the left and a sound wave on the right, tinted with the
// art's own color (the theme accent when there's no art). The clock stays in
// the middle. Clicking either side opens the player.
IslandPill {
  id: media
  shown: host.mediaPill
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
    ArtFallback {
      anchors.fill: parent
      host: media.host
      visible: artImage.status !== Image.Ready
    }
    Image {
      id: artImage
      anchors.fill: parent
      source: media.host.nowPlaying.art
      sourceSize.width: 60
      sourceSize.height: 60
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      // Browsers rewrite and delete their cover files as tracks change; never
      // hold on to a cached copy of one.
      cache: false
      visible: status === Image.Ready
    }
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
