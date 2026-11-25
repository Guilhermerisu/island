import QtQuick
import "../../components"

// The control center's one popover for the zones (ControlCenter.openPopover):
// a Popover placed under an anchor in a zone (above it when there is no room,
// within what the page shows of the island, which is the bar's height outside
// edit mode: its layer (ControlCenter) reaches that far, not only to the last
// zone), over the columns, so no zone's clip cuts it.
// The content is made from the component when it opens and destroyed once it
// has faded out. It is as wide as it asks (`implicitWidth`, else the most) up
// to 280 px or its zone's width if that is narrower, and as tall as it asks,
// up to what is in view; it is told its size by `width` and `height`.
// `center` is the ControlCenter.
Item {
  id: layer
  required property var center
  readonly property bool opened: pop.open
  readonly property real maxWidth: 280
  readonly property real pad: 8
  readonly property real edge: 8
  readonly property real gap: 6

  // Where the anchor was and what is in view when it opened, in this item's
  // coordinates: the popover doesn't follow either (it closes on scroll).
  property Item anchorItem: null
  property rect anchorRect: Qt.rect(0, 0, 0, 0)
  property real limitWidth: maxWidth
  property real viewTop: 0
  property real viewBottom: 0
  property Item content: null
  // Under the anchor, else above it.
  readonly property bool below: pop.y >= anchorRect.y

  function show(anchor, component, properties) {
    hide(true)
    if (!anchor || !component || !center.active || center.editMode) return
    var made = component.createObject(body, properties || {})
    if (!made) return
    var corner = anchor.mapToItem(layer, 0, 0)
    anchorRect = Qt.rect(corner.x, corner.y, anchor.width, anchor.height)
    // The zone's width, found up the anchor's parents (ZoneCard has the id).
    var zone = anchor.parent
    while (zone && zone.zoneId === undefined) zone = zone.parent
    limitWidth = Math.min(maxWidth, zone ? zone.width : layer.width)
    var page = center.zoneBoard.scroller
    viewTop = page ? Math.max(0, page.contentY - center.y) : 0
    viewBottom = page ? Math.min(layer.height, page.contentY + page.height - center.y) : layer.height
    anchorItem = anchor
    content = made
    made.width = Qt.binding(function() { return pop.width - 2 * layer.pad })
    made.height = Qt.binding(function() { return pop.height - 2 * layer.pad })
    pop.open = true
  }
  // Closes it; the content goes once the fade is over (or at once for `now`).
  function hide(now) {
    pop.open = false
    anchorItem = null
    if (now) drop()
  }
  function drop() {
    if (content) content.destroy()
    content = null
  }
  // The anchor going away (its zone removed) takes the popover with it.
  onAnchorItemChanged: if (!anchorItem && pop.open) hide()

  Connections {
    target: pop
    function onVisibleChanged() { if (!pop.visible && !pop.open) layer.drop() }
  }
  // A page that scrolls leaves the anchor behind.
  Connections {
    target: layer.center.zoneBoard.scroller
    function onContentYChanged() { if (pop.open) layer.hide() }
  }
  // Esc from inside the content (it may hold the keyboard); the control center
  // handles it otherwise.
  Keys.onEscapePressed: { layer.hide(); layer.center.forceActiveFocus() }

  // A click anywhere else only closes it.
  MouseArea {
    anchors.fill: parent
    enabled: pop.open
    acceptedButtons: Qt.AllButtons
    onPressed: layer.hide()
  }

  Popover {
    id: pop
    theme: layer.center.host.theme
    width: !layer.content ? 0 : layer.content.implicitWidth > 0
      ? Math.min(layer.content.implicitWidth + 2 * layer.pad, layer.limitWidth) : layer.limitWidth
    height: !layer.content ? 0 : Math.min(layer.content.implicitHeight + 2 * layer.pad,
      Math.max(0, layer.viewBottom - layer.viewTop - 2 * layer.edge))
    x: Math.max(layer.edge, Math.min(layer.anchorRect.x + layer.anchorRect.width / 2 - width / 2, layer.width - width - layer.edge))
    y: {
      var under = layer.anchorRect.y + layer.anchorRect.height + layer.gap
      var over = layer.anchorRect.y - layer.gap - height
      if (under + height <= layer.viewBottom - layer.edge) return under
      if (over >= layer.viewTop + layer.edge) return over
      return Math.max(layer.viewTop + layer.edge, Math.min(under, layer.viewBottom - layer.edge - height))
    }
    transformOrigin: layer.below ? Item.Top : Item.Bottom
    clip: false
    // Takes the clicks and wheel on its own padding, so they neither close it
    // nor scroll the page under it; the content, above, takes its own.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onWheel: function(wheel) { wheel.accepted = true }
    }
    Item {
      id: body
      x: layer.pad
      y: layer.pad
      width: parent.width - 2 * layer.pad
      height: parent.height - 2 * layer.pad
      clip: true
    }
  }
}
