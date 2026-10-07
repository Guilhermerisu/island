import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../components"

// Now-playing view, opened from the media pill's cover or wave: cover, title
// and artist, the live sound wave, a seekable progress bar with elapsed and
// remaining time, and transport controls. Keys: Space play/pause, ←/→ seek
// 10 s, Esc close.
Item {
  id: player
  required property var host
  property bool active: false

  readonly property var mpris: host.nowPlaying.player
  readonly property bool playing: !!(mpris && mpris.isPlaying)
  readonly property real length: mpris && mpris.lengthSupported ? mpris.length : 0
  readonly property bool canSeek: !!(mpris && mpris.canSeek && length > 0)
  property real position: 0
  property bool dragging: false

  implicitHeight: layout.implicitHeight

  onActiveChanged: {
    if (!active) return
    position = mpris ? mpris.position : 0
    Qt.callLater(function() { player.forceActiveFocus() })
  }
  // Mpris only reports position on seeks; re-read it every frame while open
  // and playing so the bar and times glide.
  FrameAnimation {
    running: player.active && player.playing && !player.dragging
    onTriggered: player.position = player.mpris ? player.mpris.position : 0
  }
  Connections {
    target: player.mpris
    function onPositionChanged() { if (!player.dragging) player.position = player.mpris.position }
  }

  function action(name) { if (host.nowPlaying.service) host.nowPlaying.service.runAction(name, false, "") }
  function seekTo(seconds) {
    if (!canSeek) return
    var target = Math.max(0, Math.min(length, seconds))
    mpris.position = target
    position = target
  }
  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds || 0))
    var m = Math.floor(s / 60), r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Space) { action("playPause"); event.accepted = true }
    else if (event.key === Qt.Key_Left) { seekTo(position - 10); event.accepted = true }
    else if (event.key === Qt.Key_Right) { seekTo(position + 10); event.accepted = true }
    else if (event.key === Qt.Key_Escape) { host.view = "rest"; event.accepted = true }
  }

  ColumnLayout {
    id: layout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 0

    // ---------- Cover, title, wave ----------

    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      ClippingRectangle {
        Layout.preferredWidth: 72
        Layout.preferredHeight: 72
        radius: 16
        color: player.host.theme.withAlpha(player.host.theme.accent, 0.3)
        Image {
          id: cover
          anchors.fill: parent
          source: player.host.nowPlaying.art
          sourceSize.width: 144
          sourceSize.height: 144
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          visible: status === Image.Ready
        }
        Text {
          anchors.centerIn: parent
          visible: cover.status !== Image.Ready
          text: "󰝚"
          color: player.host.theme.accentText
          font.family: player.host.theme.fontFamily
          font.pixelSize: player.host.theme.px(30)
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
          Layout.fillWidth: true
          text: player.mpris ? String(player.mpris.trackTitle || "Unknown track") : "Nothing playing"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: "#ffffff"
          font.family: player.host.theme.textFontFamily
          font.pixelSize: player.host.theme.px(17)
          font.weight: Font.DemiBold
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: player.mpris ? String(player.mpris.trackArtist || player.mpris.identity || "") : ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Qt.rgba(1, 1, 1, 0.55)
          font.family: player.host.theme.textFontFamily
          font.pixelSize: player.host.theme.px(15)
        }
      }
      SoundWave {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 10
        color: player.host.nowPlaying.tint
        playing: player.active && player.playing
        barWidth: 3.5
        maxHeight: 24
      }
    }

    // ---------- Progress ----------

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 22
      spacing: 12
      visible: player.length > 0

      Text {
        text: player.clock(player.position)
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: player.host.theme.textFontFamily
        font.pixelSize: player.host.theme.px(12)
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
      }
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 18
        Rectangle {
          id: track
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 6
          radius: 3
          color: Qt.rgba(1, 1, 1, 0.16)
          Rectangle {
            height: parent.height
            radius: parent.radius
            width: player.length > 0 ? parent.width * Math.max(0, Math.min(1, player.position / player.length)) : 0
            color: Qt.rgba(1, 1, 1, 0.6)
          }
        }
        MouseArea {
          anchors.fill: parent
          enabled: player.canSeek
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          function at(x) { return Math.max(0, Math.min(1, x / width)) * player.length }
          onPressed: function(e) { player.dragging = true; player.position = at(e.x) }
          onPositionChanged: function(e) { if (pressed) player.position = at(e.x) }
          onReleased: function(e) { player.dragging = false; player.seekTo(at(e.x)) }
        }
      }
      Text {
        text: "−" + player.clock(player.length - player.position)
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: player.host.theme.textFontFamily
        font.pixelSize: player.host.theme.px(12)
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
      }
    }

    // ---------- Controls ----------

    Item {
      Layout.fillWidth: true
      Layout.topMargin: player.length > 0 ? 16 : 22
      Layout.preferredHeight: 48

      component Control: Text {
        id: control
        property string name: ""
        property bool available: true
        signal activated()
        color: "#ffffff"
        opacity: available ? (controlMouse.pressed ? 0.6 : 1) : 0.35
        Behavior on opacity { MotionAnimation { theme: player.host.theme; pace: "quick"; curve: "fade" } }
        font.family: player.host.theme.fontFamily
        scale: controlMouse.pressed ? 0.94 : 1
        Behavior on scale { MotionAnimation { theme: player.host.theme; pace: controlMouse.pressed ? "press" : "standard" } }
        MouseArea {
          id: controlMouse
          anchors.fill: parent
          anchors.margins: -10
          enabled: control.available
          cursorShape: Qt.PointingHandCursor
          onClicked: control.activated()
        }
        Tooltip { theme: player.host.theme; text: control.name; above: true }
      }

      Row {
        anchors.centerIn: parent
        spacing: 46
        Control {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰑟"
          name: "Previous"
          font.pixelSize: player.host.theme.px(34)
          available: !!(player.mpris && player.mpris.canGoPrevious)
          onActivated: player.action("previous")
        }
        Control {
          anchors.verticalCenter: parent.verticalCenter
          text: player.playing ? "󰏤" : "󰐊"
          name: player.playing ? "Pause" : "Play"
          font.pixelSize: player.host.theme.px(42)
          available: !!player.mpris
          onActivated: player.action("playPause")
        }
        Control {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰈑"
          name: "Next"
          font.pixelSize: player.host.theme.px(34)
          available: !!(player.mpris && player.mpris.canGoNext)
          onActivated: player.action("next")
        }
      }
    }
  }
}
