import QtQuick
import Quickshell.Widgets

// Dynamic Island–style notification pill: the notification's image or app
// icon in a rounded tile, with the title and one line of body beside it.
Item {
  id: pill
  required property var host
  // The island rectangle; the app tile sizes itself from its height.
  required property Item shape
  readonly property var row: host.lastNotification || ({})
  property bool imageFailed: false
  onRowChanged: imageFailed = false
  readonly property string iconSource: host.notificationIconSource(host.lastNotification, imageFailed)
    opacity: host.notificationPill ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * host.motionScale; easing.type: Easing.InOutQuad } }

  ClippingRectangle {
    id: appTile
    anchors.left: parent.left
    anchors.leftMargin: 15
    anchors.verticalCenter: parent.verticalCenter
    // Grows with the pill so it never pokes past the rounded ends.
    width: height
    height: Math.max(0, Math.min(54, shape.height - 30))
    radius: height * 0.28
    color: "transparent"
    Rectangle {
      anchors.fill: parent
      visible: appTileImage.status !== Image.Ready
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(host.colorAccent, 1.25) }
        GradientStop { position: 1; color: host.colorAccent }
      }
    }
    Image {
      id: appTileImage
      anchors.fill: parent
      source: pill.iconSource
      sourceSize.width: 100
      sourceSize.height: 100
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      visible: status === Image.Ready
      onStatusChanged: if (status === Image.Error) pill.imageFailed = true
    }
    Text {
      anchors.centerIn: parent
      visible: appTileImage.status !== Image.Ready
      text: String(pill.row.glyph || "") || "󰂚"
      color: host.colorAccentText
      font.family: host.fontFamily
      font.pixelSize: 24
    }
  }

  Column {
    anchors.left: appTile.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 30
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    Text {
      width: parent.width
      text: String(pill.row.summary || pill.row.app || "Notification")
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: host.colorText
      font.pixelSize: 16
      font.weight: Font.DemiBold
    }
    Text {
      width: parent.width
      text: String(pill.row.body || pill.row.app || "")
      visible: text !== ""
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: host.colorMuted
      font.pixelSize: 13
    }
  }
}
