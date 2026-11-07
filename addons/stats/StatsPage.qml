pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../components"

// The System Stats pane: the cards (StatsCards) for the CPU, memory, GPU and
// storage, then the processes. In a control center zone (`inZone`, see
// Addon.qml) the cards are stacked one to a row and the table, too tall for a
// column, is left out.
ColumnLayout {
  id: page
  required property var view
  required property var stats
  property bool shown: false
  property bool inZone: false
  spacing: 20

  // Until the first reading, the cards show their spinner; then the processes.
  StatsCards {
    id: cards
    Layout.fillWidth: true
    view: page.view
    stats: page.stats
    shown: page.shown
    stacked: page.inZone
  }

  // Processes, in a box like the others: its title and search above, then
  // the table, each of your rows with its own ⓧ to quit it ----------------
  Section {
    Layout.fillWidth: true
    visible: cards.ready && !page.inZone
    opacity: cards.ready ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: page.view.host.theme; pace: "fade"; curve: "fade" } }
    view: page.view
    title: "Processes"
    count: cards.ready ? String(table.total) : ""
    accessory: [
      // Search, filtering as you type; inset as the Settings text fields,
      // with their focus ring.
      Rectangle {
        width: 170
        height: 28
        radius: 8
        color: page.view.host.theme.solid("quiet")
        border.width: 1
        border.color: page.view.host.theme.fill(filter.activeFocus ? "strong" : "raised")
        Rectangle {
          anchors.centerIn: parent
          width: parent.width + 6
          height: parent.height + 6
          radius: parent.radius + 3
          color: "transparent"
          border.width: 3
          border.color: page.view.host.theme.accentFill("ring")
          opacity: filter.activeFocus ? 1 : 0
          scale: filter.activeFocus ? 1 : 1.12
          Behavior on opacity { MotionAnimation { theme: page.view.host.theme; pace: "fade"; curve: "fade" } }
          Behavior on scale { MotionAnimation { theme: page.view.host.theme; pace: "standard" } }
        }
        Text {
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          text: "󰍉"
          color: page.view.textMuted
          font.family: page.view.host.theme.fontFamily
          font.pixelSize: page.view.host.theme.px(13)
        }
        Text {
          x: 26
          anchors.verticalCenter: parent.verticalCenter
          visible: filter.text === ""
          text: "Filter processes"
          color: page.view.textMuted
          font.family: page.view.host.theme.textFontFamily
          font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.host.theme.px(13))
          font.features: { "tnum": 1 }
          font.pixelSize: page.view.host.theme.px(13)
        }
        TextInput {
          id: filter
          selectionColor: page.view.accent
          selectedTextColor: page.view.accentInk
          x: 26
          width: parent.width - 34
          anchors.verticalCenter: parent.verticalCenter
          clip: true
          color: page.view.text
          font.family: page.view.host.theme.textFontFamily
          font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.host.theme.px(13))
          font.features: { "tnum": 1 }
          font.pixelSize: page.view.host.theme.px(13)
          Keys.onEscapePressed: function(event) {
            if (text !== "") { text = ""; event.accepted = true }
            else event.accepted = false
          }
        }
      }
    ]
    Card {
      view: page.view
      flat: true
      Layout.fillWidth: true
      implicitHeight: processBody.implicitHeight + 16

      ColumnLayout {
        id: processBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        spacing: 10

        ProcessTable {
          id: table
          Layout.fillWidth: true
          Layout.preferredHeight: implicitHeight
          view: page.view
          stats: page.stats
          format: cards
          query: filter.text
          onQuitRequested: function(row) { sheet.ask(row) }
        }
      }
    }
  }

  QuitSheet {
    id: sheet
    parent: page.view
    view: page.view
    onQuit: function(row, force) { page.stats.quit(row, force) }
  }
}
