import QtQuick

// macOS-style tooltip for an icon-only button: put it inside the button with
// the button's name. It appears under the button (above, with `above`) after
// a short hover, drawn on top of the whole window so no card can cover it.
//
//   Rectangle { ...; Tooltip { text: "Settings" } }
Item {
  id: tip
  property string text: ""
  property bool above: false
  property bool shown: false
  property var theme: null
  readonly property Item overlay: tip.Window.contentItem
  anchors.fill: parent
  // Above the button's own MouseArea, which would otherwise take the hover;
  // the HoverHandler only watches, so clicks and hover still reach the button.
  z: 100

  HoverHandler {
    id: hover
    onHoveredChanged: if (!hovered) tip.shown = false
  }
  Timer {
    interval: 550
    running: hover.hovered && tip.text !== "" && !tip.shown
    onTriggered: { bubble.place(); tip.shown = true }
  }

  Rectangle {
    id: bubble
    parent: tip.overlay
    z: 1000
    visible: opacity > 0.01
    enabled: false
    opacity: tip.shown ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: tip.theme; pace: tip.shown ? "fade" : "exit"; curve: "fade" } }
    scale: tip.shown ? 1 : 0.97
    transformOrigin: tip.above ? Item.Bottom : Item.Top
    Behavior on scale { MotionAnimation { theme: tip.theme; pace: "quick" } }
    width: label.implicitWidth + 16
    height: label.implicitHeight + 8
    radius: 6
    color: "#2c2c2e"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.1)
    // Centered on the button, kept on screen.
    function place() {
      if (!tip.overlay) return
      var p = tip.mapToItem(tip.overlay, tip.width / 2, tip.above ? 0 : tip.height)
      x = Math.max(4, Math.min(tip.overlay.width - width - 4, p.x - width / 2))
      y = tip.above ? p.y - height - 6 : p.y + 6
    }
    Text {
      id: label
      anchors.centerIn: parent
      text: tip.text
      color: "#f2f2f7"
      font.family: tip.theme.textFontFamily
      font.pixelSize: 12
    }
  }
}
