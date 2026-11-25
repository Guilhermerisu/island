import QtQuick

// Shared list view for the island: a search field over a scrolling list, with
// the selected (or hovered) row marked by a soft well. With
// `columns` above 1 it becomes a grid of cells (the selected one highlighted)
// and ←/→ move across while ↑/↓ move by rows; the selected cell gets a well
// with the accent ring set just outside it, as the theme and wallpaper
// pickers mark theirs.
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
  // Whether becoming active puts the keyboard in the search field; a list
  // sharing the screen with others (a control center zone) leaves it be.
  property bool takeFocus: true
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
  // Between a list row's edges and what it draws.
  property int rowPadding: 12
  // A list's space between rows, and its highlight's corners.
  property int rowGap: 0
  property int rowRadius: 10
  // The pointer moves the selection, so one row is lit at a time, instead of
  // the hovered row getting a second well.
  property bool hoverSelects: false
  readonly property int cellHeight: rowHeight + (grid ? 0 : rowGap)
  // Where the pointer last moved the selection (hoverSelects), in screen
  // coordinates.
  property point lastPointer: Qt.point(-1, -1)
  // The gap between grid cells.
  property int cellGap: 6
  // A bar under the list (e.g. the selected emoji's name), set off by a
  // hairline; its component's root has `property var entry`, bound to the
  // selected item.
  property Component footer
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

  // The selection ring reaches past a grid's outer cells, so the grid is
  // padded to keep it from being clipped.
  readonly property real ringGap: 2
  readonly property real ringWidth: 2
  readonly property int gridPad: grid ? Math.max(0, Math.ceil(ringGap + ringWidth - cellGap / 2)) : 0

  implicitHeight: search.height + 8 + list.height + (footer ? footerBar.height : 0)

  onActiveChanged: {
    if (!active) return
    search.clear()
    reset()
    if (takeFocus) focusSearch()
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
  function focusSearch() { Qt.callLater(function() { search.focusInput() }) }
  // Rows whose `disabled:` guard answered true stay listed but dimmed, and
  // the cursor steps over them, the way Omarchy's menu treats them.
  function isDisabled(item) { return !!(item && item.disabled) }
  function firstSelectable() {
    for (var i = 0; i < items.length; i++) if (!isDisabled(items[i])) return i
    return 0
  }
  function reset() {
    list.currentIndex = firstSelectable()
    if (items.length) reveal(list.currentIndex)
  }
  // Scrolls just enough to show a row, its padding (and so a grid's ring)
  // included, which positionViewAtIndex leaves out.
  function reveal(index) {
    var top = Math.floor(index / columns) * cellHeight - gridPad
    var bottom = top + cellHeight + 2 * gridPad
    var lowest = -gridPad
    var highest = Math.max(lowest, list.contentHeight + gridPad - list.height)
    var next = list.contentY
    if (top < next) next = top
    else if (bottom > next + list.height) next = bottom - list.height
    list.contentY = Math.max(lowest, Math.min(highest, next))
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

  StaggerIn { target: search; step: 0 }
  StaggerIn { target: list; step: 1 }

  // A GridView with one full-width column doubles as the list.
  GridView {
    id: list
    OverlayScrollbar { flickable: list; parent: list; theme: picker.host.theme }
    anchors.left: parent.left
    anchors.right: picker.showSide ? sidePane.left : parent.right
    anchors.rightMargin: picker.showSide ? 12 : 0
    anchors.top: search.bottom
    anchors.topMargin: 8
    height: picker.cellHeight * picker.shownRows + 2 * picker.gridPad
    leftMargin: picker.gridPad
    rightMargin: picker.gridPad
    topMargin: picker.gridPad
    bottomMargin: picker.gridPad
    cellWidth: Math.floor((width - 2 * picker.gridPad) / picker.columns)
    cellHeight: picker.cellHeight
    clip: true
    model: picker.items
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    onCurrentIndexChanged: picker.reveal(currentIndex)

    // One highlight for the whole list that glides to the selected row,
    // rather than each row lighting up on its own.
    highlightFollowsCurrentItem: false
    highlight: Rectangle {
      id: highlight
      readonly property Item at: list.currentItem
      readonly property bool atDisabled: !!at && at.itemDisabled
      // Only glide from one row to another: when rows come back (say after a
      // search with no results) it appears on its row instead of sliding in
      // from the corner. Re-armed a tick later, once it has jumped there (if
      // the list hasn't been torn down meanwhile).
      property bool glides: false
      onAtChanged: {
        if (!at) glides = false
        else if (!glides) Qt.callLater(function() { if (highlight && highlight.at) highlight.glides = true })
      }
      visible: !!at && list.count > 0
      readonly property real inset: picker.grid ? picker.cellGap / 2 : 0
      x: at ? at.x + inset : 0
      y: at ? at.y + inset + picker.rowGap / 2 : 0
      width: list.cellWidth - 2 * inset
      height: picker.rowHeight - 2 * inset
      radius: picker.rowRadius
      color: picker.host.theme.well
      opacity: atDisabled ? 0.4 : 1
      // A grid's ring, with the island's black between it and the well.
      Rectangle {
        visible: picker.grid
        anchors.fill: parent
        anchors.margins: -(picker.ringGap + picker.ringWidth)
        radius: parent.radius + picker.ringGap + picker.ringWidth
        color: "transparent"
        border.width: picker.ringWidth
        border.color: picker.host.theme.accent
      }
      Behavior on x { enabled: highlight.glides; MotionAnimation { theme: picker.host.theme; pace: "quick" } }
      Behavior on y { enabled: highlight.glides; MotionAnimation { theme: picker.host.theme; pace: "quick" } }
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

      // A hovered row gets the selection's well too (the gliding highlight
      // stays on the selected one).
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: picker.rowHeight
        visible: !picker.grid && !picker.hoverSelects && slotMouse.containsMouse && !slot.isSelected && !slot.itemDisabled
        radius: picker.rowRadius
        color: picker.host.theme.well
      }
      Loader {
        id: rowLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: picker.rowHeight
        scale: picker.grid && slotMouse.pressed && !slot.itemDisabled ? 0.96 : 1
        Behavior on scale { id: scaleMotion; MotionAnimation { theme: picker.host.theme; pace: towards(scaleMotion.targetValue, slotMouse.pressed ? "press" : "standard") } }
        anchors.leftMargin: picker.grid ? 0 : picker.rowPadding
        anchors.rightMargin: picker.grid ? 0 : picker.rowPadding
        sourceComponent: picker.row
        onLoaded: {
          item.entry = Qt.binding(function() { return slot.modelData || ({}) })
          item.selected = Qt.binding(function() { return slot.isSelected })
        }
      }
      MouseArea {
        id: slotMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: slot.itemDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        // Only a real move of the pointer, not the list scrolling under a
        // still one (keys reveal rows), takes the selection.
        onPositionChanged: function(mouse) {
          if (!picker.hoverSelects || slot.itemDisabled) return
          var at = mapToGlobal(mouse.x, mouse.y)
          if (at.x === picker.lastPointer.x && at.y === picker.lastPointer.y) return
          picker.lastPointer = at
          list.currentIndex = slot.index
        }
        onClicked: function(mouse) {
          if (slot.itemDisabled) return
          // A row can take a click on a part of itself (clickAt, true when it did).
          var row = rowLoader.item
          var at = row && row.clickAt ? mapToItem(row, mouse.x, mouse.y) : null
          if (!at || !row.clickAt(at.x, at.y)) picker.chosen(slot.modelData)
        }
      }
    }

    // Soft edges where the list runs on above or below, as in Settings.
    // A fixed model, so scrolling only changes the opacity (and the fade runs)
    // instead of rebuilding the edges.
    Repeater {
      model: 2
      delegate: Rectangle {
        required property int index
        readonly property bool upper: index === 0
        readonly property real scrolled: list.contentY - list.originY
        parent: list
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        y: upper ? 0 : list.height - height
        height: 24
        opacity: (upper ? scrolled > 1 : scrolled < list.contentHeight - list.height - 1) ? 1 : 0
        Behavior on opacity { MotionAnimation { theme: picker.host.theme; pace: "fade"; curve: "fade" } }
        gradient: Gradient {
          GradientStop { position: 0; color: upper ? picker.host.theme.background : "transparent" }
          GradientStop { position: 1; color: upper ? "transparent" : picker.host.theme.background }
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: picker.items.length === 0
      text: picker.emptyText
      color: picker.host.theme.muted
      font.family: picker.host.theme.textFontFamily
      font.letterSpacing: picker.host.theme.tracking(picker.host.theme.textFontFamily, picker.host.theme.size.body)
      font.pixelSize: picker.host.theme.size.body
    }
  }

  // Under the list: a hairline, then the footer's bar.
  Item {
    id: footerBar
    visible: !!picker.footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: list.bottom
    height: visible ? 1 + 8 + 28 : 0
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 1
      color: picker.host.theme.hairline
    }
    Loader {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 28
      sourceComponent: picker.footer
      onLoaded: item.entry = Qt.binding(function() { return picker.selected || ({}) })
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
