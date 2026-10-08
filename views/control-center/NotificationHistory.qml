import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../components"

// The control center's notifications, as macOS's Notification Center: a
// heading with Clear All over the newest ten as banners, each dismissed by
// the round × on its corner while hovered. `center` is the ControlCenter.
ColumnLayout {
  id: history
  required property var center
  readonly property bool empty: history.center.host.notifications.history.length === 0
  visible: !history.center.editMode
  Layout.fillWidth: true
  Layout.topMargin: 4
  spacing: 6

  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 2
    Text {
      text: "Notifications"
      color: history.center.text
      font.family: history.center.host.theme.textFontFamily
      font.pixelSize: history.center.host.theme.px(15)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
    }
    Item { Layout.fillWidth: true }
    Rectangle {
      visible: !history.empty
      implicitWidth: clearLabel.implicitWidth + 22
      implicitHeight: 24
      radius: height / 2
      color: clearMouse.containsMouse ? history.center.wellHover : history.center.card
      Behavior on color { MotionColorAnimation { theme: history.center.host.theme } }
      Text {
        id: clearLabel
        anchors.centerIn: parent
        text: "Clear All"
        color: history.center.text
        font.family: history.center.host.theme.textFontFamily
        font.pixelSize: history.center.host.theme.px(12)
        font.weight: Font.Medium
      }
      MouseArea {
        id: clearMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: history.center.host.notifications.clearAll()
      }
    }
  }

  Text {
    visible: history.empty
    Layout.fillWidth: true
    Layout.topMargin: 10
    Layout.bottomMargin: 12
    horizontalAlignment: Text.AlignHCenter
    text: "No Notifications"
    color: history.center.textMuted
    font.family: history.center.host.theme.textFontFamily
    font.pixelSize: history.center.host.theme.px(13)
  }

  ListView {
    visible: !history.empty
    Layout.fillWidth: true
    // Out by the × button's overhang, so the banners line up with the cards.
    Layout.leftMargin: -6
    Layout.preferredHeight: Math.min(contentHeight, 320)
    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    model: history.center.host.notifications.history
    // Inset by the × button's overhang, which sits on the banner's corner.
    delegate: Item {
      id: note
      required property var modelData
      readonly property string appName: String(modelData.app || modelData.summary || "?")
      readonly property bool hovered: noteMouse.containsMouse || closeMouse.containsMouse
      width: ListView.view.width
      height: banner.height + 6
      Rectangle {
        id: banner
        x: 6
        y: 6
        width: parent.width - 6
        height: Math.max(noteBody.implicitHeight, 40) + 26
        radius: 20
        color: note.hovered ? history.center.tile : history.center.card
        border.width: 1
        border.color: history.center.edge
        Behavior on color { MotionColorAnimation { theme: history.center.host.theme } }

        MouseArea {
          id: noteMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: note.modelData.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: if (note.modelData.isActive) history.center.host.notifications.command("invokeKey", note.modelData)
        }
        // The notification's image or app icon; a letter avatar when
        // there's none (or it fails to load).
        ClippingRectangle {
          id: avatar
          // A live image handle dies with the shell; fall back to the app
          // icon (then the letter) when it no longer loads.
          property bool imageFailed: false
          readonly property string source: history.center.host.notifications.iconSource(note.modelData, imageFailed)
          readonly property var brand: history.center.host.notifications.brand(note.modelData)
          anchors.left: parent.left
          anchors.leftMargin: 13
          anchors.top: parent.top
          anchors.topMargin: 13
          width: 40; height: 40; radius: 10
          color: brand ? brand.tile
            : noteIcon.status === Image.Ready ? "transparent" : history.center.host.theme.withAlpha(history.center.accent, 0.18)
          Image {
            id: noteIcon
            anchors.fill: parent
            source: avatar.source
            sourceSize.width: 60
            sourceSize.height: 60
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            onStatusChanged: if (status === Image.Error) avatar.imageFailed = true
          }
          Text {
            anchors.centerIn: parent
            visible: noteIcon.status !== Image.Ready
            text: avatar.brand ? avatar.brand.glyph : note.appName.charAt(0).toUpperCase()
            color: avatar.brand ? avatar.brand.ink : history.center.accent
            font.family: avatar.brand ? "JetBrainsMono Nerd Font" : history.center.host.theme.textFontFamily
            font.pixelSize: avatar.brand ? history.center.host.theme.px(22) : history.center.host.theme.px(17)
            font.weight: Font.DemiBold
          }
        }
        Column {
          id: noteBody
          anchors.left: avatar.right
          anchors.leftMargin: 11
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.top: parent.top
          anchors.topMargin: 13
          spacing: 2
          // Like macOS's Notification Center: the title with the time on
          // the same line (the icon already says which app).
          Item {
            width: parent.width
            height: noteTitle.height
            Text {
              id: noteTitle
              anchors.left: parent.left
              anchors.right: noteAge.left
              anchors.rightMargin: 8
              text: history.center.host.notifications.title(note.modelData)
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: history.center.text
              font.family: history.center.host.theme.textFontFamily
              font.pixelSize: history.center.host.theme.px(13)
              font.weight: Font.DemiBold
              font.letterSpacing: -0.2
            }
            Text {
              id: noteAge
              anchors.right: parent.right
              anchors.baseline: noteTitle.baseline
              text: history.center.host.notifications.age(note.modelData.timestamp)
              textFormat: Text.PlainText
              color: history.center.textMuted
              font.family: history.center.host.theme.textFontFamily
              font.pixelSize: history.center.host.theme.px(12)
            }
          }
          Text {
            width: parent.width
            text: String(note.modelData.body || "")
            visible: text !== ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            lineHeight: 1.08
            color: history.center.host.theme.withAlpha(history.center.text, 0.78)
            font.family: history.center.host.theme.textFontFamily
            font.pixelSize: history.center.host.theme.px(13)
          }
        }
      }
      // macOS's × on the banner's corner, while the banner is hovered.
      Rectangle {
        width: 20; height: 20; radius: 10
        opacity: note.hovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { MotionAnimation { theme: history.center.host.theme; pace: "fade"; curve: "fade" } }
        color: closeMouse.containsMouse ? history.center.wellHover : history.center.well
        border.width: 1
        border.color: history.center.host.theme.withAlpha(history.center.text, 0.1)
        Text {
          anchors.centerIn: parent
          text: "󰅖"
          color: history.center.text
          font.family: history.center.iconFont
          font.pixelSize: history.center.host.theme.px(12)
        }
        MouseArea {
          id: closeMouse
          anchors.fill: parent
          anchors.margins: -3
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: history.center.host.notifications.dismiss(note.modelData)
        }
        Tooltip { theme: history.center.host.theme; text: "Dismiss" }
      }
    }
  }
}
