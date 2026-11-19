import QtQuick

// macOS's scroll latching: a scroll that moved the page stays on the page,
// even as the page brings a slider or an inner list under the pointer, until
// the wheel rests for a moment. Parent it to the Flickable itself and let
// what's in it take the wheel only while `engaged` is false:
//
//   WheelLatch { id: latch; flickable: page; parent: page }
//   MouseArea { onWheel: function(e) { if (latch.engaged) { e.accepted = false; return } ... } }
//   ListView { interactive: !latch.engaged }
//
// It watches the wheel without taking it: no buttons, the event passed on.
MouseArea {
  id: latch
  required property Flickable flickable
  readonly property bool engaged: rest.running
  anchors.fill: parent
  z: 1000
  acceptedButtons: Qt.NoButton
  Timer { id: rest; interval: 350 }
  // The page moved: a scroll of its own (or one handed up by what's in it).
  Connections {
    target: latch.flickable
    function onContentYChanged() { rest.restart() }
  }
  // At the page's end, the scroll goes on into the list under the pointer
  // (Settings) rather than stopping there. Off where what's under the
  // pointer is a slider (the control center): the end shouldn't move a value.
  property bool handOffAtEnds: false
  // Still going (the page may be at its end): the latch holds, or lets go
  // when it hands off.
  onWheel: function(wheel) {
    var down = wheel.angleDelta.y < 0
    if (handOffAtEnds && (down ? flickable.atYEnd : flickable.atYBeginning)) rest.stop()
    else if (rest.running) rest.restart()
    wheel.accepted = false
  }
}
