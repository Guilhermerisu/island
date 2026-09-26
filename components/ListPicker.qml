import QtQuick

// Shared list view for the island: a search field over a scrolling list, with
// the selected row marked by a soft highlight and an accent bar. With
// `columns` above 1 it becomes a grid of cells (the selected one highlighted)
// and ←/→ move across while ↑/↓ move by rows.
// Keyboard: type to search, ↑/↓ (or Tab, PageUp/PageDown) to move, Enter to
// choose, Esc to close. Clicking a row chooses it.
//
// The owner filters: bind `items` to a list computed from `query`. Rows are
// drawn by `row`, a component whose root declares `property var entry` and
// `property bool selected`. An optional `side` component (same `entry`
// property, bound to the selected item) is shown in a pane to the right of
// the list, `sideWidth` wide.
Item {
  id: picker
  required property var host
  property bool active: false
  property var items: []
  property Component row
  property Component side
  property int sideWidth: 300
  // Lets a view show the pane only for some items (e.g. just images).
  property bool sideVisible: true
  readonly property bool showSide: !!side && sideVisible
  property string placeholder: "Search"
  property string emptyText: "Nothing matches"
  property int rowHeight: 50
  property int visibleRows: 7
  property int columns: 1
  readonly property bool grid: columns > 1
  // Spotlight-style selection: the selected row fills with the theme accent
  // (rows should switch their text to host.colorAccentText when selected).
  property bool fillSelection: false
  readonly property string query: search.text
  readonly property var selected: items[list.currentIndex] || null
  signal chosen(var entry)
  // Offered every key first; a view sets event.accepted to handle one itself
  // (e.g. Delete to remove an entry, Shift+Enter for a second action).
  signal keyFilter(var event)

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
      picker.keyFilter(event)
      if (event.accepted) return
      if (picker.grid && event.key === Qt.Key_Right) {
        picker.move(1); event.accepted = true
      } else if (picker.grid && event.key === Qt.Key_Left) {
        picker.move(-1); event.accepted = true
      } else if (event.key === Qt.Key_Down) {
        picker.move(picker.columns); event.accepted = true
      } else if (event.key === Qt.Key_Up) {
        picker.move(-picker.columns); event.accepted = true
      } else if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
        picker.move(1); event.accepted = true
      } else if (event.key === Qt.Key_Backtab) {
        picker.move(-1); event.accepted = true
      } else if (event.key === Qt.Key_PageDown) {
        picker.move(picker.visibleRows * picker.columns); event.accepted = true
      } else if (event.key === Qt.Key_PageUp) {
        picker.move(-picker.visibleRows * picker.columns); event.accepted = true
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

  // A GridView with one full-width column doubles as the list.
  GridView {
    id: list
    anchors.left: parent.left
    anchors.right: picker.showSide ? sidePane.left : parent.right
    anchors.rightMargin: picker.showSide ? 12 : 0
    anchors.top: divider.bottom
    anchors.topMargin: 8
    height: picker.rowHeight * picker.visibleRows
    cellWidth: Math.floor(width / picker.columns)
    cellHeight: picker.rowHeight
    clip: true
    model: picker.items
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    highlightMoveDuration: 0
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

    delegate: Item {
      id: slot
      required property var modelData
      required property int index
      readonly property bool isSelected: GridView.isCurrentItem
      width: list.cellWidth
      height: list.cellHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: picker.grid ? 3 : picker.fillSelection ? 0 : 8
        anchors.rightMargin: picker.grid ? 3 : 0
        anchors.topMargin: picker.grid ? 3 : 0
        anchors.bottomMargin: picker.grid ? 3 : 0
        radius: 12
        color: !slot.isSelected ? "transparent"
          : picker.fillSelection ? picker.host.colorAccent
          : picker.grid ? picker.host.withAlpha(picker.host.colorAccent, 0.28)
          : picker.host.withAlpha(picker.host.colorText, 0.07)
      }
      // Accent bar marking the selected row (list mode).
      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 22
        radius: 1.5
        color: picker.host.colorAccent
        visible: slot.isSelected && !picker.grid && !picker.fillSelection
      }
      Loader {
        anchors.fill: parent
        anchors.leftMargin: picker.grid ? 0 : picker.fillSelection ? 10 : 16
        anchors.rightMargin: picker.grid ? 0 : 12
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

  // Details for the selected item (e.g. a clipboard image preview).
  Rectangle {
    id: sidePane
    visible: picker.showSide
    anchors.right: parent.right
    anchors.top: list.top
    anchors.bottom: list.bottom
    width: picker.showSide ? picker.sideWidth : 0
    color: "transparent"
    Loader {
      anchors.fill: parent
      anchors.margins: 4
      sourceComponent: picker.side
      onLoaded: item.entry = Qt.binding(function() { return picker.selected || ({}) })
    }
  }
}
