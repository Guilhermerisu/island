import QtQuick
import "../../components"

// The control center's XSmall controls: pips (CcPip), one per control in the
// grid's order, wrapped onto as many lines as the column's width needs (two
// as a rule, three in a narrow column) and never scrolled. In edit mode each
// pip is a CcSlot (its −, dragged to reorder, or out to remove, or in from the
// add panel): the order, the drag and the drop are the ControlLayout's, which
// is `owner`; this row says where the pips are (`positions`). `center` is the
// ControlCenter.
Item {
  id: row
  required property var center
  required property var owner
  // The controls shown, in order (what a drag in progress would make it).
  readonly property var keys: owner.visibleControlKeys
  // CcPip's size, and the room between pips.
  readonly property real pipSize: 44
  readonly property real spacing: 6
  // The room edit mode leaves at the sides for the −. Lines always break as
  // they do in edit mode, so entering it never moves a pip to another line.
  readonly property real editInset: 6
  // Above and below the lines: what makes a single line the zone's 58.
  readonly property real margin: (center.zoneXsHeight - pipSize) / 2
  readonly property int perLine: Math.max(1, Math.floor((width - 2 * editInset + spacing) / (pipSize + spacing)))
  readonly property int lines: Math.max(1, Math.ceil(keys.length / perLine))
  implicitHeight: Math.max(center.zoneXsHeight, lines * pipSize + (lines - 1) * spacing + 2 * margin)

  // Where each pip is, in `content`: in lines from the left, after the room
  // edit mode leaves for the −.
  readonly property var positions: {
    var slots = {}
    keys.forEach(function(key, i) {
      slots[key] = {
        x: row.owner.inset + (i % row.perLine) * (row.pipSize + row.spacing),
        y: row.margin + Math.floor(i / row.perLine) * (row.pipSize + row.spacing),
        width: row.pipSize, height: row.pipSize
      }
    })
    return slots
  }
  readonly property Item content: pips

  Item {
    id: pips
    anchors.fill: parent
    Repeater {
      model: row.owner.xsmall ? row.owner.controls.known : []
      delegate: CcSlot {
        id: pip
        required property string modelData
        center: row.center
        place: row.positions[modelData] || null
        animated: row.owner.cardsSettled
        sliding: row.center.editMode && row.owner.cardsSettled
        editing: row.center.editMode
        dragged: row.owner.draggedKey === modelData
        cornerRadius: row.pipSize / 2
        onDragBegan: function(grabX, grabY) { row.owner.beginDrag(modelData, false, width, height, grabX, grabY) }
        onDragMoved: function(source, x, y) { row.owner.moveDrag(source, x, y) }
        onDragEnded: function(source, x, y) { row.owner.moveDrag(source, x, y); row.owner.finishDrag() }
        onDragCanceled: row.owner.endDrag()
        onRemoved: { row.owner.controls.setShown(modelData, false); row.owner.endDrag() }
        CcPip { center: row.center; controlKey: pip.modelData }
      }
    }
  }
  Text {
    anchors.centerIn: parent
    visible: row.center.editMode && row.keys.length === 0
    text: "Drag a control here"
    color: row.center.textMuted
    font.family: row.center.host.theme.textFontFamily
    font.letterSpacing: row.center.host.theme.tracking(row.center.host.theme.textFontFamily, row.center.host.theme.size.body)
    font.pixelSize: row.center.host.theme.size.body
  }
}
