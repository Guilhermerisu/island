import QtQuick
import QtQuick.Layouts
import "../../components"

// The control center's grid of controls, and editing it: in edit mode the
// cards can be dragged to reorder them, dragged out onto the gallery below to
// remove them, or dragged in from the gallery to add them. The order is saved
// in the island's settings. `center` is the ControlCenter.
ColumnLayout {
  id: layout
  required property var center
  readonly property var controls: center.controls
  readonly property bool editMode: center.editMode
  spacing: 10

  property string draggedKey: ""
  property bool dragFromGallery: false
  property bool dropActive: false
  property bool removeDropActive: false
  property point dragPoint: Qt.point(0, 0)
  property var previewOrder: []
  onEditModeChanged: {
    endDrag()
    controlLayoutScroll.contentY = 0
    if (editMode) controlGallery.resetScroll()
  }

  readonly property var visibleControlKeys: {
    var order = layout.center.editMode && layout.previewOrder.length ? layout.previewOrder : controls.keys
    return order.filter(function(key) {
      return (controls.isShown(key) || (layout.dragFromGallery && layout.dropActive && key === layout.draggedKey))
        && (!layout.controls.isMicrophoneControl(key) || layout.controls.controlPresent(key))
        && (layout.center.editMode || layout.controls.controlPresent(key))
    })
  }
  function endDrag() {
    draggedKey = ""
    dragFromGallery = false
    dropActive = false
    removeDropActive = false
    previewOrder = controls.keys.slice()
  }
  function beginDrag(key, fromGallery, width, height) {
    previewOrder = controls.keys.slice()
    dragFromGallery = fromGallery
    draggedKey = key
    dragProxy.width = width
    dragProxy.height = height
  }
  function moveDrag(source, x, y) {
    var point = source.mapToItem(dragLayer, x, y)
    dragProxy.x = point.x - dragProxy.width / 2
    dragProxy.y = point.y - dragProxy.height / 2
    dragPoint = source.mapToItem(controlLayoutScroll, x, y)
    var galleryPoint = source.mapToItem(controlGallery, x, y)
    removeDropActive = !dragFromGallery && controlGallery.visible
      && galleryPoint.x >= 0 && galleryPoint.x <= controlGallery.width
      && galleryPoint.y >= 0 && galleryPoint.y <= controlGallery.height
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
      var wide = controls.controlWide(keys[i])
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
    if (draggedKey !== "" && removeDropActive) {
      controls.setShown(draggedKey, false)
    } else if (draggedKey !== "" && dropActive) {
      controls.saveOrder(previewOrder)
      if (dragFromGallery) controls.setShown(draggedKey, true)
    }
    endDrag()
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
    Layout.preferredHeight: layout.center.editMode ? 300 : cardArea.positions.height
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
      font.pixelSize: 13
    }
    Item {
      id: cardArea
      width: controlLayoutScroll.width
      height: positions.height
      readonly property var positions: {
        var result = {}
        var gap = 10
        var halfWidth = (width - gap) / 2
        var rowY = 0
        var halfUsed = false
        for (var i = 0; i < layout.visibleControlKeys.length; i++) {
          var key = layout.visibleControlKeys[i]
          var wide = layout.controls.controlWide(key)
          var cardHeight = wide ? 100 : 74
          if (key === "sound" && layout.center.outputsOpen && !layout.center.editMode) cardHeight += layout.controls.outputs.length * 40
          if (key === "microphone" && layout.center.inputsOpen && !layout.center.editMode) cardHeight += layout.controls.inputs.length * 40
          if (wide) {
            if (halfUsed) { rowY += 74 + gap; halfUsed = false }
            result[key] = { x: 0, y: rowY, width: width, height: cardHeight }
            rowY += cardHeight + gap
          } else if (halfUsed) {
            result[key] = { x: halfWidth + gap, y: rowY, width: halfWidth, height: 74 }
            rowY += 74 + gap
            halfUsed = false
          } else {
            var nextKey = i + 1 < layout.visibleControlKeys.length ? layout.visibleControlKeys[i + 1] : ""
            var nextIsSmall = nextKey !== "" && !layout.controls.controlWide(nextKey)
            result[key] = { x: 0, y: rowY, width: nextIsSmall ? halfWidth : width, height: 74 }
            if (nextIsSmall) halfUsed = true
            else rowY += 74 + gap
          }
        }
        result.height = Math.max(0, rowY + (halfUsed ? 74 : -gap))
        return result
      }
      Repeater {
        model: layout.controls.known
        delegate: Item {
          id: controlCard
          required property string modelData
          readonly property var slot: cardArea.positions[modelData] || null
          visible: !!slot
          x: slot ? slot.x : 0
          y: slot ? slot.y : 0
          width: slot ? slot.width : 0
          height: slot ? slot.height : 0
          opacity: layout.draggedKey === modelData ? 0.25 : 1
          Behavior on x { enabled: layout.center.editMode; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }
          Behavior on y { enabled: layout.center.editMode; MotionAnimation { theme: layout.center.host.theme; pace: "standard" } }
          Behavior on opacity { MotionAnimation { theme: layout.center.host.theme; pace: "fade"; curve: "fade" } }

          Loader {
            anchors.fill: parent
            property var center: layout.center
            property string controlKey: controlCard.modelData
            property bool galleryPreview: false
            sourceComponent: layout.center.controlComponent(controlCard.modelData)
          }
          MouseArea {
            id: editDragMouse
            anchors.fill: parent
            visible: layout.center.editMode
            enabled: layout.center.editMode
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            property real pressX: 0
            property real pressY: 0
            onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
            onPositionChanged: function(mouse) {
              if (!pressed) return
              if (layout.draggedKey === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
              if (layout.draggedKey === "") layout.beginDrag(controlCard.modelData, false, controlCard.width, controlCard.height)
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
          Rectangle {
            visible: layout.center.editMode
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 0
            anchors.topMargin: 0
            z: 2
            width: 24; height: 24; radius: 12
            color: layout.center.wellHover
            border.width: 1
            border.color: layout.center.edge
            Text { anchors.centerIn: parent; text: "−"; color: layout.center.text; font.pixelSize: 18 }
            Tooltip { theme: layout.center.host.theme; text: "Remove" }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { layout.controls.setShown(controlCard.modelData, false); layout.endDrag() }
            }
          }
        }
      }
    }
  }

  Rectangle {
    visible: !layout.center.editMode && layout.visibleControlKeys.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 74
    radius: 16
    color: layout.center.card
    border.width: 1
    border.color: layout.center.edge
    Text {
      anchors.centerIn: parent
      text: "Click the pencil to add controls"
      color: layout.center.textMuted
      font.family: layout.center.host.theme.textFontFamily
      font.pixelSize: 12
    }
  }

  ControlGallery {
    id: controlGallery
    visible: layout.center.editMode
    Layout.fillWidth: true
    controlCenter: layout.center
    controlLayout: layout
  }

  // Over the whole control center, beside it rather than inside the layout.
  // Sized by bindings, not anchors: anchors could resolve before the new
  // parent is set, and an anchor to a non-sibling is dropped.
  Item {
    id: dragLayer
    parent: layout.center.parent
    x: layout.center.x
    y: layout.center.y
    width: layout.center.width
    height: layout.center.height
    z: 100
    Rectangle {
      id: dragProxy
      visible: layout.draggedKey !== ""
      radius: 16
      color: layout.center.card
      border.width: 1
      border.color: layout.center.accent
      opacity: 0.96
      scale: 1.04
      Loader {
        anchors.fill: parent
        enabled: false
        property var center: layout.center
        property string controlKey: layout.draggedKey
        property bool galleryPreview: layout.dragFromGallery
        sourceComponent: layout.center.controlComponent(layout.draggedKey)
      }
    }
  }
}
