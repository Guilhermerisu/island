import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"
import "gridLayout.js" as Grid

// The control center's grid of controls, and editing it: in edit mode the
// cards can be dragged to reorder them, dragged out onto the add panel below
// to remove them, or dragged in from the panel to add them. The order is saved
// in the island's settings. `center` is the ControlCenter.
//
// `zoneSize` (set by ZoneCard) is its size, edited in place in all three: Normal is
// the grid; Small the same grid of short tiles (CcCompactTile, two to a row)
// and thin sliders (CcThinSlider, with a › to the sources of Sound and the
// microphone); XSmall round pips wrapped onto as many lines as the width needs
// (CcPipRow, a ring of the level on the sliders'). None of them scrolls: the
// grid is as tall as its cards and the page of the island scrolls. The pickers of Normal's cards are, in the compact sizes, the
// popover of CcLevelPopover. `zoneRoom` is the height the zone was given
// (informative, never the grid's: its height is the grid's).
// In edit mode each size is edited where it is: every card, tile or pip is a
// CcSlot (its −, its drag), and one order, one drop and one drag proxy serve
// the three: `slots` says where the slots of the size are (the grid's cards,
// the pips of CcPipRow), `viewItem` what shows them and the drop is over.
ColumnLayout {
  id: layout
  required property var center
  property string zoneSize: "normal"
  property real zoneRoom: Number.POSITIVE_INFINITY
  readonly property bool xsmall: zoneSize === "xsmall"
  readonly property bool small: zoneSize === "small"
  readonly property bool normal: !xsmall && !small
  // Small's rows: a tile and a slider.
  readonly property real compactTileHeight: 40
  readonly property real compactSliderHeight: 32
  readonly property var controls: center.controls
  readonly property DragProxy dragProxy: center.dragProxy
  readonly property bool editMode: center.editMode
  spacing: center.gap

  // The add panel (see ControlCenter.addPanel) drags cards in through it.
  Component.onCompleted: center.controlLayout = layout
  Component.onDestruction: if (center.controlLayout === layout) center.controlLayout = null

  property string draggedKey: ""
  property bool dragFromGallery: false
  property bool dropActive: false
  property bool removeDropActive: false
  property point dragPoint: Qt.point(0, 0)
  property var previewOrder: []
  // Room around the grid in edit mode for the − badges on the cards' corners
  // (a little less in the compact sizes, whose zone clips at its edges).
  readonly property real inset: editMode ? (normal ? 8 : 6) : 0
  // Where the slots are, in what, and what shows them (its size is the
  // drop's): the grid's cards, or the pips of CcPipRow's lines. Both start at
  // the origin of `viewItem`.
  readonly property var slots: xsmall ? pipRow.positions : cardArea.positions
  readonly property Item slotsItem: xsmall ? pipRow.content : cardArea
  readonly property Item viewItem: xsmall ? pipRow : cardView
  // Off for the first layout each time the control center opens, so cards
  // appear and move only for changes made while it's showing.
  property bool cardsSettled: false
  Connections {
    target: layout.center
    function onActiveChanged() {
      layout.cardsSettled = false
      if (layout.center.active) cardsSettleTimer.restart()
      else layout.endDrag()
    }
  }
  Timer {
    id: cardsSettleTimer
    interval: layout.center.host.theme.motionDuration("morph")
    onTriggered: layout.cardsSettled = layout.center.active
  }
  // A slider standing up or lying down reshapes in place; only then, as a
  // card's size also follows the column while a handle is dragged.
  property bool flipping: false
  Timer {
    id: flipTimer
    interval: layout.center.host.theme.motionDuration("standard")
    onTriggered: layout.flipping = false
  }
  // The room the Sound and Microphone pickers add below their sliders,
  // eased (after the first layout) so the card and the ones under it follow
  // the rows in and out instead of snapping. Both also hold a level meter (10).
  readonly property real outputsRoom: center.outputsOpen && !center.editMode ? controls.outputs.length * 40 + 10 : 0
  readonly property real inputsRoom: center.inputsOpen && !center.editMode ? controls.inputs.length * 40 + 10 : 0
  property real outputsExtra: outputsRoom
  property real inputsExtra: inputsRoom
  Behavior on outputsExtra { enabled: layout.cardsSettled; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }
  Behavior on inputsExtra { enabled: layout.cardsSettled; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }
  onEditModeChanged: {
    endDrag()
    if (editMode) center.addPanel.resetScroll()
  }

  readonly property var visibleControlKeys: {
    var order = layout.center.editMode && layout.previewOrder.length ? layout.previewOrder : controls.keys
    return order.filter(function(key) {
      return (controls.isShown(key) || (layout.dragFromGallery && layout.dropActive && key === layout.draggedKey))
        && (!layout.controls.isMicrophoneControl(key) || layout.controls.controlPresent(key))
        && (layout.center.editMode || layout.controls.controlPresent(key))
    })
  }
  // `keepProxy` when finishDrag settles the proxy itself.
  function endDrag(keepProxy) {
    if (!keepProxy && draggedKey !== "" && dragProxy.lifted) dragProxy.release(null)
    draggedKey = ""
    dragFromGallery = false
    dropActive = false
    removeDropActive = false
    previewOrder = controls.keys.slice()
  }
  // `grabX`/`grabY`: where in the card the pointer went down, so the proxy
  // lifts from where the card is instead of jumping to centre on the
  // pointer. Without them (the gallery's small choices) it centres. A card
  // dragged in from the panel is made the size of the size's own: a pip, or a
  // tile or slider of the compact grid.
  function beginDrag(key, fromGallery, width, height, grabX, grabY) {
    previewOrder = controls.keys.slice()
    dragFromGallery = fromGallery
    draggedKey = key
    if (fromGallery && !normal) {
      var wide = small && controls.canBeVertical(key)
      width = xsmall ? pipRow.pipSize : wide ? cardArea.width - 2 * inset : (cardArea.width - 2 * inset - center.gap) / 2
      height = xsmall ? pipRow.pipSize : wide ? compactSliderHeight : compactTileHeight
    }
    dragProxy.grabX = grabX === undefined ? width / 2 : Math.min(grabX, width)
    dragProxy.grabY = grabY === undefined ? height / 2 : Math.min(grabY, height)
    // The proxy's corners, which are the cards' unless it is a pip or short.
    dragProxy.radius = xsmall ? width / 2 : Math.min(center.cardRadius, height / 2)
    dragProxy.lift(key, fromGallery, width, height, proxyComponent(key))
  }
  function proxyComponent(key) {
    return xsmall ? pipCard : small ? (controls.canBeVertical(key) ? thinSlider : compactTile) : center.controlComponent(key)
  }
  function moveDrag(source, x, y) {
    dragProxy.follow(source, x, y)
    dragPoint = source.mapToItem(viewItem, x, y)
    var panel = center.addPanel
    var panelPoint = source.mapToItem(panel, x, y)
    removeDropActive = !dragFromGallery && panel.visible
      && panelPoint.x >= 0 && panelPoint.x <= panel.width
      && panelPoint.y >= 0 && panelPoint.y <= panel.height
    updateDropPosition()
  }
  function updateDropPosition() {
    dropActive = !removeDropActive && dragPoint.x >= 0 && dragPoint.x <= viewItem.width
      && dragPoint.y >= 0 && dragPoint.y <= viewItem.height
    if (!dropActive) return
    if (dragFromGallery) previewInsertAt(dragPoint.x, dragPoint.y)
    else previewMoveAt(dragPoint.x, dragPoint.y)
  }
  function previewInsertAt(x, y) {
    var own = slots[draggedKey]
    // Keep the insertion stable while the pointer is over its placeholder.
    if (own && x >= own.x && x <= own.x + own.width && y >= own.y && y <= own.y + own.height) return
    var keys = visibleControlKeys.filter(function(key) { return key !== layout.draggedKey })
    var target = ""
    for (var i = 0; i < keys.length; i++) {
      var slot = slots[keys[i]]
      if (!slot) continue
      var wide = !xsmall && controls.controlWide(keys[i]) && !controls.isVertical(keys[i])
      // The pips, like the cards, wrap: a line first, then x within it.
      var before = y < slot.y || (y < slot.y + slot.height && (wide ? y < slot.y + slot.height / 2 : x < slot.x + slot.width / 2))
      if (before) {
        target = keys[i]
        break
      }
    }
    var order = previewOrder.filter(function(key) { return key !== layout.draggedKey })
    var index = target ? order.indexOf(target) : keys.length ? order.indexOf(keys[keys.length - 1]) + 1 : order.length
    order.splice(index, 0, draggedKey)
    previewOrder = order
  }
  function finishDrag() {
    var key = draggedKey
    if (key !== "" && removeDropActive) {
      controls.setShown(key, false)
    } else if (key !== "" && dropActive) {
      controls.saveOrder(previewOrder)
      if (dragFromGallery) controls.setShown(key, true)
    }
    endDrag(true)
    // The slot it lands in, read after endDrag so it's the saved order (or
    // its old place, when dropped outside the grid); none once removed.
    var slot = key !== "" ? slots[key] : null
    dragProxy.release(slot ? settleTarget(slot) : null)
  }
  // Where the proxy settles for a slot, in its layer.
  function settleTarget(slot) {
    var target = slotsItem.mapToItem(dragProxy.parent, slot.x, slot.y)
    return { x: target.x, y: target.y, width: slot.width, height: slot.height }
  }
  function previewMoveAt(x, y) {
    if (x < 0 || y < 0 || x > slotsItem.width || y > slotsItem.height) return
    for (var i = 0; i < visibleControlKeys.length; i++) {
      var key = visibleControlKeys[i]
      if (key === draggedKey) continue
      var slot = slots[key]
      if (!slot) continue
      var marginX = Math.min(30, slot.width * 0.2)
      var marginY = Math.min(18, slot.height * 0.2)
      if (x < slot.x + marginX || x > slot.x + slot.width - marginX ||
          y < slot.y + marginY || y > slot.y + slot.height - marginY) continue
      var order = previewOrder.slice()
      var from = order.indexOf(draggedKey)
      var to = order.indexOf(key)
      if (from < 0 || to < 0) return
      order.splice(from, 1)
      order.splice(to, 0, draggedKey)
      previewOrder = order
      return
    }
  }

  CcPipRow {
    id: pipRow
    visible: layout.xsmall
    Layout.fillWidth: true
    center: layout.center
    owner: layout
  }
  Component {
    id: pipCard
    CcPip { center: parent.center; controlKey: parent.controlKey; anchors.fill: parent }
  }
  Component {
    id: compactTile
    CcCompactTile { center: layout.center; controlKey: parent.controlKey; anchors.fill: parent }
  }
  Component {
    id: thinSlider
    CcThinSlider { center: layout.center; controlKey: parent.controlKey; anchors.fill: parent }
  }

  Item {
    id: cardView
    visible: !layout.xsmall
    Layout.fillWidth: true
    // The room around the cards in edit mode (for the −, on their corners) is
    // lent by the gaps around the grid: the zone is as tall as outside it,
    // plus its bar.
    Layout.topMargin: -layout.inset
    Layout.bottomMargin: -layout.inset
    // The grid's height, whatever the size and mode; in edit mode room for at
    // least a card (an empty grid has room for its words).
    Layout.preferredHeight: Math.max(cardArea.positions.height, !layout.center.editMode ? 0
      : (layout.normal ? layout.center.tileHeight : layout.compactTileHeight) + 2 * layout.inset)
    Text {
      anchors.centerIn: parent
      visible: layout.center.editMode && layout.visibleControlKeys.length === 0
      text: "Drag a control here"
      color: layout.center.textMuted
      font.family: layout.center.host.theme.textFontFamily
      font.letterSpacing: layout.center.host.theme.tracking(layout.center.host.theme.textFontFamily, layout.center.host.theme.size.body)
      font.pixelSize: layout.center.host.theme.size.body
    }
    Item {
      id: cardArea
      width: cardView.width
      height: positions.height
      readonly property var positions: Grid.place(layout.visibleControlKeys.map(function(key) {
        // Small keeps no picker open and no slider upright.
        var vertical = !layout.small && layout.controls.isVertical(key)
        return {
          key: key,
          wide: layout.small ? layout.controls.canBeVertical(key) : layout.controls.controlWide(key),
          vertical: vertical,
          extra: vertical || layout.small ? 0 : key === "sound" ? layout.outputsExtra : key === "microphone" ? layout.inputsExtra : 0
        }
      }), {
        width: width, inset: layout.inset, gap: layout.center.gap,
        tileHeight: layout.small ? layout.compactTileHeight : layout.center.tileHeight,
        sectionHeight: layout.small ? layout.compactSliderHeight : layout.center.sectionHeight
      })
      Repeater {
        // The pips, in XSmall, are CcPipRow's.
        model: layout.xsmall ? [] : layout.controls.known
        delegate: CcSlot {
          id: controlCard
          required property string modelData
          center: layout.center
          place: cardArea.positions[modelData] || null
          // Added and removed cards scale in and out while the others slide.
          animated: layout.cardsSettled
          sliding: layout.center.editMode && layout.cardsSettled
          resizing: layout.flipping
          editing: layout.center.editMode
          dragged: layout.draggedKey === modelData
          onDragBegan: function(grabX, grabY) { layout.beginDrag(modelData, false, width, height, grabX, grabY) }
          onDragMoved: function(source, x, y) { layout.moveDrag(source, x, y) }
          onDragEnded: function(source, x, y) { layout.moveDrag(source, x, y); layout.finishDrag() }
          onDragCanceled: layout.endDrag()
          onRemoved: { layout.controls.setShown(modelData, false); layout.endDrag() }
          Loader {
            anchors.fill: parent
            property var center: layout.center
            property string controlKey: controlCard.modelData
            property bool galleryPreview: false
            sourceComponent: !layout.small ? layout.center.controlComponent(controlCard.modelData)
              : layout.controls.canBeVertical(controlCard.modelData) ? thinSlider : compactTile
          }
          // Slider cards flip between horizontal and upright; the glyph and
          // tip name what a click turns it into.
          overlay: CcEditBadge {
            readonly property bool vertical: layout.controls.isVertical(controlCard.modelData)
            center: layout.center
            corner: "right"
            glyph: vertical ? "↔" : "↕"
            shown: layout.center.editMode && !controlCard.dragged && controlCard.shown && layout.normal && layout.controls.canBeVertical(controlCard.modelData)
            cornerRadius: controlCard.cornerRadius
            tip: vertical ? "Horizontal Slider" : "Vertical Slider"
            onClicked: {
              layout.flipping = true
              flipTimer.restart()
              layout.controls.setVertical(controlCard.modelData, !vertical)
              layout.endDrag()
            }
          }
        }
      }
    }
  }

  Rectangle {
    visible: !layout.center.editMode && layout.visibleControlKeys.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: layout.xsmall ? layout.center.zoneXsHeight : layout.center.tileHeight
    radius: layout.center.cardRadius
    color: layout.center.card
    border.width: 1
    border.color: layout.center.edge
    Text {
      anchors.centerIn: parent
      text: "Click the pencil to add controls"
      color: layout.center.textMuted
      font.family: layout.center.host.theme.textFontFamily
      font.letterSpacing: layout.center.host.theme.tracking(layout.center.host.theme.textFontFamily, layout.center.host.theme.size.callout)
      font.pixelSize: layout.center.host.theme.size.callout
    }
  }
}
