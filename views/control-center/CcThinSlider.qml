import QtQuick
import "../../components"

// A slider (Sound, Microphone, Display) in the control center's Small size:
// one short card with the icon (the mute, where there is one), a thin track,
// the level and, for Sound and the microphone, a › that opens the popover
// with the sources (CcLevelPopover). Fills its parent.
// `center` is the ControlCenter.
Rectangle {
  id: s
  required property var center
  required property string controlKey
  readonly property real knob: 14
  readonly property real iconWidth: 34
  readonly property real valueWidth: 52
  // The › at the end.
  readonly property real chevronWidth: info.hasSources ? 24 : 0

  radius: Math.min(center.cardRadius, height / 2)
  color: center.card
  border.width: 1
  border.color: center.edge
  opacity: info.available ? 1 : 0.5
  Behavior on opacity { MotionAnimation { theme: center.host.theme; pace: "fade"; curve: "fade" } }

  CcControlState { id: info; center: s.center; controlKey: s.controlKey }
  Component { id: popover; CcLevelPopover {} }

  // Animated for the level only, not while it's dragged (as CcSlider).
  property real shown: info.value
  Behavior on shown { enabled: !drag.pressed; MotionAnimation { theme: s.center.host.theme; pace: "quick" } }

  Text {
    x: 2
    width: s.iconWidth
    anchors.verticalCenter: parent.verticalCenter
    horizontalAlignment: Text.AlignHCenter
    text: info.icon
    color: info.checked || !info.clickable ? s.center.text : s.center.textMuted
    font.family: s.center.iconFont
    font.pixelSize: s.center.host.theme.px(16)
    MouseArea {
      anchors.fill: parent
      anchors.margins: -4
      enabled: info.available && info.clickable
      cursorShape: Qt.PointingHandCursor
      onClicked: info.activate()
    }
  }
  Item {
    id: track
    x: s.iconWidth + 2
    width: s.width - x - s.valueWidth - s.chevronWidth
    height: parent.height
    Rectangle {
      id: rail
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: 3
      color: s.center.host.theme.fill(drag.containsMouse ? "stronger" : "strong")
      Behavior on color { MotionColorAnimation { theme: s.center.host.theme } }
      Rectangle {
        height: parent.height
        radius: 3
        width: s.knob / 2 + (parent.width - s.knob) * Math.max(0, Math.min(1, s.shown))
        color: s.center.text
      }
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x: (parent.width - s.knob) * Math.max(0, Math.min(1, s.shown))
      width: s.knob; height: s.knob; radius: s.knob / 2
      color: s.center.text
    }
    MouseArea {
      id: drag
      anchors.fill: parent
      enabled: info.available
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      // The page scrolls: a drag that wanders stays on the slider.
      preventStealing: true
      function apply(x) { info.setValue((x - s.knob / 2) / (width - s.knob)) }
      onPressed: function(e) { apply(e.x) }
      onPositionChanged: function(e) { if (pressed) apply(e.x) }
      onWheel: function(e) { e.accepted = info.nudge(e.angleDelta.y > 0) }
    }
  }
  Text {
    anchors.right: parent.right
    anchors.rightMargin: 10 + s.chevronWidth
    anchors.verticalCenter: parent.verticalCenter
    text: info.detail
    color: s.center.textMuted
    font.family: s.center.host.theme.textFontFamily
    font.features: { "tnum": 1 }
    font.pixelSize: s.center.host.theme.size.subheadline
    font.letterSpacing: s.center.host.theme.tracking(s.center.host.theme.textFontFamily, s.center.host.theme.size.subheadline)
  }
  // The sources, in a popover (a click on it, open, closes it).
  Rectangle {
    id: chevron
    visible: info.hasSources
    anchors.right: parent.right
    anchors.rightMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    width: s.chevronWidth - 4
    height: Math.min(parent.height - 4, 24)
    radius: height / 2
    color: chevronTip.hovered || s.center.popoverOpen ? s.center.well : "transparent"
    Behavior on color { MotionColorAnimation { theme: s.center.host.theme } }
    Text {
      anchors.centerIn: parent
      text: "›"
      color: s.center.textMuted
      font.family: s.center.host.theme.textFontFamily
      font.pixelSize: s.center.host.theme.size.body
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: info.openPopover(chevron, popover)
    }
    Tooltip { id: chevronTip; theme: s.center.host.theme; text: s.controlKey === "microphone" ? "Microphone Input" : "Sound Output" }
  }
}
