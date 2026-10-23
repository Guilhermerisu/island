import QtQuick
import Quickshell.Widgets

// Dynamic Island–style notification pill: the notification's image or app
// icon in a rounded tile, with the title and one line of body beside it.
// Styled like an iOS banner: the title with the time beside it, and the body
// below.
IslandPill {
  id: pill
  // The island rectangle; the app tile sizes itself from its height.
  required property Item shape
  readonly property var row: host.notifications.last || ({})
  property bool imageFailed: false
  onRowChanged: imageFailed = false
  readonly property string iconSource: host.notifications.iconSource(host.notifications.last, imageFailed)
  readonly property var brand: host.notifications.brand(row)
  shown: host.notificationPill
  pillWidth: 440
  pillHeight: 84
  // The island's own banners act on a click (see Island.qml's showBanner);
  // any other notification is dismissed.
  function clicked(mouse) {
    if (row.islandUpdate) host.updateIsland()
    else if (row.islandSetupRetry) { host.dismissFeedback(); host.setup.install() }
    else host.dismissPillNotification()
  }

  PillReveal { id: reveal; theme: host.theme; shown: pill.shown }

  ClippingRectangle {
    id: appTile
    opacity: reveal.leadingIn
    PillPart { target: appTile; progress: reveal.leadingIn }
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

  Column {
    opacity: reveal.middleIn
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
    anchors.left: appTile.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 30
    anchors.verticalCenter: parent.verticalCenter
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
}
