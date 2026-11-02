import QtQuick
import QtQuick.Layouts
import "../../components"

// Section card with a title row (and an optional › button) over content.
// `center` is the ControlCenter, for its colours.
Rectangle {
  id: sec
  required property var center
  property string title: ""
  property string detail: ""
  property bool showChevron: false
  property bool chevronOpen: false
  property string chevronLabel: "Sound Output"
  property string chevronHideLabel: "Hide Outputs"
  signal chevronClicked()
  // An optional round toggle left of the › (Sound's mute, Microphone's).
  property string toggleIcon: ""
  property bool toggleOn: false
  property string toggleTip: ""
  signal toggleClicked()
  readonly property real headerRight: (showChevron ? 44 : 16) + (toggleIcon !== "" ? 28 : 0)
  default property alias content: body.data

  Layout.fillWidth: true
  Layout.preferredHeight: body.implicitHeight + 52
  radius: center.cardRadius
  color: center.card
  border.width: 1
  border.color: center.edge

  Text {
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
    anchors.right: parent.right
    anchors.rightMargin: sec.headerRight
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
    visible: sec.showChevron
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.top: parent.top
    anchors.topMargin: 9
    width: 22; height: 22; radius: 11
    color: chevronMouse.containsMouse ? center.wellHover : center.well
    Tooltip { theme: center.host.theme; text: sec.chevronOpen ? sec.chevronHideLabel : sec.chevronLabel }
    Text {
      anchors.centerIn: parent
      text: "󰅂"
      rotation: sec.chevronOpen ? 90 : 0
      color: center.textMuted
      font.family: center.iconFont
      font.pixelSize: center.host.theme.px(14)
      Behavior on rotation { MotionAnimation { theme: center.host.theme; pace: "standard" } }
    }
    MouseArea { id: chevronMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.chevronClicked() }
  }
  Rectangle {
    visible: sec.toggleIcon !== ""
    scale: toggleMouse.pressed ? 0.92 : 1
    Behavior on scale { MotionAnimation { theme: center.host.theme; pace: toggleMouse.pressed ? "press" : "standard" } }
    anchors.right: parent.right
    anchors.rightMargin: sec.showChevron ? 42 : 14
    anchors.top: parent.top
    anchors.topMargin: 9
    width: 22; height: 22; radius: 11
    color: sec.toggleOn ? center.host.theme.system.red : toggleMouse.containsMouse ? center.wellHover : center.well
    Behavior on color { MotionColorAnimation { theme: center.host.theme } }
    Tooltip { theme: center.host.theme; text: sec.toggleTip }
    Text {
      anchors.centerIn: parent
      text: sec.toggleIcon
      color: sec.toggleOn ? "#ffffff" : center.textMuted
      font.family: center.iconFont
      font.pixelSize: center.host.theme.px(13)
    }
    MouseArea { id: toggleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.toggleClicked() }
  }
  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 38
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 6
  }
}
