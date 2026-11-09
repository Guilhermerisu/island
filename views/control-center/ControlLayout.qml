import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"
import "gridLayout.js" as Grid

// The control center's grid of controls, and editing it: in edit mode the
// cards can be dragged to reorder them, dragged out onto the add panel below
// to remove them, or dragged in from the panel to add them. The order is saved
// in the island's settings. `center` is the ControlCenter.
ColumnLayout {
  id: layout
  required property var center
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
  // Room around the grid in edit mode for the − badges on the cards' corners.
  readonly property real inset: editMode ? 8 : 0
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
    controlLayoutScroll.contentY = 0
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
  // pointer. Without them (the gallery's small choices) it centres.
  function beginDrag(key, fromGallery, width, height, grabX, grabY) {
    previewOrder = controls.keys.slice()
    dragFromGallery = fromGallery
    draggedKey = key
    dragProxy.grabX = grabX === undefined ? width / 2 : grabX
    dragProxy.grabY = grabY === undefined ? height / 2 : grabY
    dragProxy.lift(key, fromGallery, width, height, center.controlComponent(key))
  }
  function moveDrag(source, x, y) {
    dragProxy.follow(source, x, y)
    dragPoint = source.mapToItem(controlLayoutScroll, x, y)
    var panel = center.addPanel
    var panelPoint = source.mapToItem(panel, x, y)
    removeDropActive = !dragFromGallery && panel.visible
      && panelPoint.x >= 0 && panelPoint.x <= panel.width
      && panelPoint.y >= 0 && panelPoint.y <= panel.height
    updateDropPosition()
  }
  function updateDropPosition() {
    dropActive = !removeDropActive && dragPoint.x >= 0 && dragPoint.x <= controlLayoutScroll.width
      && dragPoint.y >= 0 && dragPoint.y <= controlLayoutScroll.height
    if (!dropActive) return
    var y = dragPoint.y + controlLayoutScroll.contentY
    if (dragFromGallery) previewInsertAt(dragPoint.x, y)
    else previewMoveAt(dragPoint.x, y)
  }
  function previewInsertAt(x, y) {
    var slots = cardArea.positions
    var own = slots[draggedKey]
    // Keep the insertion stable while the pointer is over its placeholder.
    if (own && x >= own.x && x <= own.x + own.width && y >= own.y && y <= own.y + own.height) return
    var keys = visibleControlKeys.filter(function(key) { return key !== layout.draggedKey })
    var target = ""
    for (var i = 0; i < keys.length; i++) {
      var slot = slots[keys[i]]
      if (!slot) continue
      var wide = controls.controlWide(keys[i]) && !controls.isVertical(keys[i])
      if (y < slot.y || (y < slot.y + slot.height && (wide
          ? y < slot.y + slot.height / 2 : x < slot.x + slot.width / 2))) {
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
    var slot = key !== "" ? cardArea.positions[key] : null
    dragProxy.release(slot ? settleTarget(slot) : null)
  }
  // Where the proxy settles for a slot, in its layer. The grid clips while
  // it scrolls, so a slot scrolled out of view is clamped to the visible
  // grid's edge: the proxy eases to the edge it went under and fades there
  // rather than settling somewhere the card itself can't be seen.
  function settleTarget(slot) {
    var layer = dragProxy.parent
    var target = cardArea.mapToItem(layer, slot.x, slot.y)
    var view = controlLayoutScroll.mapToItem(layer, 0, 0)
    var top = view.y
    var bottom = view.y + controlLayoutScroll.height - slot.height
    return { x: target.x, y: Math.max(top, Math.min(Math.max(top, bottom), target.y)), width: slot.width, height: slot.height }
  }
  Timer {
    interval: 25
    repeat: true
    running: layout.draggedKey !== "" && layout.dropActive
    onTriggered: {
      var step = layout.dragPoint.y < 32 ? -8 : layout.dragPoint.y > controlLayoutScroll.height - 32 ? 8 : 0
      var limit = Math.max(0, controlLayoutScroll.contentHeight - controlLayoutScroll.height)
      var next = Math.max(0, Math.min(limit, controlLayoutScroll.contentY + step))
      if (next !== controlLayoutScroll.contentY) {
        controlLayoutScroll.contentY = next
        layout.updateDropPosition()
      }
    }
  }
  function previewMoveAt(x, y) {
    if (x < 0 || y < 0 || x > cardArea.width || y > cardArea.height) return
    var slots = cardArea.positions
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

  Flickable {
    id: controlLayoutScroll
    Layout.fillWidth: true
    // In edit mode it fits the grid, up to a scrolling 300.
    Layout.preferredHeight: layout.center.editMode
      ? Math.min(300, Math.max(cardArea.height, layout.center.tileHeight + 2 * layout.inset))
      : cardArea.positions.height
    contentWidth: width
    contentHeight: cardArea.height
    interactive: layout.center.editMode
    clip: layout.center.editMode
    boundsBehavior: Flickable.StopAtBounds
    Text {
      parent: controlLayoutScroll
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
      width: controlLayoutScroll.width
      height: positions.height
      readonly property var positions: Grid.place(layout.visibleControlKeys.map(function(key) {
        var vertical = layout.controls.isVertical(key)
        return {
          key: key,
          wide: layout.controls.controlWide(key),
          vertical: vertical,
          extra: vertical ? 0 : key === "sound" ? layout.outputsExtra : key === "microphone" ? layout.inputsExtra : 0
        }
      }), { width: width, inset: layout.inset, gap: layout.center.gap, tileHeight: layout.center.tileHeight, sectionHeight: layout.center.sectionHeight })
      Repeater {
        model: layout.controls.known
        delegate: Item {
          id: controlCard
          required property string modelData
          readonly property var slot: cardArea.positions[modelData] || null
          readonly property bool shown: !!slot
          // Where it last was, so a card leaving the grid fades out in place.
          property var lastSlot: null
          onSlotChanged: if (slot) lastSlot = slot
          Component.onCompleted: lastSlot = slot
          x: lastSlot ? lastSlot.x : 0
          y: lastSlot ? lastSlot.y : 0
          width: lastSlot ? lastSlot.width : 0
          height: lastSlot ? lastSlot.height : 0
          readonly property bool dragged: layout.draggedKey === modelData
          readonly property real cornerRadius: layout.center.cardRadius
          // Added and removed cards scale in and out while the others slide.
          opacity: shown ? 1 : 0
          scale: shown ? 1 : 0.9
          visible: opacity > 0.01
          Behavior on opacity {
            enabled: layout.cardsSettled
            MotionAnimation { theme: layout.center.host.theme; pace: controlCard.shown ? "fade" : "exit"; curve: controlCard.shown ? "fade" : "exit" }
          }
          Behavior on scale {
            enabled: layout.cardsSettled
            MotionAnimation { theme: layout.center.host.theme; pace: controlCard.shown ? "standard" : "exit"; curve: controlCard.shown ? "settle" : "exit" }
          }
          // A card that was hidden appears in its new place rather than
          // sliding there from where it was last shown.
          Behavior on x { enabled: layout.center.editMode && layout.cardsSettled && controlCard.visible; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }
          Behavior on y { enabled: layout.center.editMode && layout.cardsSettled && controlCard.visible; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }
          Behavior on width { enabled: layout.flipping; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }
          Behavior on height { enabled: layout.flipping; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }

          // While it's dragged, an empty slot holds its place.
          Rectangle {
            anchors.fill: parent
            radius: controlCard.cornerRadius
            color: layout.center.host.theme.fill("quiet")
            border.width: 1.5
            border.color: layout.center.host.theme.fill("strong")
            opacity: controlCard.dragged ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { MotionAnimation { theme: layout.center.host.theme; pace: "fade"; curve: "fade" } }
          }
          Loader {
            anchors.fill: parent
            opacity: controlCard.dragged ? 0 : 1
            Behavior on opacity { MotionAnimation { theme: layout.center.host.theme; pace: "fade"; curve: "fade" } }
            property var center: layout.center
            property string controlKey: controlCard.modelData
            property bool galleryPreview: false
            sourceComponent: layout.center.controlComponent(controlCard.modelData)
          }
          MouseArea {
            id: editDragMouse
            anchors.fill: parent
            visible: layout.center.editMode
            enabled: layout.center.editMode && controlCard.shown
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            property real pressX: 0
            property real pressY: 0
            onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
            onPositionChanged: function(mouse) {
              if (!pressed) return
              if (layout.draggedKey === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
              if (layout.draggedKey === "") layout.beginDrag(controlCard.modelData, false, controlCard.width, controlCard.height, pressX, pressY)
              layout.moveDrag(editDragMouse, mouse.x, mouse.y)
            }
            onReleased: function(mouse) {
              if (layout.draggedKey !== "") {
                layout.moveDrag(editDragMouse, mouse.x, mouse.y)
                layout.finishDrag()
              }
            }
            onCanceled: layout.endDrag()
          }
          CcEditBadge {
            center: layout.center
            shown: layout.center.editMode && !controlCard.dragged && controlCard.shown
            cornerRadius: controlCard.cornerRadius
            tip: "Remove"
            onClicked: { layout.controls.setShown(controlCard.modelData, false); layout.endDrag() }
          }
          // Slider cards flip between horizontal and upright; the glyph and
          // tip name what a click turns it into.
          CcEditBadge {
            readonly property bool vertical: layout.controls.isVertical(controlCard.modelData)
            center: layout.center
            corner: "right"
            glyph: vertical ? "↔" : "↕"
            shown: layout.center.editMode && !controlCard.dragged && controlCard.shown && layout.controls.canBeVertical(controlCard.modelData)
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
    Layout.preferredHeight: layout.center.tileHeight
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
