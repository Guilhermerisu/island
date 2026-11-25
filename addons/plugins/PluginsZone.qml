import QtQuick
import QtQuick.Layouts
import ".."
import "../../components"
import "../../views/control-center"

// The plugins pinned to the control center, as a zone (see `zones` in
// Addon.qml): a tile for each, in the order pinned, two to a row where there's
// room (see PluginTile). In edit mode each has a −, and is dragged like a
// control in the grid (see ControlLayout): reordered, or out onto the add
// panel to unpin it; a plugin dragged in from the panel (see PluginGallery)
// takes a place among them. `addon` is the PluginsAddon, `center` the
// ControlCenter, whose drag proxy carries the tile.
// In XSmall they are round badges, the icon alone, wrapped onto as many rows
// as the width asks (the zone is as tall as they are, one row at least), in
// Small short tiles, the name by the icon, two to a row (see PluginChip). They
// are edited in place in all three sizes, by the same order and drop: each is
// a CcSlot at the place `positions` gives it, in the grid, the two columns or
// the badges' rows.
Item {
  id: zone
  required property var addon
  required property var center
  readonly property var dragProxy: center.dragProxy
  readonly property bool editing: center.editMode
  readonly property real gap: center.gap
  property string zoneSize: "normal"
  readonly property bool compact: zoneSize !== "normal"
  readonly property bool xs: zoneSize === "xsmall"
  readonly property real chipSize: 38
  // Room around the compact sizes in edit mode for the − badges on the
  // corners (their zone clips at its edges).
  readonly property real inset: editing && compact ? 6 : 0
  readonly property string emptyText: addon.pinnedIds.length && addon.loading ? "Loading…" : "No pinned plugins"

  // The panel (see AddPanel.layout) drags plugins in through it.
  Component.onCompleted: center.pluginsZone = zone
  Component.onDestruction: if (center.pluginsZone === zone) center.pluginsZone = null

  property string draggedId: ""
  property bool dragFromPanel: false
  property bool dropActive: false
  property bool removeDropActive: false
  // The ids in the order they'd have if dropped now, while one is dragged.
  property var previewIds: []
  readonly property var order: draggedId !== "" ? previewIds : addon.pinned.map(function(entry) { return entry.id })

  // Where each tile in `order` sits, in `area`. Tiles are placed by these,
  // not by a layout, so they can slide when the order changes.
  // XSmall's badges fill a row, then wrap.
  readonly property int columns: xs ? Math.max(1, Math.floor((width - 2 * inset + gap) / (chipSize + gap)))
    : compact ? 2 : width >= 2 * 150 + gap ? 2 : 1
  readonly property real tileWidth: (width - 2 * inset - (columns - 1) * gap) / columns
  readonly property real rowHeight: compact ? chipSize : center.tileHeight
  // Above the first row: the room around the compact sizes in edit mode, but
  // XSmall's badges stay centred in its line (more than the inset).
  readonly property real padY: xs ? (center.zoneXsHeight - chipSize) / 2 : inset
  readonly property var positions: {
    var slots = {}
    order.forEach(function(id, i) {
      slots[id] = xs
        ? { x: zone.inset + (i % zone.columns) * (zone.chipSize + zone.gap), y: zone.padY + Math.floor(i / zone.columns) * (zone.rowHeight + zone.gap),
            width: zone.chipSize, height: zone.chipSize }
        : { x: zone.inset + (i % zone.columns) * (zone.tileWidth + zone.gap), y: zone.padY + Math.floor(i / zone.columns) * (zone.rowHeight + zone.gap),
            width: zone.tileWidth, height: zone.rowHeight }
    })
    return slots
  }
  readonly property real gridHeight: order.length
    ? Math.ceil(order.length / columns) * (rowHeight + gap) - gap + 2 * padY : compact ? chipSize + 2 * padY : 0
  // A row's slack under the tiles: the zone is only as tall as they are.
  readonly property real slack: xs ? 0 : rowHeight + gap

  // XSmall is one line (58) until its badges need more rows. Never derived
  // from the height given (`columns` comes from the width only).
  implicitHeight: xs ? Math.max(center.zoneXsHeight, gridHeight) : order.length || compact ? gridHeight : empty.implicitHeight

  function endDrag(keepProxy) {
    if (!keepProxy && draggedId !== "" && dragProxy.lifted) dragProxy.release(null)
    draggedId = ""
    dragFromPanel = false
    dropActive = false
    removeDropActive = false
    previewIds = []
  }
  Connections {
    target: zone.center
    function onActiveChanged() { zone.endDrag() }
    function onEditModeChanged() { zone.endDrag() }
  }
  // `grabX`/`grabY`: where in the tile the pointer went down (the middle
  // when not given), as in ControlLayout.
  function beginDrag(id, fromPanel, width, height, grabX, grabY) {
    previewIds = addon.pinned.map(function(entry) { return entry.id })
    dragFromPanel = fromPanel
    draggedId = id
    // A plugin dragged in from the panel is made the size of the zone's own.
    if (fromPanel && compact) {
      width = xs ? chipSize : tileWidth
      height = chipSize
    }
    dragProxy.grabX = grabX === undefined ? width / 2 : Math.min(grabX, width)
    dragProxy.grabY = grabY === undefined ? height / 2 : Math.min(grabY, height)
    // Its corners: the tile's, or a badge's.
    dragProxy.radius = xs ? width / 2 : Math.min(center.cardRadius, height / 2)
    dragProxy.lift(id, false, width, height, compact ? chipContent : tileContent)
  }
  function moveDrag(source, x, y) {
    dragProxy.follow(source, x, y)
    var panel = center.addPanel
    var panelPoint = source.mapToItem(panel, x, y)
    removeDropActive = !dragFromPanel && panel.visible
      && panelPoint.x >= 0 && panelPoint.x <= panel.width
      && panelPoint.y >= 0 && panelPoint.y <= panel.height
    var point = source.mapToItem(zone, x, y)
    dropActive = !removeDropActive && point.x >= 0 && point.x <= width && point.y >= 0 && point.y <= height + slack
    var at = source.mapToItem(area, x, y)
    if (dropActive) previewInsertAt(at.x, at.y)
    else if (dragFromPanel) previewIds = previewIds.filter(function(id) { return id !== draggedId })
  }
  // Before the first tile that is below the pointer, or right of it in its
  // row. Kept while the pointer is over the dragged tile's own place, so the
  // tiles don't flip back and forth under it.
  function previewInsertAt(x, y) {
    var own = positions[draggedId]
    if (own && x >= own.x && x <= own.x + own.width && y >= own.y && y <= own.y + own.height) return
    var rest = previewIds.filter(function(id) { return id !== draggedId })
    var at = rest.length
    for (var i = 0; i < rest.length; i++) {
      var slot = positions[rest[i]]
      if (slot && (y < slot.y || (y < slot.y + slot.height && x < slot.x + slot.width / 2))) {
        at = i
        break
      }
    }
    rest.splice(at, 0, draggedId)
    previewIds = rest
  }
  function finishDrag() {
    var id = draggedId
    if (id !== "" && removeDropActive) {
      addon.unpin(id)
    } else if (id !== "" && dropActive) {
      var next = previewIds[previewIds.indexOf(id) + 1]
      addon.pin(id, next)
    }
    endDrag(true)
    // The slot it lands in, read after endDrag so it's the saved order (or
    // its old place, when dropped outside); none once unpinned or never pinned.
    var slot = id !== "" ? positions[id] : null
    var origin = slot ? area.mapToItem(dragProxy.parent, slot.x, slot.y) : null
    dragProxy.release(slot ? { x: origin.x, y: origin.y, width: slot.width, height: slot.height } : null)
  }

  // The tile the drag proxy carries (it holds the plugin's id as its key).
  Component {
    id: tileContent
    PluginTile {
      anchors.fill: parent
      center: zone.center
      addon: zone.addon
      entry: zone.addon.entryFor(zone.dragProxy.key) || zone.addon.all[0]
    }
  }
  // The same for the compact sizes.
  Component {
    id: chipContent
    PluginChip {
      anchors.fill: parent
      round: zone.xs
      center: zone.center
      addon: zone.addon
      entry: zone.addon.entryFor(zone.dragProxy.key) || zone.addon.all[0]
    }
  }

  // The tiles' place.
  Item {
    id: area
    width: zone.width
    height: zone.implicitHeight
    Repeater {
      model: zone.addon.all
      delegate: CcSlot {
        id: slot
        required property var modelData
        center: zone.center
        place: zone.positions[modelData.id] || null
        animated: zone.editing && zone.center.settled
        sliding: zone.editing && zone.center.settled
        editing: zone.editing
        dragged: zone.draggedId === modelData.id
        cornerRadius: zone.xs ? zone.chipSize / 2 : zone.compact ? Math.min(zone.center.cardRadius, zone.chipSize / 2) : zone.center.cardRadius
        tip: "Unpin " + modelData.name
        onDragBegan: function(grabX, grabY) { zone.beginDrag(modelData.id, false, width, height, grabX, grabY) }
        onDragMoved: function(source, x, y) { zone.moveDrag(source, x, y) }
        onDragEnded: function(source, x, y) { zone.moveDrag(source, x, y); zone.finishDrag() }
        onDragCanceled: zone.endDrag()
        onRemoved: { zone.addon.unpin(modelData.id); zone.endDrag() }
        Loader {
          anchors.fill: parent
          sourceComponent: zone.compact ? chip : tile
        }
        Component {
          id: tile
          PluginTile {
            anchors.fill: parent
            center: zone.center
            addon: zone.addon
            entry: slot.modelData
            // Editing is not for opening them.
            enabled: !zone.editing
          }
        }
        Component {
          id: chip
          PluginChip {
            anchors.fill: parent
            round: zone.xs
            center: zone.center
            addon: zone.addon
            entry: slot.modelData
            enabled: !zone.editing
          }
        }
      }
    }
  }
  AddonZone {
    id: empty
    visible: !zone.compact && zone.order.length === 0
    width: parent.width
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: zone.editing ? "Drag a plugin here" : zone.addon.pinnedIds.length && zone.addon.loading ? "Loading…" : "No plugins pinned"
      color: zone.center.textMuted
      font.family: zone.center.host.theme.textFontFamily
      font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.callout)
      font.pixelSize: zone.center.host.theme.size.callout
    }
  }

  // XSmall and Small. Nothing pinned: a quiet line.
  Text {
    visible: zone.compact && zone.order.length === 0
    anchors.fill: parent
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: zone.editing ? "Drag a plugin here" : zone.emptyText
    color: zone.center.textMuted
    font.family: zone.center.host.theme.textFontFamily
    font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.callout)
    font.pixelSize: zone.center.host.theme.size.callout
  }
}
