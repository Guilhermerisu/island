import QtQuick

// Shared vertical list view for the island: a search field over a scrolling
// list, with the selected row marked by a soft highlight and an accent bar.
// Keyboard: type to search, ↑/↓ (or Tab, PageUp/PageDown) to move, Enter to
// choose, Esc to close. Clicking a row chooses it.
//
// The owner filters: bind `items` to a list computed from `query`. Rows are
// drawn by `row`, a component whose root declares `property var entry` and
// `property bool selected`.
Item {
  id: picker
  required property var host
  property bool active: false
  property var items: []
  property Component row
  property string placeholder: "Search"
  property string emptyText: "Nothing matches"
  property int rowHeight: 50
  property int visibleRows: 7
  readonly property string query: search.text
  readonly property var selected: items[list.currentIndex] || null
  signal chosen(var entry)

  implicitHeight: search.height + 10 + 1 + 8 + list.height

  onActiveChanged: {
    if (!active) return
    search.clear()
    reset()
    Qt.callLater(function() { search.focusInput() })
  }
  onQueryChanged: reset()

  function reset() {
    list.currentIndex = 0
    list.positionViewAtBeginning()
  }
  function move(delta) {
    if (!items.length) return
    list.currentIndex = Math.max(0, Math.min(items.length - 1, list.currentIndex + delta))
  }

  SearchField {
    id: search
    host: picker.host
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 40
    inset: 6
    iconSize: 22
    fontSize: 21
    placeholder: picker.placeholder
    onKeyPressed: function(event) {
      if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
        picker.move(1); event.accepted = true
      } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
        picker.move(-1); event.accepted = true
      } else if (event.key === Qt.Key_PageDown) {
        picker.move(picker.visibleRows); event.accepted = true
      } else if (event.key === Qt.Key_PageUp) {
        picker.move(-picker.visibleRows); event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (picker.selected) picker.chosen(picker.selected)
        event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        picker.host.view = "rest"; event.accepted = true
      }
    }
  }

  Rectangle {
    id: divider
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: search.bottom
    anchors.topMargin: 10
    height: 1
    color: picker.host.withAlpha(picker.host.colorText, 0.1)
  }

  ListView {
    id: list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: divider.bottom
    anchors.topMargin: 8
    height: picker.rowHeight * picker.visibleRows
    clip: true
    model: picker.items
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    highlightMoveDuration: 0
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: Item {
      id: slot
      required property var modelData
      required property int index
      readonly property bool isSelected: ListView.isCurrentItem
      width: ListView.view.width
      height: picker.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        radius: 12
        color: slot.isSelected ? picker.host.withAlpha(picker.host.colorText, 0.07) : "transparent"
      }
      // Accent bar marking the selected row.
      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 22
        radius: 1.5
        color: picker.host.colorAccent
        visible: slot.isSelected
      }
      Loader {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        sourceComponent: picker.row
        onLoaded: {
          item.entry = Qt.binding(function() { return slot.modelData })
          item.selected = Qt.binding(function() { return slot.isSelected })
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: picker.chosen(slot.modelData)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: picker.items.length === 0
      text: picker.emptyText
      color: picker.host.colorMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
  }
}
