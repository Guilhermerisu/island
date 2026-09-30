import QtQuick
import Quickshell.Widgets

// Dynamic Island–style "now playing" on the resting pill: the album art in a
// rounded square on the left and a sound wave on the right, tinted with the
// art's own color (the theme accent when there's no art). The clock stays in
// the middle.
Item {
  id: media
  required property var host
  readonly property bool shown: host.mediaPill

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: media.host.theme; pace: "fade"; curve: "fade" } }

  ClippingRectangle {
    id: art
    anchors.left: parent.left
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    width: 30; height: 30; radius: 8
    color: media.host.theme.withAlpha(media.host.theme.accent, 0.3)
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
    Text {
      anchors.centerIn: parent
      visible: artImage.status !== Image.Ready
      text: "󰝚"
      color: media.host.theme.accentText
      font.family: media.host.theme.fontFamily
      font.pixelSize: 14
    }
  }

  SoundWave {
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    color: media.host.nowPlaying.tint
    playing: media.shown
  }
}
