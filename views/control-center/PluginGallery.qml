import QtQuick
import QtQuick.Layouts
import "../../components"

// The plugins, in the add panel (see AddPanel): a card each, like the
// controls'. A plugin goes in the control grid as a tile ("plugins.<id>", see
// Controls.isPluginTile) or in the Plugins zone (see PluginsZone); a card
// leaves once it's in either. Drag it onto either to put it where it's
// dropped: the drag goes through whichever one the pointer is over (the
// grid's ControlLayout or the PluginsZone), handed from one to the other on
// the way. Its + adds it to the grid, or pins it while the grid's zone is
// away. `panel` is the AddPanel.
ColumnLayout {
  id: gallery
  required property var panel
  readonly property var cc: panel.center
  readonly property var controls: cc.controls
  // The Plugins addon, once it's on: it has the list of plugins.
  readonly property var addon: cc.host.addons.root("plugins")
  readonly property string zoneId: "addon:plugins/pinned"
  // The grid and the zone, while each is in the Control Center.
  readonly property var layout: panel.hasControls ? panel.layout : null
  readonly property var zone: cc.pluginsZone
  readonly property bool zoneAway: cc.zones.absent.indexOf(zoneId) !== -1

  function gridKey(id) { return "plugins." + id }
  function inGrid(id) { return controls.isShown(gridKey(id)) }
  // Pins are kept while the zone is away, and pinning brings it and them
  // back, so with it away a pinned plugin can still be pinned.
  function inZone(id) { return !!addon && !zoneAway && addon.pinnedIds.indexOf(id) !== -1 }
  function canGrid(id) { return panel.hasControls && !inGrid(id) }
  readonly property var plugins: !addon ? [] : addon.all.filter(function(entry) {
    return !gallery.inGrid(entry.id) && !gallery.inZone(entry.id)
  })

  // The plugin being dragged, and the grid or zone taking the drag.
  property string draggedId: ""
  property var target: null
  // While a drag has brought the zone in; it goes again if the card isn't
  // dropped on it.
  property bool zoneForDrag: false
  property real dragWidth: 0
  property real dragHeight: 0

  // Whether (x, y) of `source` is over `item`, with `slack` below it (the
  // zone is only as tall as its tiles).
  function over(item, source, x, y, slack) {
    if (!item) return false
    var point = source.mapToItem(item, x, y)
    return point.x >= 0 && point.x <= item.width && point.y >= 0 && point.y <= item.height + slack
  }
  function beginOn(next, grabX, grabY) {
    target = next
    if (next === layout) layout.beginDrag(gridKey(draggedId), true, dragWidth, dragHeight, grabX, grabY)
    else zone.beginDrag(draggedId, true, dragWidth, dragHeight, grabX, grabY)
  }
  // Starts on the one under the pointer, else the grid where it can go,
  // else the zone (brought in for it if away). False until the zone, just
  // brought in, has made itself; the next move tries again.
  function beginDrag(id, width, height, grabX, grabY, source, x, y) {
    draggedId = id
    dragWidth = width
    dragHeight = height
    var next = zone && !inZone(id) && over(zone, source, x, y, cc.tileHeight + cc.gap) ? zone
      : layout && canGrid(id) ? layout : null
    if (!next) {
      if (!zone) {
        zoneForDrag = true
        cc.zones.ensure(zoneId)
      }
      if (!zone) { draggedId = ""; return false }
      next = zone
    }
    beginOn(next, grabX, grabY)
    return true
  }
  function moveDrag(source, x, y) {
    var next = target === layout && zone && !inZone(draggedId) && over(zone, source, x, y, cc.tileHeight + cc.gap) ? zone
      : target === zone && layout && canGrid(draggedId) && over(layout, source, x, y, 0) ? layout
      : target
    if (next !== target) {
      var grabX = cc.dragProxy.grabX
      var grabY = cc.dragProxy.grabY
      target.endDrag(true)
      beginOn(next, grabX, grabY)
    }
    target.moveDrag(source, x, y)
  }
  function finishDrag(source, x, y) {
    moveDrag(source, x, y)
    var landedInZone = target === zone && zone.dropActive
    target.finishDrag()
    settleDrag(landedInZone)
  }
  function cancelDrag() {
    if (target) target.endDrag()
    settleDrag(false)
  }
  function settleDrag(landedInZone) {
    if (zoneForDrag && !landedInZone) cc.zones.remove(zoneId)
    zoneForDrag = false
    draggedId = ""
    target = null
  }
  // The +: into the grid while it can go there, else pinned.
  function add(id) {
    if (canGrid(id)) {
      controls.setShown(gridKey(id), true)
    } else {
      addon.pin(id)
      cc.zones.ensure(zoneId)
    }
  }

  spacing: 8

  GridLayout {
    Layout.fillWidth: true
    visible: gallery.plugins.length > 0
    columns: gallery.panel.cardColumns
    columnSpacing: 0
    rowSpacing: 0
    Repeater {
      model: gallery.plugins
      delegate: Item {
        id: card
        required property var modelData
        Layout.preferredWidth: gallery.panel.cardWidth
        Layout.preferredHeight: gallery.cc.tileHeight + 8
        scale: dragMouse.pressed ? 0.98 : 1
        Behavior on scale { MotionAnimation { theme: gallery.cc.host.theme; pace: dragMouse.pressed ? "press" : "standard" } }
        CcTile {
          anchors.fill: parent
          anchors.margins: 4
          enabled: false
          center: gallery.cc
          icon: gallery.addon.iconOf(card.modelData.id).text
          iconFamily: gallery.addon.iconOf(card.modelData.id).family
          title: card.modelData.name
          subtitle: card.modelData.id
          checked: card.modelData.enabled
        }
        MouseArea {
          id: dragMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          preventStealing: true
          property real pressX: 0
          property real pressY: 0
          onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            if (gallery.draggedId === "") {
              if (Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
              // Held where it was taken (the card is inset by 4).
              if (!gallery.beginDrag(card.modelData.id, card.width - 8, card.height - 8, pressX - 4, pressY - 4, dragMouse, mouse.x, mouse.y)) return
            }
            if (gallery.draggedId === card.modelData.id) gallery.moveDrag(dragMouse, mouse.x, mouse.y)
          }
          onReleased: function(mouse) {
            if (gallery.draggedId === card.modelData.id) gallery.finishDrag(dragMouse, mouse.x, mouse.y)
            else if (gallery.zoneForDrag) gallery.settleDrag(false)
          }
          onCanceled: if (gallery.draggedId === card.modelData.id || gallery.zoneForDrag) gallery.cancelDrag()
        }
        Item {
          anchors.fill: parent
          anchors.margins: 4
          CcEditBadge {
            center: gallery.cc
            adding: true
            shown: gallery.draggedId !== card.modelData.id
            cornerRadius: gallery.cc.cardRadius
            tip: (gallery.canGrid(card.modelData.id) ? "Add " : "Pin ") + card.modelData.name
            onClicked: gallery.add(card.modelData.id)
          }
        }
        Tooltip { theme: gallery.cc.host.theme; text: "Drag to Controls or Plugins, or " + (gallery.canGrid(card.modelData.id) ? "add " : "pin ") + card.modelData.name }
      }
    }
  }
  Text {
    visible: gallery.plugins.length === 0
    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.bottomMargin: 8
    horizontalAlignment: Text.AlignHCenter
    text: !gallery.addon ? "Turn on the Plugins addon to add plugins"
      : gallery.addon.all.length ? "All plugins have been added"
      : gallery.addon.loading ? "Loading…" : "No plugins added"
    color: gallery.cc.textMuted
    font.family: gallery.cc.host.theme.textFontFamily
    font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.size.body)
    font.pixelSize: gallery.cc.host.theme.size.body
  }
}
