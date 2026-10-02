import QtQuick
import "../../components"

// The timer on the resting island while it's set, as iOS's live activity:
// its ring leading and the time left trailing, both dimmed while it's
// paused, the clock between them. `timer` is the TimerAddon.
Item {
  id: pill
  required property var timer
  readonly property var host: timer.host
  readonly property color ink: timer.phase === "paused" ? timer.tintDim : timer.tint

  opacity: timer.pillShown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  TimerRing {
    anchors.left: parent.left
    anchors.leftMargin: 13
    anchors.verticalCenter: parent.verticalCenter
    width: 20
    height: 20
    progress: pill.timer.progress
    color: pill.ink
    track: Qt.rgba(1, 159 / 255, 10 / 255, 0.25)
    thickness: 3
  }
  Text {
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: pill.timer.timeText(pill.timer.remaining)
    color: pill.ink
    font.family: "Adwaita Sans"
    font.pixelSize: 14
    font.weight: Font.Medium
    font.features: { "tnum": 1, "case": 1 }
    font.letterSpacing: -0.2
  }
}
