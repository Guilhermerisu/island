pragma ComponentBehavior: Bound
import QtQuick
import "../../components"

// The arrangement canvas: each monitor that's on as a box at its logical
// size (scaled and turned), placed as in Hyprland's layout. Clicking a box
// picks it; dragging moves it, snapping to the others' edges and centres
// with guide lines, and on release it's settled against an edge with no
// overlap (DisplaysAddon.settle). The island's monitor carries a small pill.
// `view` is the SettingsView, `displays` the DisplaysAddon.
Item {
  id: arrangement
  required property var view
  required property var displays
  implicitHeight: 220

  readonly property var boxes: displays.draft.filter(function(e) { return !e.disabled }).map(function(e) {
    return Object.assign({ name: e.name, title: e.title }, displays.box(e))
  })
  function boundsOf(list) {
    if (!list.length) return { x: 0, y: 0, w: 1, h: 1 }
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
    list.forEach(function(b) {
      x0 = Math.min(x0, b.x); y0 = Math.min(y0, b.y)
      x1 = Math.max(x1, b.x + b.w); y1 = Math.max(y1, b.y + b.h)
    })
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
  }
  // Held while dragging, so the canvas doesn't rescale under the pointer.
  property var frozen: null
  readonly property var bounds: frozen || boundsOf(boxes)
  readonly property real pad: 28
  readonly property real k: Math.max(0.0001, Math.min((width - 2 * pad) / bounds.w, (height - 2 * pad) / bounds.h))
  readonly property real offX: (width - bounds.w * k) / 2
  readonly property real offY: (height - bounds.h * k) / 2
  function toX(x) { return offX + (x - bounds.x) * k }
  function toY(y) { return offY + (y - bounds.y) * k }

  // The box being dragged, where it is now (logical), and the guides it
  // snapped to: [{ vertical, at }].
  property string dragName: ""
  property real dragX: 0
  property real dragY: 0
  property var guides: []

  // The nearest of the other boxes' edge and centre lines within a few
  // canvas pixels, for each axis.
  function snap(name, x, y, w, h) {
    var reach = 10 / k
    var bestX = { d: reach, at: x, line: null }, bestY = { d: reach, at: y, line: null }
    boxes.forEach(function(o) {
      if (o.name === name) return
      ;[[o.x - w, o.x], [o.x + o.w, o.x + o.w], [o.x, o.x], [o.x + o.w - w, o.x + o.w],
        [o.x + o.w / 2 - w / 2, o.x + o.w / 2]].forEach(function(c) {
        var d = Math.abs(c[0] - x)
        if (d < bestX.d) bestX = { d: d, at: c[0], line: c[1] }
      })
      ;[[o.y - h, o.y], [o.y + o.h, o.y + o.h], [o.y, o.y], [o.y + o.h - h, o.y + o.h],
        [o.y + o.h / 2 - h / 2, o.y + o.h / 2]].forEach(function(c) {
        var d = Math.abs(c[0] - y)
        if (d < bestY.d) bestY = { d: d, at: c[0], line: c[1] }
      })
    })
    var lines = []
    if (bestX.line !== null) lines.push({ vertical: true, at: bestX.line })
    if (bestY.line !== null) lines.push({ vertical: false, at: bestY.line })
    return { x: Math.round(bestX.at), y: Math.round(bestY.at), guides: lines }
  }

  Repeater {
    model: arrangement.guides
    delegate: Rectangle {
      required property var modelData
      x: modelData.vertical ? arrangement.toX(modelData.at) : 0
      y: modelData.vertical ? 0 : arrangement.toY(modelData.at)
      width: modelData.vertical ? 1 : arrangement.width
      height: modelData.vertical ? arrangement.height : 1
      color: arrangement.view.accent
      opacity: 0.8
    }
  }

  Repeater {
    model: arrangement.boxes
    delegate: Rectangle {
      id: screenBox
      required property var modelData
      readonly property bool dragging: arrangement.dragName === modelData.name
      readonly property bool picked: arrangement.displays.selected === modelData.name
      x: arrangement.toX(dragging ? arrangement.dragX : modelData.x)
      y: arrangement.toY(dragging ? arrangement.dragY : modelData.y)
      z: dragging ? 2 : 1
      width: modelData.w * arrangement.k
      height: modelData.h * arrangement.k
      radius: 4
      // As macOS's: each screen shows the wallpaper (see DisplayScreen), ringed
      // while it's picked.
      color: "transparent"
      opacity: dragging ? 0.85 : 1
      // Inset a pixel, so monitors that touch keep a seam between them.
      DisplayScreen {
        id: boxScreen
        anchors.fill: parent
        anchors.margins: 1
        view: arrangement.view
        radius: 5
        bezel: 2
        sourceWidth: 320
      }
      // Inside the box, in place of its bezel, so it never covers the
      // monitor beside it.
      Rectangle {
        anchors.fill: boxScreen
        radius: boxScreen.radius
        color: "transparent"
        border.width: 2.5
        border.color: arrangement.view.accent
        opacity: screenBox.picked ? 1 : 0
        Behavior on opacity { MotionAnimation { theme: arrangement.view.host.theme } }
      }

      // The island, on its monitor.
      Rectangle {
        visible: screenBox.modelData.name === arrangement.view.host.outputName
        anchors.horizontalCenter: parent.horizontalCenter
        y: 5
        width: Math.min(parent.width * 0.3, 40)
        height: 6
        radius: 3
        color: "#000000"
      }
      Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 10, boxName.implicitWidth + 14)
        height: boxName.implicitHeight + 6
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
          id: boxName
          anchors.centerIn: parent
          width: parent.width - 14
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: screenBox.modelData.title
          color: "#ffffff"
          font.family: arrangement.view.host.theme.textFontFamily
          font.pixelSize: arrangement.view.detailCaptionFontSize
          font.weight: Font.Medium
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: arrangement.boxes.length > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
        property point start
        property real startX
        property real startY
        onPressed: function(mouse) {
          arrangement.displays.selected = screenBox.modelData.name
          start = mapToItem(arrangement, mouse.x, mouse.y)
          startX = screenBox.modelData.x
          startY = screenBox.modelData.y
        }
        onPositionChanged: function(mouse) {
          if (!pressed || arrangement.boxes.length < 2 || arrangement.displays.confirming) return
          var p = mapToItem(arrangement, mouse.x, mouse.y)
          if (arrangement.dragName === "" && Math.hypot(p.x - start.x, p.y - start.y) < 4) return
          if (arrangement.dragName === "") {
            arrangement.frozen = arrangement.bounds
            arrangement.dragName = screenBox.modelData.name
          }
          var s = arrangement.snap(screenBox.modelData.name,
                                   startX + (p.x - start.x) / arrangement.k,
                                   startY + (p.y - start.y) / arrangement.k,
                                   screenBox.modelData.w, screenBox.modelData.h)
          arrangement.dragX = s.x
          arrangement.dragY = s.y
          arrangement.guides = s.guides
        }
        onReleased: finish()
        onCanceled: finish()
        function finish() {
          if (arrangement.dragName !== "") {
            var name = arrangement.dragName
            arrangement.dragName = ""
            arrangement.guides = []
            arrangement.frozen = null
            arrangement.displays.move(name, arrangement.dragX, arrangement.dragY)
          }
        }
      }
    }
  }
}
