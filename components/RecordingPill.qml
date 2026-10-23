import QtQuick

// Screen recording live activity, fed by ScreenRecorder.qml: a pulsing red
// dot left of the clock and the time recorded on the right, then "Saving…"
// while Omarchy finishes the video. Clicking it stops the recording.
Item {
  id: pill
  required property var host
  readonly property var recorder: host.recorder
  readonly property bool shown: host.recordingPill
  readonly property color ink: host.settings.colorfulLiveActivities ? pill.host.theme.system.red : host.theme.accent

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  PillReveal { id: reveal; theme: pill.host.theme; shown: pill.shown }

  Rectangle {
    id: dot
    scale: 0.9 + 0.1 * reveal.leadingIn
    layer.enabled: reveal.leadingIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.leadingIn }
    anchors.left: parent.left
    anchors.leftMargin: 17
    anchors.verticalCenter: parent.verticalCenter
    width: 12; height: 12; radius: 6
    color: pill.ink
    property real pulse: 1
    opacity: (pill.recorder.recording ? pulse : 0.35) * reveal.leadingIn
    SequentialAnimation on pulse {
      running: pill.shown && pill.recorder.recording
      loops: Animation.Infinite
      alwaysRunToEnd: true
      NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
    }
  }
  Text {
    opacity: reveal.trailingIn
    scale: 0.9 + 0.1 * reveal.trailingIn
    layer.enabled: reveal.trailingIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.trailingIn }
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
