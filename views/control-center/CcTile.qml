import QtQuick
import QtQuick.Layouts

// A control tile: a round badge with the icon, and the title over a status.
// `center` is the ControlCenter, for its colours.
Rectangle {
  id: t
  required property var center
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property bool checked: false
  property bool available: true
  // When set, the badge toggles and the rest of the tile opens details.
  property bool opens: false
  signal clicked()
  signal opened()

  Layout.fillWidth: true
  Layout.preferredWidth: 1
  Layout.preferredHeight: 72
  radius: 16
  color: tileMouse.containsMouse ? center.tile : center.card
  border.width: 1
  border.color: center.edge
  opacity: available ? 1 : 0.5
  scale: tileMouse.pressed ? 0.97 : 1
  Behavior on scale { NumberAnimation { duration: 120 * center.host.theme.motionScale; easing.type: Easing.OutCubic } }

  Rectangle {
    id: badge
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 42; height: 42; radius: 21
    color: t.checked ? center.accent : center.well
    Behavior on color { ColorAnimation { duration: center.animDuration; easing.type: Easing.OutCubic } }
    Text {
      anchors.centerIn: parent
      text: t.icon
      color: t.checked ? center.accentInk : center.text
      font.family: center.iconFont
      font.pixelSize: 19
    }
  }
  Column {
    anchors.left: badge.right
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Text {
      width: parent.width
      text: t.title
      elide: Text.ElideRight
      color: center.text
      font.family: "Adwaita Sans"
      font.pixelSize: 14
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
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }
  }
  MouseArea {
    id: tileMouse
    anchors.fill: parent
    enabled: t.available
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: t.opens ? t.opened() : t.clicked()
  }
  MouseArea {
    visible: t.opens
    anchors.fill: badge
    enabled: t.available
    cursorShape: Qt.PointingHandCursor
    onClicked: t.clicked()
  }
}
