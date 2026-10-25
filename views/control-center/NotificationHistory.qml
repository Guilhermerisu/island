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
  // Off for the first layout each time the control center opens (as the
  // grid's cardsSettled), so only changes made while it's showing animate.
  property bool settled: false
  Connections {
    target: history.center
    function onActiveChanged() {
      history.settled = false
      if (history.center.active) historySettleTimer.restart()
    }
  }
  Timer {
    id: historySettleTimer
    interval: history.center.host.theme.motionDuration("morph")
    onTriggered: history.settled = history.center.active
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 2
    Text {
      text: "Notifications"
      color: history.center.text
      font.family: history.center.host.theme.textFontFamily
      font.pixelSize: history.center.host.theme.px(13)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.1
    }
    Item { Layout.fillWidth: true }
    // macOS's round ×, widening into "Clear All" while hovered.
    Rectangle {
      scale: clearMouse.pressed ? 0.94 : 1
      Behavior on scale { MotionAnimation { theme: history.center.host.theme; pace: clearMouse.pressed ? "press" : "standard" } }
      // Goes with the banners it clears.
      opacity: history.empty ? 0 : 1
      visible: opacity > 0.01
      Behavior on opacity {
        enabled: history.settled
        MotionAnimation { theme: history.center.host.theme; pace: history.empty ? "exit" : "fade"; curve: history.empty ? "exit" : "fade" }
      }
      implicitWidth: clearMouse.containsMouse ? clearLabel.implicitWidth + 20 : 22
      implicitHeight: 22
      radius: height / 2
      clip: true
      color: clearMouse.containsMouse ? history.center.wellHover : history.center.card
      border.width: 1
      border.color: history.center.edge
      Behavior on color { MotionColorAnimation { theme: history.center.host.theme } }
      Behavior on implicitWidth { MotionAnimation { theme: history.center.host.theme; pace: "quick" } }
      Text {
        anchors.centerIn: parent
        opacity: clearMouse.containsMouse ? 0 : 1
        text: "󰅖"
        color: history.center.textMuted
        font.family: history.center.iconFont
        font.pixelSize: history.center.host.theme.px(12)
        Behavior on opacity { MotionAnimation { theme: history.center.host.theme; pace: "fade"; curve: "fade" } }
      }
      Text {
        id: clearLabel
        anchors.centerIn: parent
        opacity: clearMouse.containsMouse ? 1 : 0
        text: "Clear All"
        color: history.center.text
        font.family: history.center.host.theme.textFontFamily
        font.letterSpacing: history.center.host.theme.tracking(history.center.host.theme.textFontFamily, history.center.host.theme.px(11))
        font.pixelSize: history.center.host.theme.px(11)
        font.weight: Font.Medium
        Behavior on opacity { MotionAnimation { theme: history.center.host.theme; pace: "fade"; curve: "fade" } }
      }
      MouseArea {
        id: clearMouse
        anchors.fill: parent
        enabled: !history.empty
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: history.center.host.notifications.clearAll()
      }
    }
  }

  // Fades in as the last banners go out; it isn't in the way of new ones.
  Text {
    visible: history.empty
    opacity: history.empty ? 1 : 0
    Behavior on opacity { enabled: history.settled; MotionAnimation { theme: history.center.host.theme; pace: "fade"; curve: "fade" } }
    Layout.fillWidth: true
    Layout.topMargin: 10
    Layout.bottomMargin: 12
    horizontalAlignment: Text.AlignHCenter
    text: "No Notifications"
    color: history.center.textMuted
    font.family: history.center.host.theme.textFontFamily
    font.letterSpacing: history.center.host.theme.tracking(history.center.host.theme.textFontFamily, history.center.host.theme.px(13))
    font.pixelSize: history.center.host.theme.px(13)
  }

  ListView {
    id: notes
    OverlayScrollbar { flickable: notes; parent: notes; theme: history.center.host.theme }
    // Clear All (or dismissing the last banner) lets the rows fade out and
    // the frame close before the list goes, rather than dropping it at once.
    opacity: history.empty ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity {
      enabled: history.settled
      MotionAnimation { theme: history.center.host.theme; pace: history.empty ? "exit" : "fade"; curve: history.empty ? "exit" : "fade" }
    }
    Layout.fillWidth: true
    // Out by the × button's overhang, so the banners line up with the cards.
    Layout.leftMargin: -6
    // Grows and shrinks with the rows as they come and go, instead of
    // jumping to the new content height while they're still animating.
    property real frameHeight: history.empty ? 0 : Math.min(contentHeight, 320)
    Behavior on frameHeight { enabled: history.settled; MotionAnimation { theme: history.center.host.theme; pace: "standard" } }
    Layout.preferredHeight: frameHeight
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    // Kept by key, so dismissing one slides the rest up instead of
    // rebuilding every banner.
    model: noteRows.model
    KeyedListModel {
      id: noteRows
      values: history.center.host.notifications.history
      keyOf: function(row) { return history.center.host.notifications.key(row) }
    }
    // A banner fades in where it lands and out where it was, and the rest
    // slide over; the first fill (and anything while hidden) just appears.
    add: Transition {
      enabled: noteRows.primed && history.center.active
      MotionAnimation { theme: history.center.host.theme; property: "opacity"; from: 0; to: 1; pace: "fade"; curve: "fade" }
      MotionAnimation { theme: history.center.host.theme; property: "scale"; from: 0.96; to: 1; pace: "standard" }
    }
    remove: Transition {
      enabled: history.center.active
      MotionAnimation { theme: history.center.host.theme; property: "opacity"; to: 0; pace: "exit"; curve: "exit" }
      MotionAnimation { theme: history.center.host.theme; property: "scale"; to: 0.96; pace: "exit"; curve: "exit" }
    }
    // Also settles opacity and scale, in case a banner was still fading in.
    displaced: Transition {
      MotionAnimation { theme: history.center.host.theme; property: "y"; pace: "standard" }
      MotionAnimation { theme: history.center.host.theme; properties: "opacity,scale"; to: 1; pace: "fade"; curve: "fade" }
    }
    // Soft edges where the list runs on above or below, as in Settings.
    Repeater {
      model: [
        { top: true, shown: notes.contentY - notes.originY > 1 },
        { top: false, shown: notes.contentY - notes.originY < notes.contentHeight - notes.height - 1 }
      ]
      delegate: Rectangle {
        required property var modelData
        parent: notes
        z: 1
        anchors.left: parent.left
        anchors.right: parent.right
        y: modelData.top ? 0 : notes.height - height
        height: 24
        opacity: modelData.shown ? 1 : 0
        Behavior on opacity { MotionAnimation { theme: history.center.host.theme; pace: "fade"; curve: "fade" } }
        gradient: Gradient {
          GradientStop { position: 0; color: modelData.top ? history.center.host.theme.background : "transparent" }
          GradientStop { position: 1; color: modelData.top ? "transparent" : history.center.host.theme.background }
        }
      }
    }
    // Inset by the × button's overhang, which sits on the banner's corner.
    delegate: Item {
      id: note
      required property var entry
      readonly property var modelData: entry
      readonly property bool hovered: noteMouse.containsMouse || closeMouse.containsMouse
      width: ListView.view.width
      height: banner.height + 6
      Rectangle {
        id: banner
        scale: noteMouse.pressed ? 0.98 : 1
        Behavior on scale { MotionAnimation { theme: history.center.host.theme; pace: noteMouse.pressed ? "press" : "standard" } }
        x: 6
        y: 6
        width: parent.width - 6
        height: Math.max(noteBody.implicitHeight, 36) + 24
        radius: history.center.host.theme.radii.card
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
        // The notification's image or app icon; the banner's accent bell
        // tile when there's none (or it fails to load).
        ClippingRectangle {
          id: avatar
          // A live image handle dies with the shell; fall back to the app
          // icon (then the bell) when it no longer loads.
          property bool imageFailed: false
          readonly property string source: history.center.host.notifications.iconSource(note.modelData, imageFailed)
          readonly property var brand: history.center.host.notifications.brand(note.modelData)
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          width: 36; height: 36; radius: history.center.host.theme.radii.large
          readonly property bool generic: !brand && noteIcon.status !== Image.Ready
          color: brand ? brand.tile : "transparent"
          // Same tile as the banner (NotificationPill), so a notification
          // looks the same on the pill and here.
          Rectangle {
            anchors.fill: parent
            visible: avatar.generic
            gradient: Gradient {
              GradientStop { position: 0; color: Qt.lighter(history.center.host.theme.accent, 1.25) }
              GradientStop { position: 1; color: history.center.host.theme.accent }
            }
          }
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
            text: avatar.brand ? avatar.brand.glyph : "󰂚"
            color: avatar.brand ? avatar.brand.ink : history.center.host.theme.accentText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: history.center.host.theme.px(20)
          }
        }
        Column {
          id: noteBody
          anchors.left: avatar.right
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 1
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
              font.letterSpacing: -0.1
            }
            Text {
              id: noteAge
              anchors.right: parent.right
              anchors.baseline: noteTitle.baseline
              text: history.center.host.notifications.age(note.modelData.timestamp)
              textFormat: Text.PlainText
              color: history.center.textMuted
              font.family: history.center.host.theme.textFontFamily
              font.letterSpacing: history.center.host.theme.tracking(history.center.host.theme.textFontFamily, history.center.host.theme.px(11))
              font.pixelSize: history.center.host.theme.px(11)
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
            font.letterSpacing: history.center.host.theme.tracking(history.center.host.theme.textFontFamily, history.center.host.theme.px(12))
            font.pixelSize: history.center.host.theme.px(12)
          }
        }
      }
      // macOS's × on the banner's corner, while the banner is hovered.
      Rectangle {
        scale: closeMouse.pressed ? 0.9 : 1
        Behavior on scale { MotionAnimation { theme: history.center.host.theme; pace: closeMouse.pressed ? "press" : "standard" } }
        width: 20; height: 20; radius: 10
        opacity: note.hovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { MotionAnimation { theme: history.center.host.theme; pace: "fade"; curve: "fade" } }
        color: closeMouse.containsMouse ? history.center.wellHover : history.center.well
        border.width: 1
        border.color: history.center.host.theme.fill("raised")
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
