import QtQuick
import Quickshell

// What's playing, from Omarchy's media service: the active player, its cover
// art, and a tint picked from the cover for the media pill and player view.
Item {
  id: nowPlaying
  required property var shell
  required property var theme

  readonly property var service: shell ? shell.firstPartyServiceFor("omarchy.media") : null
  // Only the players named in Settings (matched against the player's name
  // or desktop entry); none named means every player, as Omarchy picks it.
  readonly property var allowedApps: String(theme.settings.mediaApps || "").toLowerCase()
    .split(/[\s,]+/).filter(function(a) { return a !== "" })
  function allows(p) {
    if (!p) return false
    var name = (String(p.identity || "") + " " + String(p.desktopEntry || "")).toLowerCase()
    return allowedApps.some(function(a) { return name.indexOf(a) >= 0 })
  }
  readonly property var player: {
    if (!service) return null
    var active = service.activePlayer
    if (allowedApps.length === 0 || allows(active)) return active
    var mine = (service.players || []).filter(function(p) { return allows(p) && !service.isProxyPlayer(p) })
    return mine.find(function(p) { return p.isPlaying }) || mine.find(function(p) { return p.trackTitle }) || null
  }
  readonly property bool playing: !!(player && player.isPlaying)
  readonly property string title: player ? String(player.trackTitle || "") : ""
  readonly property string artist: player ? String(player.trackArtist || "") : ""
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
