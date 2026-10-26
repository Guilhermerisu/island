import QtQuick
import Quickshell.Widgets

// Dynamic Island secondary satellite pill:
// When the island is hover-expanded and the user has not configured "Now Playing"
// into one of the big pill's slots, this compact pill slides out smoothly right below
// the island during media playback.
// Clicking it immediately opens the full PlayerView ("media ayarlama pilli").
Rectangle {
  id: satellite
  required property var host
  required property Item shape
  property bool hasMediaInGlance: false

  readonly property var nowPlaying: host.nowPlaying
  readonly property var player: nowPlaying ? nowPlaying.player : null
  readonly property bool isPlaying: !!(nowPlaying && nowPlaying.playing)
  readonly property string track: nowPlaying && nowPlaying.title ? nowPlaying.title : ""
  readonly property string artist: nowPlaying && nowPlaying.artist ? nowPlaying.artist : (player && player.trackArtist ? String(player.trackArtist) : "")
  readonly property string artUrl: nowPlaying && nowPlaying.art ? nowPlaying.art : ""

  readonly property bool shown: shape && shape.isGlanceExpanded && !hasMediaInGlance && isPlaying && host.view === "rest" && (host.settings.glanceMediaSatellite !== false)
  readonly property bool isHovered: mouseArea.containsMouse

  x: shape ? shape.x + (shape.width - width) / 2 : 0
  readonly property real targetY: shape ? shape.y + shape.height + (host.settings.notch ? 8 : 6) : 0
  y: ySpring.value
  MotionSpring {
    id: ySpring
    theme: satellite.host.theme
    pace: "quick"
    target: satellite.shown ? satellite.targetY : (shape ? shape.y + shape.height - 10 : 0)
  }

  implicitWidth: Math.max(160, Math.min(260, contentRow.implicitWidth + 24))
  implicitHeight: 30
  width: implicitWidth
  height: implicitHeight
  radius: height / 2

  color: host.theme.background
  readonly property bool hasBorder: host.settings.glanceMediaSatelliteBorder !== false
  border.width: hasBorder ? 1 : 0
  border.color: hasBorder
    ? (mouseArea.containsMouse ? (nowPlaying.tint || host.theme.accent) : Qt.rgba(1, 1, 1, 0.16))
    : "transparent"
  Behavior on border.color {
    ColorAnimation { duration: 150 }
  }

  scale: mouseArea.pressed ? 0.96 : mouseArea.containsMouse ? 1.02 : 1.0
  Behavior on scale {
    MotionAnimation { theme: satellite.host.theme; pace: "quick" }
  }

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity {
    MotionAnimation { theme: satellite.host.theme; pace: satellite.shown ? "standard" : "exit"; curve: "fade" }
  }

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: 7

    // Mini album artwork
    ClippingRectangle {
      id: miniCoverClip
      width: 18
      height: 18
      radius: 5
      color: "transparent"
      anchors.verticalCenter: parent.verticalCenter
      visible: miniCover.status === Image.Ready

      Image {
        id: miniCover
        anchors.fill: parent
        source: satellite.artUrl
        sourceSize.width: 36
        sourceSize.height: 36
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }
    }

    Text {
      visible: !miniCoverClip.visible
      text: "󰝚"
      color: satellite.nowPlaying && satellite.nowPlaying.tint ? satellite.nowPlaying.tint : satellite.host.theme.accent
      font.family: satellite.host.theme.fontFamily
      font.pixelSize: satellite.host.theme.px(13)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: satellite.track !== "" ? (satellite.artist ? satellite.track + " · " + satellite.artist : satellite.track) : "Now Playing"
      color: Qt.rgba(0.92, 0.94, 0.90, 0.95)
      font.family: satellite.host.theme.textFontFamily
      font.pixelSize: satellite.host.theme.px(11)
      font.weight: Font.Medium
      elide: Text.ElideRight
      width: Math.min(implicitWidth, 140)
      anchors.verticalCenter: parent.verticalCenter
    }

    SoundWave {
      anchors.verticalCenter: parent.verticalCenter
      color: satellite.nowPlaying && satellite.nowPlaying.tint ? satellite.nowPlaying.tint : satellite.host.theme.accent
      playing: satellite.shown
      bars: 3
      barWidth: 2
      maxHeight: 12
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      mouse.accepted = true
      satellite.host.view = "player"
    }
  }
}
