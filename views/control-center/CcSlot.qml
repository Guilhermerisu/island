import QtQuick
import "../../components"

// One place in a set that is reordered by dragging in edit mode: a control
// card (ControlLayout's grid, its small tiles, its XSmall pips) or a plugin
// (PluginsZone's tiles, chips and badges). It sits where `place` says
// ({ x, y, width, height }, the owner's slot; none when it is not shown, it
// then fades out where it last was) and gives the content the same editing in
// every size: an empty slot while it is dragged, a drag that is told to the
// owner by signals, and the − on its corner. The owner keeps the order and
// the drop (see ControlLayout, PluginsZone). The content is what is put in it.
// `center` is the ControlCenter.
Item {
  id: slot
  required property var center
  property var place: null
  // Fades and scales in and out (for what changes while it shows), slides to
  // a new place, and eases a new size.
  property bool animated: false
  property bool sliding: false
  property bool resizing: false
  property bool editing: false
  property bool dragged: false
  property real cornerRadius: center.cardRadius
  property string tip: "Remove"
  default property alias content: holder.data
  // Over the drag area and the − (a second button on a card).
  property alias overlay: top.data
  readonly property bool shown: !!place
  // Where it last was, so a slot leaving fades out in place.
  property var lastPlace: null
  onPlaceChanged: if (place) lastPlace = place
  Component.onCompleted: lastPlace = place

  // The pointer went down at (grabX, grabY) of the slot and moved: the drag
  // starts. Then it moves (`source` is the area that reads the pointer, for
  // mapToItem), is let go (`dragEnded`, after a last move) or is cancelled.
  signal dragBegan(real grabX, real grabY)
  signal dragMoved(Item source, real x, real y)
  signal dragEnded(Item source, real x, real y)
  signal dragCanceled()
  signal removed()

  x: lastPlace ? lastPlace.x : 0
  y: lastPlace ? lastPlace.y : 0
  width: lastPlace ? lastPlace.width : 0
  height: lastPlace ? lastPlace.height : 0
  opacity: shown ? 1 : 0
  scale: shown ? 1 : 0.9
  visible: opacity > 0.01
  Behavior on opacity {
    id: opacityMotion
    enabled: slot.animated
    MotionAnimation { theme: slot.center.host.theme; pace: towards(opacityMotion.targetValue, slot.shown ? "fade" : "exit"); curve: towards(opacityMotion.targetValue, slot.shown ? "fade" : "exit") }
  }
  Behavior on scale {
    id: scaleMotion
    enabled: slot.animated
    MotionAnimation { theme: slot.center.host.theme; pace: towards(scaleMotion.targetValue, slot.shown ? "standard" : "exit"); curve: towards(scaleMotion.targetValue, slot.shown ? "settle" : "exit") }
  }
  // A slot that was hidden appears in its new place rather than sliding there
  // from where it was last shown.
  Behavior on x { enabled: slot.sliding && slot.visible; MotionAnimation { theme: slot.center.host.theme; pace: "standard" } }
  Behavior on y { enabled: slot.sliding && slot.visible; MotionAnimation { theme: slot.center.host.theme; pace: "standard" } }
  Behavior on width { enabled: slot.resizing; MotionAnimation { theme: slot.center.host.theme; pace: "standard" } }
  Behavior on height { enabled: slot.resizing; MotionAnimation { theme: slot.center.host.theme; pace: "standard" } }

  // While it's dragged, an empty slot holds its place.
  Rectangle {
    anchors.fill: parent
    radius: slot.cornerRadius
    color: slot.center.host.theme.fill("quiet")
    border.width: 1.5
    border.color: slot.center.host.theme.fill("strong")
    opacity: slot.dragged ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { MotionAnimation { theme: slot.center.host.theme; pace: "fade"; curve: "fade" } }
  }
  Item {
    id: holder
    anchors.fill: parent
    opacity: slot.dragged ? 0 : 1
    Behavior on opacity { MotionAnimation { theme: slot.center.host.theme; pace: "fade"; curve: "fade" } }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    visible: slot.editing
    enabled: slot.editing && slot.shown
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    preventStealing: true
    property real pressX: 0
    property real pressY: 0
    property bool started: false
    onPressed: function(e) { pressX = e.x; pressY = e.y; started = false }
    onPositionChanged: function(e) {
      if (!pressed) return
      if (!started) {
        if (Math.pow(e.x - pressX, 2) + Math.pow(e.y - pressY, 2) < 36) return
        started = true
        slot.dragBegan(pressX, pressY)
      }
      slot.dragMoved(mouse, e.x, e.y)
    }
    onReleased: function(e) {
      if (!started) return
      started = false
      slot.dragEnded(mouse, e.x, e.y)
    }
    onCanceled: { started = false; slot.dragCanceled() }
  }
  CcEditBadge {
    center: slot.center
    shown: slot.editing && !slot.dragged && slot.shown
    cornerRadius: slot.cornerRadius
    tip: slot.tip
    onClicked: slot.removed()
  }
  Item { id: top; anchors.fill: parent }
}
