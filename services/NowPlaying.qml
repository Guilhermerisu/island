import QtQuick
import Quickshell

// What's playing, from Omarchy's media service: the active player, its cover
// art, and a tint picked from the cover for the media pill and player view.
Item {
  id: nowPlaying
  required property var shell
  required property var theme

  readonly property var service: shell ? shell.firstPartyServiceFor("omarchy.media") : null
  readonly property var player: service ? service.activePlayer : null
  readonly property bool playing: !!(player && player.isPlaying)
  readonly property string title: player ? String(player.trackTitle || "") : ""
  // If the art URL goes empty while the title stays the same, the last art
  // keeps showing.
  readonly property string reportedArt: player && player.trackArtUrl ? String(player.trackArtUrl) : ""
  property string keptArt: ""
  property string keptArtTitle: ""
  onReportedArtChanged: if (reportedArt) { keptArt = reportedArt; keptArtTitle = title }
  onTitleChanged: if (title !== keptArtTitle) { keptArt = reportedArt; keptArtTitle = title }
  readonly property string art: reportedArt || (title === keptArtTitle ? keptArt : "")

  ColorQuantizer {
    id: coverColors
    source: nowPlaying.art
    depth: 2
    rescaleSize: 64
  }
  // The cover's most vivid colour, or the theme's accent for a grey cover.
  readonly property color tint: {
    var best = null, bestScore = -1
    var colors = coverColors.colors || []
    for (var i = 0; i < colors.length; i++) {
      var c = colors[i]
      var score = c.hsvSaturation * 0.7 + c.hsvValue * 0.3
      if (score > bestScore) { bestScore = score; best = c }
    }
    if (!best || best.hsvSaturation < 0.12) return theme.accent
    return Qt.hsva(best.hsvHue, Math.min(1, best.hsvSaturation), Math.max(0.75, best.hsvValue), 1)
  }
}
