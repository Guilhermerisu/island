import QtQuick
import "../../components"

// The timer in a control center zone set XSmall or Small (see "Zone sizes" in
// Addon.qml), drawn for those and not the view cut down. XSmall is one line
// (34 of the 42 px its card leaves): a ring, the time left, and the buttons
// that pause or resume and cancel it (or, unset, "Timer" and a button that
// starts the shortest preset); a click anywhere else opens the timer view.
// Small has room for a larger ring, the time big, and pause and cancel (or
// the presets and "Custom", unset). A length of the Normal view's own picker
// is a popover: "Custom" in Small, a right click anywhere in XSmall. Used by
// TimerView, which gives it `center` and `picker` (the popover's Component,
// from TimerZone); without them (the island's view) there is no popover.
// `timer` is the TimerAddon.
Item {
  id: compact
  required property var timer
  property bool small: false
  property var center: null
  property Component picker: null
  readonly property var theme: timer.host.theme
  readonly property bool picking: timer.phase === "idle"
  readonly property bool paused: timer.phase === "paused"
  // Dims while paused, as the pill's does.
  readonly property color ink: paused ? timer.tintDim : timer.tint
  implicitHeight: small ? 48 : 34

  // The picker under `anchor`, when unset (the popover is the control center's).
  function custom(anchor) {
    if (picking && center && picker) center.openPopover(anchor, picker, {})
  }

  component RoundButton: Rectangle {
    id: button
    property string glyph: ""
    property color ink: compact.timer.tint
    property string label: ""
    signal clicked()
    height: parent ? parent.height : 34
    width: label ? content.implicitWidth + 24 : height
    radius: height / 2
    scale: mouse.pressed ? 0.92 : 1
    Behavior on scale { id: scaleMotion1; MotionAnimation { theme: compact.theme; pace: towards(scaleMotion1.targetValue, mouse.pressed ? "press" : "standard") } }
    Row {
      id: content
      anchors.centerIn: parent
      spacing: 4
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: button.glyph
        color: button.ink
        font.family: compact.theme.fontFamily
        font.pixelSize: Math.round(button.height * (button.label ? 0.5 : 0.62))
      }
      Text {
        visible: button.label !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: button.label
        color: button.ink
        font.family: compact.theme.textFontFamily
        font.letterSpacing: compact.theme.tracking(compact.theme.textFontFamily, compact.theme.size.callout)
        font.pixelSize: compact.theme.size.callout
        font.weight: Font.Medium
      }
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  // The time left, shrunk to the room it's given rather than cut.
  component Countdown: Item {
    id: countdown
    property real pixelSize: 18
    implicitHeight: digits.implicitHeight
    RollingText {
      id: digits
      theme: compact.theme
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: implicitWidth
      transformOrigin: Item.Left
      scale: implicitWidth > countdown.width ? countdown.width / implicitWidth : 1
      text: compact.timer.timeText(compact.timer.remaining)
      color: compact.ink
      font.family: compact.theme.textFontFamily
      font.pixelSize: compact.theme.px(countdown.pixelSize)
      font.weight: Font.Light
      font.features: { "tnum": 1, "case": 1 }
      font.letterSpacing: compact.theme.tracking(compact.theme.textFontFamily, compact.theme.px(countdown.pixelSize))
    }
  }

  // Behind everything, so the buttons keep their own clicks.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) compact.custom(compact)
      else compact.timer.host.view = "timer"
    }
  }

  // ---------- XSmall ----------

  Item {
    anchors.fill: parent
    visible: !compact.small

    Row {
      visible: compact.picking
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰔛"
        color: compact.timer.tint
        font.family: compact.theme.fontFamily
        font.pixelSize: compact.theme.px(22)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Timer"
        color: compact.theme.text
        font.family: compact.theme.textFontFamily
        font.letterSpacing: compact.theme.tracking(compact.theme.textFontFamily, compact.theme.size.title3)
        font.pixelSize: compact.theme.size.title3
        font.weight: Font.Medium
      }
    }
    RoundButton {
      visible: compact.picking
      anchors.right: parent.right
      color: compact.timer.tintWell
      glyph: "󰐊"
      label: compact.timer.durationText(compact.timer.presets[0])
      onClicked: compact.timer.start(compact.timer.presets[0])
    }

    TimerRing {
      id: smallRing
      visible: !compact.picking
      anchors.verticalCenter: parent.verticalCenter
      width: 30
      height: 30
      progress: compact.timer.progress
      color: compact.ink
      thickness: 3
    }
    Countdown {
      visible: !compact.picking
      anchors.left: smallRing.right
      anchors.leftMargin: 8
      anchors.right: xsControls.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      pixelSize: 22
    }
    Row {
      id: xsControls
      visible: !compact.picking
      anchors.right: parent.right
      height: parent.height
      spacing: 6
      RoundButton {
        color: compact.timer.tintWell
        glyph: compact.paused ? "󰐊" : "󰏤"
        onClicked: compact.timer.togglePause()
      }
      RoundButton {
        color: compact.theme.well
        ink: compact.theme.text
        glyph: "󰅖"
        onClicked: compact.timer.cancel()
      }
    }
  }

  // ---------- Small ----------

  Item {
    anchors.fill: parent
    visible: compact.small

    // Unset: the presets, one tap to start, and any other length in the
    // picker the Normal view has, as a popover.
    Row {
      id: presets
      visible: compact.picking
      anchors.fill: parent
      spacing: 6
      Repeater {
        model: compact.timer.presets
        delegate: RoundButton {
          required property real modelData
          width: (presets.width - customButton.width - compact.timer.presets.length * presets.spacing) / compact.timer.presets.length
          radius: 14
          color: compact.timer.tintWell
          label: compact.timer.durationText(modelData)
          onClicked: compact.timer.start(modelData)
        }
      }
      RoundButton {
        id: customButton
        radius: 14
        color: compact.theme.well
        ink: compact.theme.text
        label: "Custom"
        onClicked: compact.custom(customButton)
      }
    }

    TimerRing {
      id: bigRing
      visible: !compact.picking
      anchors.verticalCenter: parent.verticalCenter
      width: 44
      height: 44
      progress: compact.timer.progress
      color: compact.ink
      thickness: 4
    }
    Countdown {
      visible: !compact.picking
      anchors.left: bigRing.right
      anchors.leftMargin: 10
      anchors.right: controls.left
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      pixelSize: 30
    }
    Row {
      id: controls
      visible: !compact.picking
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: 40
      spacing: 6
      RoundButton {
        color: compact.timer.tintWell
        glyph: compact.paused ? "󰐊" : "󰏤"
        onClicked: compact.timer.togglePause()
      }
      RoundButton {
        color: compact.theme.well
        ink: compact.theme.text
        glyph: "󰅖"
        onClicked: compact.timer.cancel()
      }
    }
  }
}
