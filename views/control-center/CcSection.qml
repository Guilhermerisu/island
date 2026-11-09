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
  default property alias content: body.data

  Layout.fillWidth: true
  Layout.preferredHeight: body.implicitHeight + 52
  radius: center.cardRadius
  // Upright, the slider's pill draws the card itself (rounder than this).
  color: vertical ? "transparent" : center.card
  border.width: sec.vertical ? 0 : 1
  border.color: center.edge

  Text {
    visible: !sec.vertical
    anchors.left: parent.left
    anchors.leftMargin: 16
    anchors.top: parent.top
    anchors.topMargin: 13
    text: sec.title
    color: center.text
    font.family: center.host.theme.textFontFamily
    font.features: { "tnum": 1 }
    font.pixelSize: center.host.theme.px(13)
    font.weight: Font.DemiBold
    font.letterSpacing: -0.1
  }
  Text {
    visible: !sec.vertical
    anchors.right: parent.right
    anchors.rightMargin: sec.showChevron ? 44 : 16
    anchors.top: parent.top
    anchors.topMargin: 14
    text: sec.detail
    color: center.textMuted
    font.family: center.host.theme.textFontFamily
    font.letterSpacing: center.host.theme.tracking(center.host.theme.textFontFamily, center.host.theme.px(11))
    font.pixelSize: center.host.theme.px(11)
    font.features: { "tnum": 1 }
  }
  Rectangle {
    id: chevron
    scale: chevronMouse.pressed ? 0.92 : 1
    Behavior on scale { MotionAnimation { theme: center.host.theme; pace: chevronMouse.pressed ? "press" : "standard" } }
    visible: sec.showChevron && !sec.vertical
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.top: parent.top
    anchors.topMargin: 9
    width: 22; height: 22; radius: 11
    color: chevronMouse.containsMouse ? center.wellHover : center.well
    Tooltip { theme: center.host.theme; text: sec.chevronOpen ? sec.chevronHideLabel : sec.chevronLabel }
    Chevron {
      anchors.centerIn: parent
      theme: center.host.theme
      open: sec.chevronOpen
      color: center.textMuted
      pixelSize: center.host.theme.px(14)
    }
    MouseArea { id: chevronMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.chevronClicked() }
  }
  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: sec.vertical ? 0 : 38
    anchors.bottom: sec.vertical ? parent.bottom : undefined
    anchors.bottomMargin: sec.vertical ? 0 : 12
    anchors.leftMargin: sec.vertical ? 0 : 14
    anchors.rightMargin: sec.vertical ? 0 : 14
    spacing: 6
  }
}
