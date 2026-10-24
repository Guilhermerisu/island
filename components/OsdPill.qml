import QtQuick

// The island's take on Omarchy's on-screen display: an icon with either a
// progress bar and its reading, or a message. Fed by `host.showOsd` — the
// `osd` IPC target and the backlight watch in OsdBridge — so the stock OSD
// plugin can stay off and nothing pops up twice.
IslandPill {
  id: osd
  shown: host.osdPill
  pillWidth: host.osdProgress ? 240 : host.osdMessage.length > 26 ? 340 : 280
  function clicked(mouse) { host.dismissFeedback() }

  readonly property real level: host.osdMaxValue > 0
    ? Math.max(0, Math.min(1, host.osdValue / host.osdMaxValue)) : 0
  // Glides between steps, as the volume bar's.
  property real shownLevel: level
  Behavior on shownLevel { MotionAnimation { theme: osd.host.theme; pace: "standard" } }

  // The icon, then the bar or message, then the reading come in from a blur
  // in turn, as the other pills.
  PillReveal { id: reveal; theme: osd.host.theme; shown: osd.shown }

  Text {
    id: glyph
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    width: 24
    horizontalAlignment: Text.AlignHCenter
    text: osd.host.osdIcon
    color: "#ffffff"
    font.family: osd.host.theme.fontFamily
    font.pixelSize: osd.host.theme.px(21)
    opacity: reveal.leadingIn
    PillPart { progress: reveal.leadingIn }
  }

  Rectangle {
    id: track
    visible: osd.host.osdProgress
    anchors.left: glyph.right
    anchors.leftMargin: 12
    anchors.right: reading.left
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    height: 5
    radius: height / 2
    color: Qt.tint("#2a2a2a", osd.host.theme.accentFill("soft"))
    opacity: reveal.middleIn
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
    Rectangle {
      width: parent.width * osd.shownLevel
      height: parent.height
      radius: height / 2
      color: osd.host.theme.accent
    }
  }

  Text {
    id: reading
    visible: osd.host.osdProgress
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(36, implicitWidth)
    horizontalAlignment: Text.AlignRight
    text: osd.host.osdMessage
    color: "#ffffff"
    font.family: osd.host.theme.textFontFamily
    font.letterSpacing: osd.host.theme.tracking(osd.host.theme.textFontFamily, osd.host.theme.px(12))
    font.pixelSize: osd.host.theme.px(12)
    font.weight: Font.DemiBold
    font.features: { "tnum": 1 }
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
  }

  Text {
    visible: !osd.host.osdProgress
    anchors.left: glyph.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: osd.host.osdMessage
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: "#ffffff"
    font.family: osd.host.theme.textFontFamily
    font.letterSpacing: osd.host.theme.tracking(osd.host.theme.textFontFamily, osd.host.theme.px(13))
    font.features: { "tnum": 1 }
    font.pixelSize: osd.host.theme.px(13)
    font.weight: Font.Medium
    opacity: reveal.middleIn
    transformOrigin: Item.Left
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
  }
}
