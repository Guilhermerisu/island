import QtQuick
import "../../components"

// The timer view. Unset, play and cancel buttons, and after a "Timer"
// label, as the countdown has, how long it's set to ("15 min", each time it
// opens), turned a minute at a time like one of iOS's picker wheels:
// scrolled, dragged up or down, or with ↑/↓, the new length rolling in as on
// a drum. Play or Enter starts it and folds the island back to its pill;
// cancel closes the view. Once set, its controls (see TimerControls): Space
// pauses or resumes. Esc closes. `timer` is the TimerAddon.
Item {
  id: view
  required property var timer
  property bool active: false
  readonly property var host: timer.host
  readonly property bool picking: timer.phase === "idle"
  readonly property int defaultMinutes: 15
  readonly property int maxMinutes: 24 * 60 - 1
  property int minutes: defaultMinutes

  implicitHeight: 52

  onActiveChanged: if (active) reset()
  onPickingChanged: if (active) reset()
  function reset() {
    minutes = defaultMinutes
    roller.stop()
    roller.roll = 0
    Qt.callLater(function() { view.forceActiveFocus() })
  }
  Keys.onEscapePressed: host.view = "rest"
  Keys.onSpacePressed: if (timer.phase === "running" || timer.phase === "paused") timer.togglePause()
  Keys.onReturnPressed: if (picking) start()
  Keys.onEnterPressed: if (picking) start()
  Keys.onUpPressed: if (picking) turn(-1)
  Keys.onDownPressed: if (picking) turn(1)

  // Down (or a scroll down) is a minute more, the next one rolling up from
  // below, as on a wheel.
  property string leaving: ""
  property int direction: 1
  function turn(by) {
    var next = Math.max(1, Math.min(maxMinutes, minutes + by))
    if (next === minutes) return
    leaving = timer.durationText(minutes * 60000)
    direction = by > 0 ? 1 : -1
    minutes = next
    roller.restart()
  }
  function start() {
    timer.start(minutes * 60000)
    host.view = "rest"
  }

  component Fade: Item {
    property bool on: false
    anchors.fill: parent
    opacity: on ? 1 : 0
    visible: opacity > 0.01
    enabled: on
    Behavior on opacity { MotionAnimation { theme: view.host.theme; pace: "fade"; curve: "fade" } }
  }

  Fade {
    on: view.picking

    Rectangle {
      id: startButton
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 52
      height: width
      radius: width / 2
      color: view.timer.tintWell
      scale: startMouse.pressed ? 0.92 : 1
      Behavior on scale { MotionAnimation { theme: view.host.theme; pace: startMouse.pressed ? "press" : "standard" } }
      Text {
        anchors.centerIn: parent
        text: "󰐊"
        color: view.timer.tint
        font.family: view.host.theme.fontFamily
        font.pixelSize: Math.round(parent.width * 0.7)
      }
      MouseArea {
        id: startMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: view.start()
      }
    }

    // Beside it, one that closes the view without starting.
    Rectangle {
      id: cancelButton
      anchors.left: startButton.right
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 52
      height: width
      radius: width / 2
      color: "#48484a"
      scale: cancelMouse.pressed ? 0.92 : 1
      Behavior on scale { MotionAnimation { theme: view.host.theme; pace: cancelMouse.pressed ? "press" : "standard" } }
      Text {
        anchors.centerIn: parent
        text: "󰅖"
        color: "#ffffff"
        font.family: view.host.theme.fontFamily
        font.pixelSize: Math.round(parent.width * 0.7)
      }
      MouseArea {
        id: cancelMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: view.host.view = "rest"
      }
    }

    // As in the running view, a small label on the length's baseline.
    Text {
      id: timerLabel
      anchors.right: well.left
      anchors.rightMargin: -2
      y: well.y + (drum.height - current.height) / 2 + current.baselineOffset - baselineOffset
      text: "Timer"
      color: view.timer.tint
      font.family: view.host.theme.textFontFamily
      font.pixelSize: Math.round(46 * 0.4)
      font.weight: Font.Medium
    }

    // The length, on a faint well while hovered: the old one turning away
    // and fading as the new one comes in.
    Rectangle {
      id: well
      anchors.right: parent.right
      anchors.rightMargin: -10
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(current.implicitWidth, previous.implicitWidth * roller.roll) + 20
      height: 56
      radius: 14
      color: view.timer.tintWell
      opacity: wheelMouse.containsMouse || wheelMouse.pressed ? 0.4 : 0
      Behavior on opacity { MotionAnimation { theme: view.host.theme; pace: "fade"; curve: "fade" } }
    }
    Item {
      id: drum
      anchors.fill: well
      clip: true
      NumberAnimation {
        id: roller
        target: roller
        property real roll: 0
        property: "roll"
        from: 1
        to: 0
        duration: 220
        easing.type: Easing.OutCubic
      }
      component Face: Text {
        property real shift: 0
        // A long length ("23 h 59 min") shrinks to fit between the label
        // and the buttons.
        width: Math.min(implicitWidth, view.width - 2 * 52 - 12 - 16 - timerLabel.implicitWidth - 20)
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 22
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: (drum.height - height) / 2 + shift * drum.height * 0.8
        color: view.timer.tint
        font.family: view.host.theme.textFontFamily
        font.pixelSize: 46
        font.weight: Font.Light
        font.features: { "tnum": 1, "case": 1 }
        font.letterSpacing: -1
        transform: Scale {
          origin.y: height / 2
          yScale: Math.max(0, 1 - Math.abs(shift) * 0.6)
        }
      }
      Face {
        id: previous
        visible: roller.roll > 0
        text: view.leaving
        shift: -view.direction * (1 - roller.roll)
        opacity: roller.roll
      }
      Face {
        id: current
        text: view.timer.durationText(view.minutes * 60000)
        shift: view.direction * roller.roll
        opacity: 1 - roller.roll * 0.8
      }
    }
    // A notch of the wheel (or a touchpad's worth of one), or a drag of a
    // row's height, is a minute.
    MouseArea {
      id: wheelMouse
      anchors.fill: well
      hoverEnabled: true
      cursorShape: Qt.SizeVerCursor
      property real held: 0
      property real lastY: 0
      onWheel: function(wheel) {
        held -= wheel.angleDelta.y
        while (held >= 120) { view.turn(1); held -= 120 }
        while (held <= -120) { view.turn(-1); held += 120 }
      }
      onPressed: function(mouse) { lastY = mouse.y }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        var rows = Math.trunc((lastY - mouse.y) / 18)
        if (rows === 0) return
        view.turn(rows)
        lastY -= rows * 18
      }
    }
  }

  Fade {
    on: !view.picking
    TimerControls {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      timer: view.timer
    }
  }
}
