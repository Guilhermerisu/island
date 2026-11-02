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
  // Compact: one line, as tall as the resting pill (Settings → Notifications).
  readonly property bool compact: host.settings.notificationStyle === "compact"
  // Expanded: everything the notification has, its buttons, and the
  // island's own (snooze, silence the app, dismiss). Compact banners expand
  // while hovered, and a hovered banner doesn't time out.
  readonly property bool expanded: !compact || (bannerHover.hovered && shown)
  HoverHandler { id: bannerHover; onHoveredChanged: if (pill.shown) pill.host.holdFeedback(hovered) }
  pillWidth: expanded ? 440 : 400
  pillHeight: expanded ? Math.max(84, full.implicitHeight + 28) : host.pillHeight
  function escaped(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }
  // The island's own banners act on a click (see Island.qml's showBanner);
  // any other notification opens its app.
  function clicked(mouse) {
    if (row.islandUpdate) host.updateIsland()
    else if (row.islandSetupRetry) { host.dismissFeedback(); host.setup.install() }
    // Anything else runs the sender's default action, or focuses its window.
    else if (row.timestamp !== undefined) { host.dismissFeedback(); host.notifications.command("invokeKey", row) }
    else host.dismissPillNotification()
  }

  PillReveal { id: reveal; theme: host.theme; shown: pill.shown }

  // The image or app icon: round beside a compact banner, a rounded square
  // at the head of an expanded one (see AppTile).
  AppTile {
    id: appTile
    visible: !pill.expanded
    opacity: reveal.leadingIn
    PillPart { target: appTile; progress: reveal.leadingIn }
    anchors.left: parent.left
    anchors.leftMargin: 7
    anchors.verticalCenter: parent.verticalCenter
    width: height
    height: Math.max(0, Math.min(32, shape.height - 12))
    radius: height / 2
  }

  Column {
    visible: !pill.expanded
    opacity: reveal.middleIn
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
    anchors.left: appTile.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: pill.compact ? 18 : 30
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
        // Compact puts the body on the title's line, dimmer.
        text: pill.compact
          ? "<b>" + pill.escaped(host.notifications.title(pill.row)) + "</b>&nbsp;&nbsp;<font color=\"#b8ffffff\">"
            + pill.escaped(pill.row.body || pill.row.app || "") + "</font>"
          : host.notifications.title(pill.row)
        textFormat: pill.compact ? Text.StyledText : Text.PlainText
        elide: Text.ElideRight
        // iOS's type: a semibold title and a regular body of nearly the same
        // size, in SF's stand-in (Adwaita Sans).
        color: "#ffffff"
        font.family: host.theme.textFontFamily
        font.pixelSize: host.theme.px(pill.compact ? 13 : 15)
        font.weight: pill.compact ? Font.Normal : Font.DemiBold
        font.letterSpacing: -0.2
      }
      Text {
        id: age
        anchors.right: parent.right
        anchors.baseline: title.baseline
        text: host.notificationRun > 1 ? host.notificationRun + " new" : host.notifications.age(pill.row.timestamp)
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
      visible: text !== "" && !pill.compact
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Qt.rgba(1, 1, 1, 0.72)
      font.family: host.theme.textFontFamily
      font.pixelSize: host.theme.px(13)
      font.letterSpacing: -0.1
    }
  }

  // ---------- Expanded ----------

  Column {
    id: full
    visible: pill.expanded
    opacity: reveal.middleIn
    x: 16
    y: 14
    width: pill.width - 32
    spacing: 10
    Row {
      width: parent.width
      spacing: 12
      AppTile { width: 40; height: 40; radius: 11 }
      Column {
        width: parent.width - 52
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Item {
          width: parent.width
          height: fullTitle.height
          Text {
            id: fullTitle
            anchors.left: parent.left
            anchors.right: fullAge.left
            anchors.rightMargin: 8
            text: host.notifications.title(pill.row)
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: "#ffffff"
            font.family: host.theme.textFontFamily
            font.pixelSize: host.theme.px(15)
            font.weight: Font.DemiBold
          }
          Text {
            id: fullAge
            anchors.right: parent.right
            anchors.baseline: fullTitle.baseline
            text: host.notificationRun > 1 ? host.notificationRun + " new" : host.notifications.age(pill.row.timestamp)
            color: Qt.rgba(1, 1, 1, 0.45)
            font.family: host.theme.textFontFamily
            font.pixelSize: host.theme.px(12)
          }
        }
        Text {
          width: parent.width
          text: String(pill.row.app || "") + (pill.row.snoozed ? " · snoozed" : "")
          visible: text !== ""
          elide: Text.ElideRight
          color: Qt.rgba(1, 1, 1, 0.45)
          font.family: host.theme.textFontFamily
          font.pixelSize: host.theme.px(12)
        }
      }
    }
    Text {
      width: parent.width
      text: String(pill.row.body || "")
      visible: text !== ""
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      maximumLineCount: 8
      elide: Text.ElideRight
      color: Qt.rgba(1, 1, 1, 0.8)
      font.family: host.theme.textFontFamily
      font.pixelSize: host.theme.px(13)
      lineHeight: 1.1
    }
    Flow {
      width: parent.width
      spacing: 6
      visible: pill.row.timestamp !== undefined
      // The sender's buttons, while it can still hear them.
      Repeater {
        model: pill.row.snoozed ? [] : (pill.row.actions || [])
        delegate: BannerButton {
          required property var modelData
          label: modelData.text
          accent: true
          onActivated: { pill.host.dismissFeedback(); pill.host.notifications.invokeAction(pill.row, modelData.id) }
        }
      }
      BannerButton { label: "Snooze 10 min"; onActivated: pill.host.snoozeNotification(pill.row, 10) }
      BannerButton { label: "Snooze 1 h"; onActivated: pill.host.snoozeNotification(pill.row, 60) }
      BannerButton {
        visible: !!pill.row.app
        label: "Silence " + String(pill.row.app || "")
        onActivated: pill.host.silenceApp(pill.row)
      }
      BannerButton { label: "Dismiss"; onActivated: pill.host.dismissPillNotification() }
    }
  }

  component BannerButton: Rectangle {
    id: button
    property string label: ""
    property bool accent: false
    signal activated()
    height: 28
    width: Math.min(full.width, buttonText.implicitWidth + 22)
    radius: 14
    color: accent ? (buttonMouse.containsMouse ? Qt.lighter(pill.host.theme.accent, 1.1) : pill.host.theme.accent)
      : (buttonMouse.containsMouse ? pill.host.theme.fill("strong") : pill.host.theme.fill("raised"))
    Text {
      id: buttonText
      anchors.centerIn: parent
      width: Math.min(implicitWidth, button.width - 22)
      text: button.label
      elide: Text.ElideRight
      color: button.accent ? pill.host.theme.accentText : "#ffffff"
      font.family: pill.host.theme.textFontFamily
      font.pixelSize: pill.host.theme.px(12)
      font.weight: Font.Medium
    }
    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.activated()
    }
  }

  component AppTile: ClippingRectangle {
    color: "transparent"
    Rectangle {
      anchors.fill: parent
      visible: appTileImage.status !== Image.Ready
      gradient: Gradient {
        GradientStop { position: 0; color: pill.brand ? Qt.lighter(pill.brand.tile, 1.12) : Qt.lighter(pill.host.theme.accent, 1.25) }
        GradientStop { position: 1; color: pill.brand ? pill.brand.tile : pill.host.theme.accent }
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
      color: pill.brand ? pill.brand.ink : pill.host.theme.accentText
      font.family: pill.brand ? "JetBrainsMono Nerd Font" : pill.host.theme.fontFamily
      font.pixelSize: pill.brand ? Math.round(parent.height * 0.6) : pill.host.theme.px(24)
    }
  }
}
