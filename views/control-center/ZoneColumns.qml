import QtQuick
import QtQuick.Layouts
import "../../components"
import "zones.js" as ZoneModel

// The control center's zones in their columns (see Zones.qml). In edit mode
// a zone is picked up by its title bar and dropped in another place or
// column: a stand-in follows the pointer, the DropArea of the column under
// it says where, and a line shows the place. Between two columns a handle
// trades width from one to the other; the island's width doesn't change.
// `center` is the ControlCenter.
Item {
  id: board
  required property var center
  readonly property var zones: center.zones
  Layout.fillWidth: true
  // Not a layout itself, so the stand-in can be placed freely over the columns.
  implicitHeight: row.implicitHeight
  visible: implicitHeight > 0

  property string draggedId: ""
  property real grabX: 0
  property real grabY: 0
  property int dropColumn: -1
  property int dropIndex: 0

  // Which columns take room: all of them while editing, else those holding a zone.
  readonly property var shown: {
    var arrangement = zones.arrangement
    return arrangement.map(function(column) { return center.editMode || column.length > 0 })
  }
  // The shares as dragged, until the handle is let go and they are saved.
  property var liveShares: null
  // Each column's width once the island has reached its width, which is
  // what a zone's minimum is judged by (the layout follows the island as it
  // grows, in proportion).
  readonly property var finalWidths: ZoneModel.widths(liveShares || zones.shares, shown, center.columnsSpace, ZoneModel.minColumnWidth)
  function layoutWidth(index) {
    var space = center.columnsSpace
    return space > 0 && finalWidths[index] ? finalWidths[index] / space * Math.max(0, width - (center.shownColumns - 1) * center.gap) : 0
  }
  // The Flickable the control center scrolls in (Views.qml), if any: the
  // handles' capsules stay in the middle of what it shows.
  readonly property var scroller: {
    var item = parent
    while (item && item.contentY === undefined) item = item.parent
    return item
  }
  // Middle of the part of the columns in view, in the board's coordinates;
  // on the columns, never beyond them. Reads cc.y and the board's y because
  // the scroller's content is the control center, and they move the board.
  readonly property real viewMiddle: {
    if (!scroller) return height / 2
    var top = scroller.contentY - center.y - y
    var from = Math.max(0, Math.min(top, height))
    var to = Math.max(0, Math.min(top + scroller.height, height))
    return (from + to) / 2
  }
  // The next column showing after `index`, or -1.
  function nextShown(index) {
    for (var i = index + 1; i < shown.length; i++) if (shown[i]) return i
    return -1
  }

  function place(scene) {
    var point = mapFromItem(null, scene.x, scene.y)
    ghost.x = point.x - grabX
    ghost.y = point.y - grabY
  }
  // `size` of the bar, `grab` where in it the pointer went down, `scene` the pointer.
  function beginDrag(id, size, grab, scene) {
    ghost.width = size.width
    ghost.height = size.height
    grabX = grab.x
    grabY = grab.y
    place(scene)
    draggedId = id
  }
  function moveDrag(scene) { if (draggedId !== "") place(scene) }
  // Dropping lands in the DropArea under the pointer, if any.
  function finishDrag() {
    if (draggedId === "") return
    ghost.Drag.drop()
    cancelDrag()
  }
  function cancelDrag() {
    draggedId = ""
    dropColumn = -1
  }
  Connections {
    target: board.center
    function onActiveChanged() { board.cancelDrag() }
    function onEditModeChanged() { board.cancelDrag() }
  }

  RowLayout {
    id: row
    width: parent.width
    spacing: board.center.gap
    Repeater {
      model: board.zones.columns
      delegate: Item {
        id: column
        required property int index
        readonly property int count: zoneRepeater.count
        // Hidden when empty, except while editing, and then it takes no width.
        visible: board.shown[index] === true
        Layout.fillHeight: true
        Layout.preferredWidth: board.layoutWidth(index)
        Layout.minimumWidth: 0
        implicitHeight: Math.max(stack.implicitHeight, board.center.editMode ? 64 : 0)

        // Kept by id, so a zone staying in the column isn't rebuilt when
        // another is added or removed.
        KeyedListModel {
          id: rows
          values: board.zones.arrangement[column.index] || []
        }

        // Where a drop at `y` in the column goes: before the first zone whose
        // middle is below it.
        function indexAt(y) {
          for (var i = 0; i < count; i++) {
            var item = zoneRepeater.itemAt(i)
            if (item && y < item.y + item.height / 2) return i
          }
          return count
        }
        function lineY(index) {
          if (count === 0) return 0
          var item = zoneRepeater.itemAt(Math.min(index, count - 1))
          if (!item) return 0
          return (index < count ? item.y - row.spacing / 2 : item.y + item.height + row.spacing / 2) - 1.5
        }

        Rectangle {
          anchors.fill: parent
          visible: board.center.editMode && column.count === 0
          radius: board.center.cardRadius
          color: board.center.host.theme.fill("quiet")
          border.width: 1.5
          border.color: board.dropColumn === column.index ? board.center.accent : board.center.host.theme.fill("strong")
          Text {
            anchors.centerIn: parent
            text: "Drag a zone here"
            color: board.center.textMuted
            font.family: board.center.host.theme.textFontFamily
            font.letterSpacing: board.center.host.theme.tracking(board.center.host.theme.textFontFamily, board.center.host.theme.px(13))
            font.pixelSize: board.center.host.theme.px(13)
          }
        }

        ColumnLayout {
          id: stack
          width: parent.width
          spacing: board.center.gap
          Repeater {
            id: zoneRepeater
            model: rows.model
            delegate: ZoneCard {
              required property var entry
              Layout.fillWidth: true
              center: board.center
              zoneBoard: board
              zoneId: entry
              columnWidth: board.finalWidths[column.index] || 0
            }
          }
        }

        // Where the dragged zone would land.
        Rectangle {
          visible: board.draggedId !== "" && board.dropColumn === column.index && column.count > 0
          y: column.lineY(board.dropIndex)
          width: parent.width
          height: 3
          radius: 1.5
          color: board.center.accent
        }

        // Between this column and the next one showing, over both a little.
        // The whole height is grabbable; the capsule sits mid-view, like the
        // grip under the island, and is always shown.
        MouseArea {
          id: handle
          readonly property int next: board.nextShown(column.index)
          property real startX: 0
          property var startShares: null
          property bool moved: false
          visible: next !== -1
          z: 5
          x: column.width + board.center.gap / 2 - width / 2
          width: board.center.gap + 8
          height: column.height
          hoverEnabled: true
          preventStealing: true
          cursorShape: Qt.SizeHorCursor
          function sceneX(mouse) { return mapToItem(null, mouse.x, mouse.y).x }
          onPressed: function(mouse) {
            startX = sceneX(mouse)
            startShares = board.zones.shares
            moved = false
          }
          // In window coordinates: the handle moves with the columns.
          onPositionChanged: function(mouse) {
            if (!pressed) return
            var dx = sceneX(mouse) - startX
            if (!moved && Math.abs(dx) < 2) return
            moved = true
            board.liveShares = ZoneModel.dragShares(startShares, board.shown, board.center.columnsSpace,
              ZoneModel.minColumnWidth, column.index, next, dx)
          }
          // Saved on release, and only if it moved, so a click writes nothing.
          onReleased: {
            if (moved && board.liveShares) board.zones.setShares(board.liveShares)
            board.liveShares = null
          }
          onCanceled: board.liveShares = null
          onDoubleClicked: board.zones.setShares(null)
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, Math.min(parent.height - height, board.viewMiddle - height / 2))
            width: 5
            height: 36
            radius: 2.5
            color: handle.pressed || handle.containsMouse ? board.center.host.theme.fill("stronger") : board.center.host.theme.fill("strong")
            Behavior on color { MotionColorAnimation { theme: board.center.host.theme } }
          }
        }

        DropArea {
          anchors.fill: parent
          keys: ["zone"]
          onEntered: function(drag) {
            board.dropColumn = column.index
            board.dropIndex = column.indexAt(drag.y)
          }
          onPositionChanged: function(drag) { board.dropIndex = column.indexAt(drag.y) }
          onExited: if (board.dropColumn === column.index) board.dropColumn = -1
          onDropped: function(drop) { board.zones.move(board.draggedId, column.index, column.indexAt(drop.y)) }
        }
      }
    }
  }

  // The zone being moved, as its bar.
  Rectangle {
    id: ghost
    z: 10
    visible: board.draggedId !== ""
    radius: Math.min(board.center.cardRadius, height / 2)
    color: board.center.tile
    border.width: 1
    border.color: board.center.edge
    scale: 1.03
    Drag.active: board.draggedId !== ""
    // Only the columns take it, not what else is dragged (a plugin's card).
    Drag.keys: ["zone"]
    Drag.hotSpot.x: board.grabX
    Drag.hotSpot.y: board.grabY
    Text {
      anchors.centerIn: parent
      text: board.zones.definition(board.draggedId) ? board.zones.definition(board.draggedId).title : ""
      color: board.center.text
      font.family: board.center.host.theme.textFontFamily
      font.letterSpacing: board.center.host.theme.tracking(board.center.host.theme.textFontFamily, board.center.host.theme.px(12))
      font.pixelSize: board.center.host.theme.px(12)
      font.weight: Font.DemiBold
    }
  }
}
