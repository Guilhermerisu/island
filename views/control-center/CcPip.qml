import QtQuick
import "../../components"

// A control as a round pip, icon alone, in the control center's XSmall row
// (CcPipRow). `center` is the ControlCenter.
//
// A tile (Wi-Fi, Bluetooth, an addon's): click switches it, right click opens
// its details. A slider (Sound, Microphone, Display) wears a ring of its
// level around the icon (the ring is empty while it is muted):
//   wheel          the level, 5 % a step;
//   press and hold, then drag, up or right for more, down or left for less
//                  the level continuously, the ring follows; release ends it;
//   click          mutes / unmutes Sound and the microphone, opens the
//                  popover of Display (nothing to mute);
//   right click    the popover: the slider and the sources (CcLevelPopover).
// The tip gives the level, live.
Item {
  id: pip
  required property var center
  required property string controlKey
  // The ring's outside, and the disc inside it (a tile's badge, almost).
  readonly property real size: 44
  readonly property real discSize: 36
  readonly property real ringThickness: 3
  // How far a hold has to be dragged to go through the whole level.
  readonly property real dragRange: 140
  // Held for this long, a press is a hold; moved past `slop` before, it is
  // neither a hold nor a click.
  readonly property int holdDelay: 250
  readonly property real slop: 8
  readonly property bool slider: info.isSlider
  // A hold is under way: the level, not the icon, is shown.
  readonly property bool holding: mouse.held
  width: size
  height: size
  opacity: info.available ? 1 : 0.5
  Behavior on opacity { MotionAnimation { theme: pip.center.host.theme; pace: "fade"; curve: "fade" } }

  CcControlState { id: info; center: pip.center; controlKey: pip.controlKey }
  Component { id: popover; CcLevelPopover {} }

  // Scaled by a press, apart from the area that reads the pointer, so the
  // scale doesn't move the pointer under a drag.
  Item {
    anchors.fill: parent
    scale: mouse.pressed ? 0.92 : 1
    Behavior on scale { id: scaleMotion1; MotionAnimation { theme: pip.center.host.theme; pace: towards(scaleMotion1.targetValue, mouse.pressed ? "press" : "standard") } }

    Ring {
      visible: pip.slider
      anchors.fill: parent
      view: pip.center
      thickness: pip.ringThickness
      color: pip.center.accent
      text: ""
      value: info.ringLevel * 100
    }
    Rectangle {
      anchors.centerIn: parent
      width: pip.discSize; height: width; radius: width / 2
      // A slider's level is on its ring; a tile's state is its disc.
      color: !pip.slider && info.checked ? pip.center.accent : !pip.slider && tip.hovered && info.available && info.clickable ? pip.center.wellHover : pip.center.well
      Behavior on color { MotionColorAnimation { theme: pip.center.host.theme } }
      Text {
        anchors.centerIn: parent
        visible: !pip.holding
        text: info.icon
        color: info.checked && !pip.slider ? pip.center.badgeOnInk : pip.slider && !info.checked ? pip.center.textMuted : pip.center.text
        Behavior on color { MotionColorAnimation { theme: pip.center.host.theme } }
        font.family: info.iconFamily || pip.center.iconFont
        font.pixelSize: pip.center.host.theme.px(17)
      }
      // While held, what the ring is at.
      Text {
        anchors.centerIn: parent
        visible: pip.holding
        text: Math.round(info.value * 100)
        color: pip.center.text
        font.family: pip.center.host.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: pip.center.host.theme.size.subheadline
        font.weight: Font.DemiBold
      }
    }
    Tooltip {
      id: tip
      theme: pip.center.host.theme
      text: info.title + (info.subtitle !== "" ? " · " + info.subtitle : "")
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    // Editing (CcSlot's) takes the pointer, a pip is not to be used then.
    enabled: info.available && !pip.center.editMode
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: info.clickable || pip.slider ? Qt.PointingHandCursor : Qt.ArrowCursor
    // A press is the pip's own, up to its release: the page and the zone
    // don't take a drag that wanders.
    preventStealing: pressed
    // Where the hold started: the pointer and the level.
    property bool held: false
    // The press became a hold or a drag, so its release is not a click.
    property bool spent: false
    property real pressX: 0
    property real pressY: 0
    property real holdX: 0
    property real holdY: 0
    property real holdLevel: 0

    Timer {
      id: holdTimer
      interval: pip.holdDelay
      onTriggered: {
        mouse.held = true
        mouse.spent = true
        mouse.holdX = mouse.mouseX
        mouse.holdY = mouse.mouseY
        mouse.holdLevel = info.value
      }
    }
    function end() { holdTimer.stop(); held = false }
    onPressed: function(e) {
      spent = false
      pressX = e.x
      pressY = e.y
      if (e.button === Qt.LeftButton && pip.slider) holdTimer.restart()
    }
    onPositionChanged: function(e) {
      if (held) {
        // Right and up raise it, left and down lower it, whichever way the
        // pointer goes.
        info.setValue(holdLevel + ((e.x - holdX) + (holdY - e.y)) / pip.dragRange)
      } else if (pressed && !spent && Math.abs(e.x - pressX) + Math.abs(e.y - pressY) > pip.slop) {
        spent = true
        holdTimer.stop()
      }
    }
    onReleased: end()
    onCanceled: end()
    onClicked: function(e) {
      if (spent) return
      if (e.button === Qt.RightButton) {
        if (pip.slider) info.openPopover(pip, popover)
        else info.openDetails()
      } else if (pip.controlKey === "display") info.openPopover(pip, popover)
      else info.activate()
    }
    // Only a slider takes the wheel; elsewhere it goes on to the row.
    onWheel: function(e) { e.accepted = pip.slider && info.nudge(e.angleDelta.y > 0) }
  }
}
