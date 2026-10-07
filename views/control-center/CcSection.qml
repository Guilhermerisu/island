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
  default property alias content: body.data

  Layout.fillWidth: true
  Layout.preferredHeight: body.implicitHeight + 54
  radius: 16
  color: center.card
  border.width: 1
  border.color: center.edge

  Text {
    anchors.left: parent.left
    anchors.leftMargin: 16
    anchors.top: parent.top
    anchors.topMargin: 14
    text: sec.title
    color: center.text
    font.family: center.host.theme.textFontFamily
    font.pixelSize: center.host.theme.px(14)
    font.weight: Font.DemiBold
    font.letterSpacing: -0.2
  }
  Text {
    anchors.right: parent.right
    anchors.rightMargin: sec.showChevron ? 44 : 16
    anchors.top: parent.top
    anchors.topMargin: 15
    text: sec.detail
    color: center.textMuted
    font.family: center.host.theme.textFontFamily
    font.pixelSize: center.host.theme.px(12)
  }
  Rectangle {
    id: chevron
    visible: sec.showChevron
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.top: parent.top
    anchors.topMargin: 10
    width: 24; height: 24; radius: 12
    color: chevronMouse.containsMouse ? center.wellHover : center.well
    Tooltip { theme: center.host.theme; text: sec.chevronOpen ? sec.chevronHideLabel : sec.chevronLabel }
    Text {
      anchors.centerIn: parent
      text: "󰅂"
      rotation: sec.chevronOpen ? 90 : 0
      color: center.textMuted
      font.family: center.iconFont
      font.pixelSize: center.host.theme.px(15)
      Behavior on rotation { MotionAnimation { theme: center.host.theme; pace: "standard" } }
    }
    MouseArea { id: chevronMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.chevronClicked() }
  }
  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 42
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 6
  }
}
