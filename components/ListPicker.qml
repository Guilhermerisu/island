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
  // The list fits its contents, from `minRows` up to `visibleRows` rows, so
  // the island morphs as you type or change menus instead of leaving space.
  property int visibleRows: 7
  property int minRows: 1
  readonly property int contentRows: grid ? Math.ceil(items.length / columns) : items.length
  readonly property int shownRows: Math.max(minRows, Math.min(visibleRows, contentRows))
  property int columns: 1
  readonly property bool grid: columns > 1
  readonly property string query: search.text
  readonly property var selected: items[list.currentIndex] || null
  signal chosen(var entry)
  // Offered every key first; a view sets event.accepted to handle one itself
  // (e.g. Delete to remove an entry, Shift+Enter for a second action).
  signal keyFilter(var event)

  implicitHeight: search.height + 10 + list.height

  onActiveChanged: {
    if (!active) return
    search.clear()
    reset()
    Qt.callLater(function() { search.focusInput() })
  }
  onQueryChanged: reset()
  // The list re-forms under the cursor (results, clipboard, the live app
  // list), so keep the selection on a row that exists and can be picked.
  onItemsChanged: {
    if (!list) return
    if (!items.length) { list.currentIndex = 0; return }
    if (list.currentIndex >= items.length || isDisabled(items[list.currentIndex]))
      list.currentIndex = firstSelectable()
  }

  function clearSearch() { search.clear() }
  // Rows whose `disabled:` guard answered true stay listed but dimmed, and
  // the cursor steps over them, the way Omarchy's menu treats them.
  function isDisabled(item) { return !!(item && item.disabled) }
  function firstSelectable() {
    for (var i = 0; i < items.length; i++) if (!isDisabled(items[i])) return i
    return 0
  }
  function reset() {
    list.currentIndex = firstSelectable()
    if (items.length) list.positionViewAtIndex(list.currentIndex, GridView.Contain)
  }
  function move(delta) {
    if (!items.length) return
    var next = list.currentIndex
    for (var step = 0; step < items.length; step++) {
      next = Math.max(0, Math.min(items.length - 1, next + delta))
      if (!isDisabled(items[next])) { list.currentIndex = next; return }
    }
  }

  SearchField {
    id: search
    host: picker.host
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
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
        if (picker.selected && !picker.isDisabled(picker.selected)) picker.chosen(picker.selected)
        event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        picker.host.view = "rest"; event.accepted = true
      }
    }
  }

  // A GridView with one full-width column doubles as the list.
  GridView {
    id: list
    OverlayScrollbar { flickable: list; parent: list; theme: picker.host.theme }
    anchors.left: parent.left
    anchors.right: picker.showSide ? sidePane.left : parent.right
    anchors.rightMargin: picker.showSide ? 12 : 0
    anchors.top: search.bottom
    anchors.topMargin: 10
    height: picker.rowHeight * picker.shownRows
    cellWidth: Math.floor(width / picker.columns)
    cellHeight: picker.rowHeight
    clip: true
    model: picker.items
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

    // One highlight for the whole list that glides to the selected row,
    // rather than each row lighting up on its own.
    highlightFollowsCurrentItem: false
    highlight: Rectangle {
      readonly property Item at: list.currentItem
      readonly property bool atDisabled: !!at && at.itemDisabled
      visible: !!at && list.count > 0
      x: at ? at.x + (picker.grid ? 3 : 0) : 0
      y: at ? at.y + (picker.grid ? 3 : 0) : 0
      width: list.cellWidth - (picker.grid ? 6 : 0)
      height: list.cellHeight - (picker.grid ? 6 : 0)
      radius: 12
      color: picker.grid ? picker.host.theme.accentFill("medium") : picker.host.theme.fill("raised")
      opacity: atDisabled ? 0.4 : 1
      Behavior on x { MotionAnimation { theme: picker.host.theme; pace: "quick" } }
      Behavior on y { MotionAnimation { theme: picker.host.theme; pace: "quick" } }
    }

    delegate: Item {
      id: slot
      required property var modelData
      required property int index
      readonly property bool isSelected: GridView.isCurrentItem
      readonly property bool itemDisabled: picker.isDisabled(slot.modelData)
      width: list.cellWidth
      height: list.cellHeight
      opacity: slot.itemDisabled ? 0.4 : 1

      Loader {
        anchors.fill: parent
        anchors.leftMargin: picker.grid ? 0 : 10
        anchors.rightMargin: picker.grid ? 0 : 12
        sourceComponent: picker.row
        onLoaded: {
          item.entry = Qt.binding(function() { return slot.modelData || ({}) })
          item.selected = Qt.binding(function() { return slot.isSelected })
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: slot.itemDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!slot.itemDisabled) picker.chosen(slot.modelData)
      }
    }

    // Soft edges where the list runs on above or below, as in Settings.
    Repeater {
      model: [
        { top: true, shown: list.contentY - list.originY > 1 },
        { top: false, shown: list.contentY - list.originY < list.contentHeight - list.height - 1 }
      ]
      delegate: Rectangle {
        required property var modelData
        parent: list
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        y: modelData.top ? 0 : list.height - height
        height: 24
        opacity: modelData.shown ? 1 : 0
        Behavior on opacity { MotionAnimation { theme: picker.host.theme; pace: "fade"; curve: "fade" } }
        gradient: Gradient {
          GradientStop { position: 0; color: modelData.top ? picker.host.theme.background : "transparent" }
          GradientStop { position: 1; color: modelData.top ? "transparent" : picker.host.theme.background }
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: picker.items.length === 0
      text: picker.emptyText
      color: picker.host.theme.muted
      font.family: picker.host.theme.textFontFamily
      font.pixelSize: picker.host.theme.px(13)
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
