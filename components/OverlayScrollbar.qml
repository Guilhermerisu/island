import QtQuick

// macOS's overlay scrollbar: a thin thumb that shows while a list scrolls or
// the pointer is at its edge, fades out after, and only when there's more to
// see. It widens under the pointer and can be dragged. Parent it to the
// Flickable itself (not its content) so it stays put while the content moves:
//
//   OverlayScrollbar { flickable: list; parent: list; theme: host.theme }
Item {
  id: bar
  required property Flickable flickable
  property var theme: null

  readonly property bool needed: flickable.contentHeight > flickable.height + 1
  readonly property bool engaged: edgeHover.hovered || drag.pressed
  property bool awake: false
  readonly property real thickness: engaged ? 9 : 6
  readonly property real ratio: Math.min(1, flickable.visibleArea.heightRatio)
  readonly property real track: height - 4
  readonly property real thumbLength: Math.max(28, track * ratio)
  // Where the thumb sits along its track, 0 at the top and 1 at the bottom.
  readonly property real progress: ratio >= 1 ? 0
    : Math.max(0, Math.min(1, flickable.visibleArea.yPosition / (1 - ratio)))

  function wake() {
    if (!needed) return
    awake = true
    sleep.restart()
  }

  anchors.fill: parent
  z: 100
  visible: needed && opacity > 0.01
  opacity: needed && (awake || engaged) ? 1 : 0
  Behavior on opacity {
    MotionAnimation { theme: bar.theme; pace: bar.awake || bar.engaged ? "quick" : "standard"; curve: "fade" }
  }

  Connections {
    target: bar.flickable
    function onContentYChanged() { bar.wake() }
  }
  Timer { id: sleep; interval: 900; onTriggered: bar.awake = false }

  // The edge the pointer wakes it from; it only takes clicks once it's shown,
  // so rows reaching the edge stay clickable while it's hidden.
  Item {
    id: edge
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: 14
    HoverHandler { id: edgeHover; enabled: bar.needed; onHoveredChanged: if (!hovered) bar.wake() }

    // While engaged, a faint track behind the thumb, as macOS does.
    Rectangle {
      x: thumb.x - 1
      y: 1
      width: thumb.width + 2
      height: parent.height - 2
      radius: width / 2
      color: bar.theme ? bar.theme.fill("quiet") : "transparent"
      opacity: bar.engaged ? 1 : 0
      Behavior on opacity { MotionAnimation { theme: bar.theme; pace: "quick"; curve: "fade" } }
    }

    Rectangle {
      id: thumb
      x: parent.width - width - 2
      y: 2 + bar.progress * (bar.track - bar.thumbLength)
      width: bar.thickness
      height: bar.thumbLength
      radius: width / 2
      color: bar.theme ? bar.theme.withAlpha(bar.theme.text, bar.engaged ? 0.55 : 0.4) : "#888888"
      Behavior on width { MotionAnimation { theme: bar.theme; pace: "quick" } }
    }

    MouseArea {
      id: drag
      anchors.fill: parent
      enabled: bar.needed && bar.opacity > 0.5
      preventStealing: true
      property real startY: 0
      property real startContentY: 0
      onPressed: function(mouse) {
        // A press beside the thumb jumps it there first, then drags.
        if (mouse.y < thumb.y || mouse.y > thumb.y + thumb.height) {
          var f = bar.flickable
          var to = (mouse.y - 2 - bar.thumbLength / 2) / Math.max(1, bar.track - bar.thumbLength)
          f.contentY = f.originY + Math.max(0, Math.min(1, to)) * (f.contentHeight - f.height)
        }
        startY = mouse.y
        startContentY = bar.flickable.contentY
      }
      onPositionChanged: function(mouse) {
        var f = bar.flickable
        var scrollable = f.contentHeight - f.height
        var perPixel = scrollable / Math.max(1, bar.track - bar.thumbLength)
        f.contentY = Math.max(f.originY, Math.min(f.originY + scrollable, startContentY + (mouse.y - startY) * perPixel))
      }
    }
  }
}
