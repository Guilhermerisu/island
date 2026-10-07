import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../components"

// The control center's Notifications card: the newest ten, Clear All, and
// dismissing one. `center` is the ControlCenter.
Rectangle {
  id: history
  required property var center
  visible: !history.center.editMode
  Layout.fillWidth: true
  Layout.preferredHeight: notificationBody.implicitHeight + 20
  radius: 16
  color: history.center.card
  border.width: 1
  border.color: history.center.edge

  ColumnLayout {
    id: notificationBody
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 10
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4
      Layout.rightMargin: 4
      Layout.topMargin: 2
      Text {
        text: "Notifications"
        color: history.center.text
        font.family: history.center.host.theme.textFontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
        font.letterSpacing: -0.2
      }
      Item { Layout.fillWidth: true }
      // macOS push button.
      Rectangle {
        visible: history.center.host.notifications.history.length > 0
        implicitWidth: clearLabel.implicitWidth + 20
        implicitHeight: 22
        radius: 6
        color: clearMouse.containsMouse ? history.center.wellHover : history.center.well
        Behavior on color { MotionColorAnimation { theme: history.center.host.theme } }
        Text {
          id: clearLabel
          anchors.centerIn: parent
          text: "Clear All"
          color: history.center.text
          font.family: history.center.host.theme.textFontFamily
          font.pixelSize: 12
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
      visible: history.center.host.notifications.history.length === 0
      Layout.fillWidth: true
      Layout.topMargin: 4
      Layout.bottomMargin: 8
      horizontalAlignment: Text.AlignHCenter
      text: "No notifications"
      color: history.center.textMuted
      font.family: history.center.host.theme.textFontFamily
      font.pixelSize: 12
    }

    ListView {
      visible: history.center.host.notifications.history.length > 0
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(contentHeight, 240)
      clip: true
      spacing: 8
      boundsBehavior: Flickable.StopAtBounds
      model: history.center.host.notifications.history
      delegate: Rectangle {
        id: note
        required property var modelData
        readonly property string appName: String(modelData.app || modelData.summary || "?")
        width: ListView.view.width
        height: noteBody.implicitHeight + 22
        radius: 14
        color: noteMouse.containsMouse && modelData.isActive ? history.center.wellHover : history.center.tile

        MouseArea {
          id: noteMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: !!note.modelData.isActive
          onClicked: history.center.host.notifications.command("invokeKey", note.modelData)
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
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          width: 32; height: 32; radius: 8
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
            font.pixelSize: avatar.brand ? 20 : 14
            font.weight: Font.DemiBold
          }
        }
        Column {
          id: noteBody
          anchors.left: avatar.right
          anchors.leftMargin: 12
          anchors.right: parent.right
          anchors.rightMargin: 32
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 2
          // Like iOS's Notification Center: the title with the time on the
          // same line (the icon already says which app).
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
              font.pixelSize: 14
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
              font.pixelSize: 12
            }
          }
          Text {
            width: parent.width
            text: String(note.modelData.body || "")
            visible: text !== ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: history.center.host.theme.withAlpha(history.center.text, 0.72)
            font.family: history.center.host.theme.textFontFamily
            font.pixelSize: 13
          }
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: 13
          anchors.top: parent.top
          anchors.topMargin: 12
          text: "󰅖"
          color: closeMouse.containsMouse ? history.center.text : history.center.textMuted
          font.family: history.center.iconFont
          font.pixelSize: 13
          MouseArea { id: closeMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: history.center.host.notifications.dismiss(note.modelData) }
          Tooltip { theme: history.center.host.theme; text: "Dismiss" }
        }
      }
    }
  }
}
