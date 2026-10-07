import QtQuick

// The island's take on Omarchy's on-screen display: an icon with either a
// progress bar and its reading, or a message. Fed by `host.showOsd` — the
// `osd` IPC target and the backlight watch in OsdBridge — so the stock OSD
// plugin can stay off and nothing pops up twice.
Item {
  id: osd
  required property var host
  opacity: host.osdPill ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: host.theme; pace: "fade"; curve: "fade" } }

  readonly property real level: host.osdMaxValue > 0
    ? Math.max(0, Math.min(1, host.osdValue / host.osdMaxValue)) : 0

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
    font.pixelSize: 21
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
    color: Qt.tint("#2a2a2a", osd.host.theme.withAlpha(osd.host.theme.accent, 0.16))
    Rectangle {
      width: parent.width * osd.level
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
    font.pixelSize: 12
    font.weight: Font.DemiBold
    font.features: { "tnum": 1 }
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
    font.pixelSize: 14
    font.weight: Font.Medium
  }
}
