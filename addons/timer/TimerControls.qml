import QtQuick
import "../../components"

// A set timer's controls, as iOS's expanded live activity: leading, an
// orange round button that pauses or resumes it and a grey one that
// cancels it; trailing, a small label on the countdown's baseline. Used by
// the timer view. `timer` is the TimerAddon.
Item {
  id: controls
  required property var timer
  property real buttonSize: 52
  property real timeSize: 46
  readonly property var theme: timer.host.theme
  readonly property string phase: timer.phase

  implicitHeight: Math.max(buttonSize, time.implicitHeight)

  component RoundButton: Rectangle {
    id: button
    property string glyph: ""
    property color ink: "#ffffff"
    signal clicked()
    width: controls.buttonSize
    height: width
    radius: width / 2
    scale: mouse.pressed ? 0.92 : 1
    Behavior on scale { MotionAnimation { theme: controls.theme; pace: mouse.pressed ? "press" : "standard" } }
    Text {
      anchors.centerIn: parent
      text: button.glyph
      color: button.ink
      font.family: controls.theme.fontFamily
      font.pixelSize: Math.round(controls.buttonSize * 0.7)
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: 12
    RoundButton {
      color: controls.timer.tintWell
      ink: controls.timer.tint
      glyph: controls.phase === "paused" ? "󰐊" : "󰏤"
      onClicked: controls.timer.togglePause()
    }
    RoundButton {
      color: "#48484a"
      glyph: "󰅖"
      onClicked: controls.timer.cancel()
    }
  }

  Text {
    id: label
    anchors.right: time.left
    anchors.rightMargin: 8
    y: time.y + time.baselineOffset - baselineOffset
    text: controls.phase === "paused" ? "Paused" : "Timer"
    color: controls.timer.tint
    font.family: controls.theme.textFontFamily
    font.pixelSize: Math.round(controls.timeSize * 0.4)
    font.weight: Font.Medium
  }
  Text {
    id: time
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: controls.timer.timeText(controls.timer.remaining)
    color: controls.timer.tint
    font.family: controls.theme.textFontFamily
    font.pixelSize: controls.timeSize
    font.weight: Font.Light
    font.features: { "tnum": 1, "case": 1 }
    font.letterSpacing: -1
  }
}
