import QtQuick
import "../../components"
import QtQuick.Layouts

// A control tile, as macOS's: a capsule with a round badge for the icon at
// its end, and the title over a status.
// `center` is the ControlCenter, for its colours.
Rectangle {
  id: t
  required property var center
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property bool checked: false
  property bool available: true
  // When unset the tile only reports (Ethernet), and doesn't respond.
  property bool clickable: true
  // When set, the badge toggles and the rest of the tile opens details.
  property bool opens: false
  signal clicked()
  signal opened()

  Layout.fillWidth: true
  Layout.preferredWidth: 1
  Layout.preferredHeight: 72
  radius: height / 2
  color: tileMouse.containsMouse ? center.tile : center.card
  border.width: 1
  border.color: center.edge
  Behavior on color { MotionColorAnimation { theme: center.host.theme } }
  opacity: available ? 1 : 0.5
  Behavior on opacity { MotionAnimation { theme: center.host.theme; pace: "fade"; curve: "fade" } }
  scale: tileMouse.pressed || badgeMouse.pressed ? 0.97 : 1
  Behavior on scale { MotionAnimation { theme: center.host.theme; pace: tileMouse.pressed || badgeMouse.pressed ? "press" : "standard" } }

  Rectangle {
    id: badge
    anchors.left: parent.left
    anchors.leftMargin: (t.height - height) / 2
    anchors.verticalCenter: parent.verticalCenter
    width: 44; height: 44; radius: 22
    color: t.checked ? center.accent : center.well
    Behavior on color { MotionColorAnimation { theme: center.host.theme } }
    Text {
      anchors.centerIn: parent
      text: t.icon
      color: t.checked ? center.badgeOnInk : center.text
      Behavior on color { MotionColorAnimation { theme: center.host.theme } }
      font.family: center.iconFont
      font.pixelSize: center.host.theme.px(20)
    }
  }
  Column {
    anchors.left: badge.right
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.rightMargin: 18
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Text {
      width: parent.width
      text: t.title
      elide: Text.ElideRight
      color: center.text
      font.family: center.host.theme.textFontFamily
      font.pixelSize: center.host.theme.px(14)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
    }
    Text {
      width: parent.width
      visible: t.subtitle !== ""
      text: t.subtitle
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: center.textMuted
      font.family: center.host.theme.textFontFamily
      font.pixelSize: center.host.theme.px(12)
    }
  }
  MouseArea {
    id: tileMouse
    anchors.fill: parent
    enabled: t.available && t.clickable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: t.opens ? t.opened() : t.clicked()
  }
  MouseArea {
    id: badgeMouse
    visible: t.opens
    anchors.fill: badge
    enabled: t.available
    cursorShape: Qt.PointingHandCursor
    onClicked: t.clicked()
  }
}
