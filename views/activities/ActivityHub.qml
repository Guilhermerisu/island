import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../components"

ColumnLayout {
  id: hub
  required property var host
  required property bool active
  required property bool shown
  readonly property var live: host.liveActivities
  readonly property var theme: host.theme
  property bool showHidden: false
  property double now: Date.now()
  spacing: 6
  opacity: shown ? 1 : 0
  visible: shown || opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: hub.theme; pace: hub.shown ? "fade" : "exit"; curve: "fade" } }

  onActiveChanged: if (!active) showHidden = false
  Connections {
    target: hub.live
    function onHiddenEntriesChanged() { if (!hub.live.hiddenEntries.length) hub.showHidden = false }
  }
  Timer {
    running: hub.active && hub.host.agentSessions.length > 0
    repeat: true
    triggeredOnStart: true
    interval: 1000
    onTriggered: hub.now = Date.now()
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: 4
    spacing: 5
    Text {
      Layout.fillWidth: true
      Layout.leftMargin: 8
      text: "Activities"
      color: hub.theme.secondary
      font.family: hub.theme.textFontFamily
      font.pixelSize: hub.theme.size.callout
      font.weight: Font.DemiBold
    }
    Rectangle {
      Layout.rightMargin: 4
      visible: hub.live.hiddenEntries.length > 0
      implicitHeight: 26
      implicitWidth: filterLabel.implicitWidth + 16
      radius: height / 2
      color: filterTap.pressed || hub.showHidden ? hub.theme.fill("stronger") : hub.theme.fill("quiet")
      Text {
        id: filterLabel
        anchors.centerIn: parent
        text: hub.showHidden ? "Visible"
          : "Hidden" + " · " + hub.live.hiddenEntries.length
        color: hub.theme.accent
        font.family: hub.theme.textFontFamily
        font.pixelSize: hub.theme.size.footnote
        font.weight: Font.DemiBold
      }
      HoverHandler { cursorShape: Qt.PointingHandCursor }
      TapHandler { id: filterTap; onTapped: hub.showHidden = !hub.showHidden }
      Accessible.role: Accessible.Button
      Accessible.name: filterLabel.text
      Accessible.onPressAction: hub.showHidden = !hub.showHidden
    }
  }

  KeyedListModel {
    id: activityRows
    values: (hub.showHidden ? hub.live.hiddenEntries : hub.live.visibleEntries).map(function(row) { return row.key })
  }

  ListView {
    id: list
    Layout.fillWidth: true
    Layout.preferredHeight: rowSpace
    property real rowSpace: count ? count * 52 + (count - 1) * spacing : 0
    Behavior on rowSpace { enabled: hub.active; MotionAnimation { theme: hub.theme; pace: "morph" } }
    spacing: 6
    interactive: false
    clip: true
    model: activityRows.model
    add: Transition {
      MotionAnimation { property: "opacity"; from: 0; to: 1; theme: hub.theme; pace: "fade"; curve: "fade" }
      MotionAnimation { property: "scale"; from: 0.96; to: 1; theme: hub.theme; pace: "quick" }
    }
    remove: Transition {
      MotionAnimation { property: "opacity"; to: 0; theme: hub.theme; pace: "exit"; curve: "fade" }
      MotionAnimation { property: "scale"; to: 0.97; theme: hub.theme; pace: "exit" }
    }
    displaced: Transition {
      MotionAnimation { property: "y"; theme: hub.theme; pace: "morph" }
    }
    delegate: Rectangle {
      id: card
      required property string entry
      readonly property var latest: hub.live.byKey[entry]
      property var saved: null
      onLatestChanged: if (latest) saved = latest
      Component.onCompleted: if (latest) saved = latest
      readonly property var activity: latest || saved || ({ key: entry, label: "", tint: "transparent" })
      readonly property bool canOpen: !!activity.open && (!hub.showHidden || activity.kind === "agent")
      width: list.width
      height: 52
      radius: 16
      color: rowTap.pressed ? hub.theme.fill("stronger") : hub.theme.fill("strong")

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        spacing: 8
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          HoverHandler { enabled: card.canOpen; cursorShape: Qt.PointingHandCursor }
          TapHandler { id: rowTap; enabled: card.canOpen; onTapped: card.activity.open() }
          Accessible.role: card.canOpen ? Accessible.Button : Accessible.StaticText
          Accessible.name: card.activity.label
          Accessible.onPressAction: if (card.canOpen) card.activity.open()

          RowLayout {
            anchors.fill: parent
            spacing: 9
            ClippingRectangle {
              Layout.preferredWidth: 33
              Layout.preferredHeight: 33
              radius: 10
              color: hub.theme.withAlpha(card.activity.tint, 0.18)
              Text {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: card.activity.glyph
                color: card.activity.tint
                font.family: hub.theme.fontFamily
                font.pixelSize: hub.theme.px(18)
              }
              Image {
                id: cover
                anchors.fill: parent
                source: card.activity.art || ""
                sourceSize.width: 66
                sourceSize.height: 66
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
              }
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1
              Text {
                Layout.fillWidth: true
                text: card.activity.label
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: hub.theme.text
                font.family: hub.theme.textFontFamily
                font.pixelSize: hub.theme.size.callout
                font.weight: Font.DemiBold
              }
              Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.activity.detail || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: hub.theme.secondary
                font.family: hub.theme.textFontFamily
                font.pixelSize: hub.theme.size.footnote
              }
            }
            Text {
              Layout.maximumWidth: card.width / 4
              visible: text !== ""
              text: card.activity.tail ? card.activity.tail(hub.now) : ""
              elide: Text.ElideRight
              color: card.activity.tint
              font.family: hub.theme.textFontFamily
              font.pixelSize: hub.theme.size.footnote
              font.features: { "tnum": 1 }
            }
          }
        }
        Rectangle {
          id: hideButton
          Layout.preferredWidth: 29
          Layout.preferredHeight: 29
          radius: height / 2
          color: hideHover.hovered || hideTap.pressed ? hub.theme.fill("stronger") : hub.theme.fill("quiet")
          readonly property string label: hub.showHidden ? "Restore" : "Hide"
          Text {
            anchors.centerIn: parent
            text: hub.showHidden ? "󰑎" : "󰅖"
            color: hub.showHidden ? hub.theme.accent : hub.theme.secondary
            font.family: hub.theme.fontFamily
            font.pixelSize: hub.theme.px(15)
          }
          HoverHandler { id: hideHover; cursorShape: Qt.PointingHandCursor }
          Tooltip { theme: hub.theme; text: hideButton.label }
          TapHandler {
            id: hideTap
            onTapped: hub.live.setHidden(card.activity.key, !hub.showHidden)
          }
          Accessible.role: Accessible.Button
          Accessible.name: label + " " + card.activity.label
          Accessible.onPressAction: hub.live.setHidden(card.activity.key, !hub.showHidden)
        }
      }
    }
  }
}
