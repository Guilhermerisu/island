import QtQuick

// macOS's battery symbol: a rounded outline with a nub, filled to the level.
// The fill is green while charging (with a bolt) and red when low.
Item {
  id: battery
  // 0–100.
  property real level: 0
  property bool charging: false
  property bool low: false
  property color color: "#ffffff"
  implicitWidth: 27
  implicitHeight: 13

  Rectangle {
    id: body
    width: parent.width - 3
    height: parent.height
    radius: height * 0.28
    color: "transparent"
    border.width: 1.2
    border.color: Qt.rgba(battery.color.r, battery.color.g, battery.color.b, 0.45)
    Rectangle {
      x: 2
      y: 2
      height: parent.height - 4
      width: Math.max(2, (parent.width - 4) * Math.max(0, Math.min(100, battery.level)) / 100)
      radius: height * 0.22
      color: battery.charging ? "#30d158" : battery.low ? "#ff453a" : battery.color
    }
    Text {
      anchors.centerIn: parent
      visible: battery.charging
      text: "󱐋"
      color: "#ffffff"
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, 0.5)
      font.pixelSize: Math.round(parent.height * 0.8)
    }
  }
  Rectangle {
    anchors.left: body.right
    anchors.leftMargin: 1
    anchors.verticalCenter: body.verticalCenter
    width: 2
    height: Math.round(parent.height * 0.38)
    radius: 1
    color: Qt.rgba(battery.color.r, battery.color.g, battery.color.b, 0.45)
  }
}
