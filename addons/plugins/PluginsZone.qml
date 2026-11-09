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
Item {
  id: zone
  required property var addon
  required property var center
  readonly property var dragProxy: center.dragProxy
  readonly property bool editing: center.editMode
  readonly property real gap: center.gap

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

  // Where each tile in `order` sits. Tiles are placed by these, not by a
  // layout, so they can slide when the order changes.
  readonly property int columns: width >= 2 * 150 + gap ? 2 : 1
  readonly property real tileWidth: (width - (columns - 1) * gap) / columns
  readonly property var positions: {
    var slots = {}
    order.forEach(function(id, i) {
      slots[id] = {
        x: (i % zone.columns) * (zone.tileWidth + zone.gap),
        y: Math.floor(i / zone.columns) * (zone.center.tileHeight + zone.gap),
        width: zone.tileWidth, height: zone.center.tileHeight
      }
    })
    return slots
  }
  readonly property real gridHeight: order.length
    ? Math.ceil(order.length / columns) * (center.tileHeight + gap) - gap : 0

  implicitHeight: order.length ? gridHeight : empty.implicitHeight

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
    dragProxy.grabX = grabX === undefined ? width / 2 : grabX
    dragProxy.grabY = grabY === undefined ? height / 2 : grabY
    dragProxy.lift(id, false, width, height, tileContent)
  }
  function moveDrag(source, x, y) {
    dragProxy.follow(source, x, y)
    var panel = center.addPanel
    var panelPoint = source.mapToItem(panel, x, y)
    removeDropActive = !dragFromPanel && panel.visible
      && panelPoint.x >= 0 && panelPoint.x <= panel.width
      && panelPoint.y >= 0 && panelPoint.y <= panel.height
    var point = source.mapToItem(zone, x, y)
    // A row's slack under the tiles: the zone is only as tall as they are.
    dropActive = !removeDropActive && point.x >= 0 && point.x <= width && point.y >= 0 && point.y <= height + center.tileHeight + gap
    if (dropActive) previewInsertAt(point.x, point.y)
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
    var origin = slot ? zone.mapToItem(dragProxy.parent, slot.x, slot.y) : null
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

  Repeater {
    model: zone.addon.all
    delegate: Item {
      id: slot
      required property var modelData
      readonly property var place: zone.positions[modelData.id] || null
      readonly property bool shown: !!place
      readonly property bool dragged: zone.draggedId === modelData.id
      // Where it last was, so a tile leaving fades out in place.
      property var lastPlace: null
      onPlaceChanged: if (place) lastPlace = place
      Component.onCompleted: lastPlace = place
      x: lastPlace ? lastPlace.x : 0
      y: lastPlace ? lastPlace.y : 0
      width: lastPlace ? lastPlace.width : 0
      height: lastPlace ? lastPlace.height : 0
      opacity: shown ? 1 : 0
      scale: shown ? 1 : 0.9
      visible: opacity > 0.01
      Behavior on opacity { enabled: zone.editing && zone.center.settled; MotionAnimation { theme: zone.center.host.theme; pace: slot.shown ? "fade" : "exit"; curve: slot.shown ? "fade" : "exit" } }
      Behavior on scale { enabled: zone.editing && zone.center.settled; MotionAnimation { theme: zone.center.host.theme; pace: slot.shown ? "standard" : "exit"; curve: slot.shown ? "settle" : "exit" } }
      Behavior on x { enabled: zone.editing && zone.center.settled && slot.visible; MotionAnimation { theme: zone.center.host.theme; pace: "standard" } }
      Behavior on y { enabled: zone.editing && zone.center.settled && slot.visible; MotionAnimation { theme: zone.center.host.theme; pace: "standard" } }

      // While it's dragged, an empty slot holds its place.
      Rectangle {
        anchors.fill: parent
        radius: zone.center.cardRadius
        color: zone.center.host.theme.fill("quiet")
        border.width: 1.5
        border.color: zone.center.host.theme.fill("strong")
        opacity: slot.dragged ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
      }
      PluginTile {
        anchors.fill: parent
        center: zone.center
        addon: zone.addon
        entry: slot.modelData
        opacity: slot.dragged ? 0 : 1
        Behavior on opacity { MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
        // Editing is not for opening them.
        enabled: !zone.editing
      }
      MouseArea {
        id: editDragMouse
        anchors.fill: parent
        visible: zone.editing
        enabled: zone.editing && slot.shown
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        property real pressX: 0
        property real pressY: 0
        onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
        onPositionChanged: function(mouse) {
          if (!pressed) return
          if (zone.draggedId === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
          if (zone.draggedId === "") zone.beginDrag(slot.modelData.id, false, slot.width, slot.height, pressX, pressY)
          zone.moveDrag(editDragMouse, mouse.x, mouse.y)
        }
        onReleased: function(mouse) {
          if (zone.draggedId !== "") {
            zone.moveDrag(editDragMouse, mouse.x, mouse.y)
            zone.finishDrag()
          }
        }
        onCanceled: zone.endDrag()
      }
      CcEditBadge {
        center: zone.center
        shown: zone.editing && !slot.dragged && slot.shown
        cornerRadius: zone.center.cardRadius
        tip: "Unpin " + slot.modelData.name
        onClicked: { zone.addon.unpin(slot.modelData.id); zone.endDrag() }
      }
    }
  }

  AddonZone {
    id: empty
    visible: zone.order.length === 0
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
}
