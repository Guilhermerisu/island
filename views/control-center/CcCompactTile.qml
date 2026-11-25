import QtQuick
import "../../components"

// A control tile in the control center's Small size: a short card (CcTile's
// look and clicks) with a small badge and the name, no status; the tip gives
// it. Fills its parent. `center` is the ControlCenter.
Rectangle {
  id: t
  required property var center
  required property string controlKey
  readonly property real badgeSize: 28

  radius: Math.min(center.cardRadius, height / 2)
  color: mouse.containsMouse && info.clickable ? center.tile : center.card
  border.width: 1
  border.color: center.edge
  Behavior on color { MotionColorAnimation { theme: center.host.theme } }
  opacity: info.available ? 1 : 0.5
  Behavior on opacity { MotionAnimation { theme: center.host.theme; pace: "fade"; curve: "fade" } }
  scale: mouse.pressed || badgeMouse.pressed ? 0.97 : 1
  Behavior on scale { id: scaleMotion1; MotionAnimation { theme: center.host.theme; pace: towards(scaleMotion1.targetValue, mouse.pressed || badgeMouse.pressed ? "press" : "standard") } }

  CcControlState { id: info; center: t.center; controlKey: t.controlKey }

  Rectangle {
    id: badge
    anchors.left: parent.left
    anchors.leftMargin: (t.height - height) / 2
    anchors.verticalCenter: parent.verticalCenter
    width: t.badgeSize; height: t.badgeSize; radius: t.badgeSize / 2
    color: info.checked ? center.accent : center.well
    Behavior on color { MotionColorAnimation { theme: center.host.theme } }
    Text {
      anchors.centerIn: parent
      text: info.icon
      color: info.checked ? center.badgeOnInk : center.text
      Behavior on color { MotionColorAnimation { theme: center.host.theme } }
      font.family: info.iconFamily || center.iconFont
      font.pixelSize: center.host.theme.px(15)
    }
  }
  Text {
    anchors.left: badge.right
    anchors.leftMargin: 8
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: info.title
    elide: Text.ElideRight
    color: center.text
    font.family: center.host.theme.textFontFamily
    font.pixelSize: center.host.theme.size.body
    font.weight: Font.DemiBold
    font.letterSpacing: center.host.theme.tracking(center.host.theme.textFontFamily, center.host.theme.size.body)
  }
  Tooltip {
    theme: center.host.theme
    text: info.title + (info.subtitle !== "" ? " · " + info.subtitle : "")
  }
  // As CcTile: where the badge switches, the rest opens the details.
  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: info.available && info.clickable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: info.opens ? info.openDetails() : info.activate()
  }
  MouseArea {
    id: badgeMouse
    visible: info.opens
    anchors.fill: badge
    enabled: info.available
    cursorShape: Qt.PointingHandCursor
    onClicked: info.activate()
  }
}
