import QtQuick

// Screen recording live activity, fed by ScreenRecorder.qml: a pulsing red
// dot left of the clock and the time recorded on the right, then "Saving…"
// while Omarchy finishes the video. Clicking it stops the recording.
IslandPill {
  id: pill
  readonly property var recorder: host.recorder
  readonly property color ink: host.settings.colorfulLiveActivities ? pill.host.theme.system.red : host.theme.accent
  shown: host.recordingPill
  pillWidth: 240
  keepsClock: true
  function clicked(mouse) { recorder.stop() }

  PillReveal { id: reveal; theme: pill.host.theme; shown: pill.shown }

  Rectangle {
    id: dot
    PillPart { progress: reveal.leadingIn }
    anchors.left: parent.left
    anchors.leftMargin: 17
    anchors.verticalCenter: parent.verticalCenter
    width: 12; height: 12; radius: 6
    color: pill.ink
    property real pulse: 1
    opacity: (pill.recorder.recording ? pulse : 0.35) * reveal.leadingIn
    SequentialAnimation on pulse {
      running: pill.shown && pill.recorder.recording
      // Stops with the pill rather than finishing its swing (up to 1.4 s on).
      loops: Animation.Infinite
      NumberAnimation { to: 0.35; duration: pill.host.theme.scaled(467); easing.type: Easing.InOutSine }
      NumberAnimation { to: 1; duration: pill.host.theme.scaled(467); easing.type: Easing.InOutSine }
    }
  }
  Text {
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: pill.recorder.recording ? pill.recorder.timeText(pill.recorder.elapsed) : "Saving…"
    color: pill.ink
    font.family: pill.host.theme.textFontFamily
    font.pixelSize: pill.host.theme.px(13)
    font.weight: Font.Medium
    font.features: { "tnum": 1, "case": 1 }
    font.letterSpacing: -0.2
  }
}
