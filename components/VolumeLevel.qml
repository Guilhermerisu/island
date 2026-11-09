import QtQuick

// Shared by the live HUD and its static settings preview.
Item {
  id: volume
  required property var theme
  property real level: 0
  property bool muted: false
  // Overrides the speaker glyph (the brightness preview uses the display one).
  property string icon: ""
  property bool animateLevel: true
  readonly property real effectiveLevel: muted ? 0 : Math.max(0, Math.min(1, level))
  property real shownLevel: effectiveLevel
  Behavior on shownLevel {
    enabled: volume.animateLevel
    MotionAnimation { theme: volume.theme; pace: "standard" }
  }

  Text {
    id: speaker
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    width: 24
    horizontalAlignment: Text.AlignHCenter
    text: volume.icon !== "" ? volume.icon
      : volume.effectiveLevel <= 0 ? "󰖁" : volume.effectiveLevel < 0.34 ? "󰕿" : volume.effectiveLevel < 0.67 ? "󰖀" : "󰕾"
    color: volume.theme.text
    font.family: volume.theme.fontFamily
    font.pixelSize: volume.theme.px(21)
  }

  Rectangle {
    id: track
    anchors.left: speaker.right
    anchors.leftMargin: 12
    anchors.right: percentage.left
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    height: 5
    radius: height / 2
    color: Qt.tint("#2a2a2a", volume.theme.accentFill("soft"))
    Rectangle {
      width: parent.width * volume.shownLevel
      height: parent.height
      radius: height / 2
      color: volume.theme.accent
    }
  }

  RollingText {
    theme: volume.theme
    id: percentage
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    width: 36
    text: Math.round(volume.effectiveLevel * 100) + "%"
    color: volume.theme.text
    font.family: volume.theme.textFontFamily
    font.letterSpacing: volume.theme.tracking(volume.theme.textFontFamily, volume.theme.size.callout)
    font.pixelSize: volume.theme.size.callout
    font.weight: Font.DemiBold
    font.features: { "tnum": 1 }
  }
}
