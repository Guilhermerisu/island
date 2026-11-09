import QtQuick
import Quickshell.Widgets

// Dynamic Island–style notification pill: the notification's image or app
// icon in a rounded tile, with the title and one line of body beside it.
// Styled like an iOS banner: the title with the time beside it, and the body
// below. A notification with buttons (Open, Edit…) grows a row of them under
// that, and one in an app's stack says how many there are.
IslandPill {
  id: pill
  // The island rectangle; the app tile sizes itself from its height.
  required property Item shape
  readonly property var row: host.notifications.last || ({})
  property bool imageFailed: false
  onRowChanged: imageFailed = false
  readonly property string iconSource: host.notifications.iconSource(host.notifications.last, imageFailed)
  readonly property var brand: host.notifications.brand(row)
  readonly property var actions: row.actions || []
  // Room under the text for the buttons.
  readonly property real actionsExtra: actions.length > 0 ? 42 : 0
  shown: host.notificationPill
  pillWidth: 440
  pillHeight: 84 + actionsExtra
  // The island's own banners act on a click (see Island.qml's showBanner);
  // any other notification takes you to where it came from (and is dismissed).
  function clicked(mouse) {
    if (row.islandUpdate) host.updateIsland()
    else if (row.islandSetupRetry) { host.dismissFeedback(); host.setup.install() }
    else { host.dismissFeedback(); host.notifications.open(row, true) }
  }

  PillReveal { id: reveal; theme: host.theme; shown: pill.shown }

  ClippingRectangle {
    id: appTile
    opacity: reveal.leadingIn
    PillPart { target: appTile; progress: reveal.leadingIn }
    anchors.left: parent.left
    anchors.leftMargin: 15
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -pill.actionsExtra / 2
    // Grows with the pill so it never pokes past the rounded ends.
    width: height
    height: Math.max(0, Math.min(54, shape.height - 30))
    radius: height * 0.28
    color: "transparent"
    Rectangle {
      anchors.fill: parent
      visible: appTileImage.status !== Image.Ready
      gradient: Gradient {
        GradientStop { position: 0; color: pill.brand ? Qt.lighter(pill.brand.tile, 1.12) : Qt.lighter(host.theme.accent, 1.25) }
        GradientStop { position: 1; color: pill.brand ? pill.brand.tile : host.theme.accent }
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
      text: pill.brand ? pill.brand.glyph : String(pill.row.glyph || "") || "󰂚"
      color: pill.brand ? pill.brand.ink : host.theme.accentText
      font.family: pill.brand ? "JetBrainsMono Nerd Font" : host.theme.fontFamily
      font.pixelSize: pill.brand ? Math.round(parent.height * 0.6) : pill.host.theme.px(24)
    }
  }

  // How many of the app's notifications are waiting, on the tile's corner.
  Rectangle {
    opacity: reveal.leadingIn
    visible: pill.row.stack > 1 && host.settings.stackNotifications
    x: appTile.x + appTile.width - width * 0.6
    y: appTile.y - height * 0.4
    width: Math.max(height, stackCount.implicitWidth + 10)
    height: 20
    radius: height / 2
    color: host.theme.accent
    border.width: 2
    border.color: host.theme.background
    Text {
      id: stackCount
      anchors.centerIn: parent
      text: String(pill.row.stack || 0)
      color: host.theme.accentText
      font.family: host.theme.textFontFamily
      font.pixelSize: host.theme.px(11)
      font.weight: Font.Bold
    }
  }

  Column {
    opacity: reveal.middleIn
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
    anchors.left: appTile.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 30
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -pill.actionsExtra / 2
    spacing: 2
    Item {
      width: parent.width
      height: title.height
      Text {
        id: title
        anchors.left: parent.left
        anchors.right: age.left
        anchors.rightMargin: 8
        text: host.notifications.title(pill.row)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        // iOS's type: a semibold title and a regular body of nearly the same
        // size, in SF's stand-in (Adwaita Sans).
        color: "#ffffff"
        font.family: host.theme.textFontFamily
        font.pixelSize: host.theme.px(15)
        font.weight: Font.DemiBold
        font.letterSpacing: -0.2
      }
      Text {
        id: age
        anchors.right: parent.right
        anchors.baseline: title.baseline
        text: host.notifications.age(pill.row.timestamp)
        textFormat: Text.PlainText
        color: Qt.rgba(1, 1, 1, 0.45)
        font.family: host.theme.textFontFamily
        font.letterSpacing: host.theme.tracking(host.theme.textFontFamily, host.theme.px(13))
        font.pixelSize: host.theme.px(13)
      }
    }
    Text {
      width: parent.width
      text: String(pill.row.body || pill.row.app || "")
      visible: text !== ""
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Qt.rgba(1, 1, 1, 0.72)
      font.family: host.theme.textFontFamily
      font.pixelSize: host.theme.px(13)
      font.letterSpacing: -0.1
    }
  }

  // The buttons the sender (or Omarchy, for a code) offers, pressed through
  // the companion; pressing one ends the notification.
  Row {
    opacity: reveal.middleIn
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
    anchors.left: parent.left
    anchors.leftMargin: 15
    anchors.right: parent.right
    anchors.rightMargin: 15
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 15
    visible: pill.actions.length > 0
    spacing: 8
    Repeater {
      model: pill.actions.slice(0, 3)
      delegate: Rectangle {
        required property var modelData
        required property int index
        width: (parent.width - (pill.actions.slice(0, 3).length - 1) * parent.spacing) / pill.actions.slice(0, 3).length
        height: 28
        radius: height / 2
        color: Qt.rgba(1, 1, 1, actionMouse.pressed ? 0.28 : actionMouse.containsMouse ? 0.22 : 0.14)
        Behavior on color { MotionColorAnimation { theme: pill.host.theme } }
        Text {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: String(modelData.label || "")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: "#ffffff"
          font.family: host.theme.textFontFamily
          font.pixelSize: host.theme.px(13)
          font.weight: Font.DemiBold
        }
        MouseArea {
          id: actionMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            host.notifications.runAction(pill.row, index)
            host.dismissFeedback()
          }
        }
      }
    }
  }
}
