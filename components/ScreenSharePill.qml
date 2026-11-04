import QtQuick

// Screen sharing live activity: while an app shares the screen or a window
// (Hyprland reports each portal screencast), a screen glyph left of the
// clock and how long it's been shared on the right, as the recording pill.
IslandPill {
  id: pill
  readonly property color ink: host.settings.colorfulLiveActivities ? pill.host.theme.system.green : host.theme.accent
  shown: host.sharePill
  pillWidth: 240
  keepsClock: true
  function clicked(mouse) { host.view = "share" }

  PillReveal { id: reveal; theme: pill.host.theme; shown: pill.shown }

  Text {
    opacity: reveal.leadingIn
    PillPart { progress: reveal.leadingIn }
    anchors.left: parent.left
    anchors.leftMargin: 15
    anchors.verticalCenter: parent.verticalCenter
    text: pill.host.shareKind === "window" ? "󰖯" : "󰍹"
    color: pill.ink
    font.family: pill.host.theme.fontFamily
    font.pixelSize: pill.host.theme.px(16)
  }
  Text {
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: pill.host.recorder.timeText(Math.max(0, pill.host.clockDate.getTime() - pill.host.shareStartedAt))
    color: pill.ink
    font.family: pill.host.theme.textFontFamily
    font.pixelSize: pill.host.theme.px(13)
    font.weight: Font.Medium
    font.features: { "tnum": 1, "case": 1 }
  }
}
