import QtQuick
import QtQuick.Layouts
import "../../components"

// Section card with a title row (and an optional › button) over content.
// `vertical`: a tall card (a slider standing up): no title row or › button,
// the content (the slider, which draws the title itself) fills the card.
// `center` is the ControlCenter, for its colours.
Rectangle {
  id: sec
  required property var center
  property string title: ""
  property string detail: ""
  property bool showChevron: false
  property bool chevronOpen: false
  property bool vertical: false
  property string chevronLabel: "Sound Output"
  property string chevronHideLabel: "Hide Outputs"
  signal chevronClicked()
  // An optional round toggle left of the › (Sound's mute, Microphone's).
  property string toggleIcon: ""
  property string toggleTip: ""
  signal toggleClicked()
  default property alias content: body.data

  Layout.fillWidth: true
  // 12 above the 24px header, 10 under it, 14 below the content.
  Layout.preferredHeight: body.implicitHeight + 60
  radius: center.cardRadius
  // Upright, the slider's pill draws the card itself (rounder than this).
  color: vertical ? "transparent" : center.card
  border.width: sec.vertical ? 0 : 1
  border.color: center.edge

  // The header: the title on the left; the value, the round toggle and the
  // › on the right, all on one 24px line 12px from the top.
  Item {
    id: header
    visible: !sec.vertical
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    anchors.topMargin: 12
    height: 24
    Text {
      anchors.left: parent.left
      anchors.right: headerEnd.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: sec.title
      elide: Text.ElideRight
      color: center.text
      font.family: center.host.theme.textFontFamily
      font.pixelSize: center.host.theme.size.body
      font.weight: Font.DemiBold
      font.letterSpacing: center.host.theme.tracking(center.host.theme.textFontFamily, center.host.theme.size.body)
    }
    Row {
      id: headerEnd
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      RollingText {
        theme: center.host.theme
        anchors.verticalCenter: parent.verticalCenter
        text: sec.detail
        color: center.textMuted
        font.family: center.host.theme.textFontFamily
        font.letterSpacing: center.host.theme.tracking(center.host.theme.textFontFamily, center.host.theme.size.callout)
        font.pixelSize: center.host.theme.size.callout
        font.features: { "tnum": 1 }
      }
      // A round hover button in the value's grey (Sound's mute, Microphone's).
      Rectangle {
        visible: sec.toggleIcon !== ""
        anchors.verticalCenter: parent.verticalCenter
        scale: toggleMouse.pressed ? 0.92 : 1
        Behavior on scale { id: scaleMotion2; MotionAnimation { theme: center.host.theme; pace: towards(scaleMotion2.targetValue, toggleMouse.pressed ? "press" : "standard") } }
        width: 24; height: 24; radius: 12
        color: toggleTip.hovered ? center.well : "transparent"
        Behavior on color { MotionColorAnimation { theme: center.host.theme } }
        Tooltip { id: toggleTip; theme: center.host.theme; text: sec.toggleTip }
        Text {
          anchors.centerIn: parent
          text: sec.toggleIcon
          color: center.textMuted
          font.family: center.iconFont
          font.pixelSize: center.host.theme.px(14)
        }
        MouseArea { id: toggleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.toggleClicked() }
      }
      Rectangle {
        id: chevron
        visible: sec.showChevron
        anchors.verticalCenter: parent.verticalCenter
        scale: chevronMouse.pressed ? 0.92 : 1
        Behavior on scale { id: scaleMotion; MotionAnimation { theme: center.host.theme; pace: towards(scaleMotion.targetValue, chevronMouse.pressed ? "press" : "standard") } }
        width: 24; height: 24; radius: 12
        color: chevronTip.hovered || sec.chevronOpen ? center.well : "transparent"
        Behavior on color { MotionColorAnimation { theme: center.host.theme } }
        Tooltip { id: chevronTip; theme: center.host.theme; text: sec.chevronOpen ? sec.chevronHideLabel : sec.chevronLabel }
        Chevron {
          anchors.centerIn: parent
          theme: center.host.theme
          open: sec.chevronOpen
          color: center.textMuted
          pixelSize: center.host.theme.px(14)
        }
        MouseArea { id: chevronMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.chevronClicked() }
      }
    }
  }
  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: sec.vertical ? 0 : 46
    // Not a bottom anchor: dropping one leaves the tall height behind, and
    // back to horizontal the slider sat out below the card. `undefined`
    // resets the height to follow the content again.
    height: sec.vertical ? parent.height : undefined
    anchors.leftMargin: sec.vertical ? 0 : 14
    anchors.rightMargin: sec.vertical ? 0 : 14
    spacing: 6
  }
}
