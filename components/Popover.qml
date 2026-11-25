import QtQuick
import QtQuick.Effects

// A macOS-style pop-up panel over a view: raised, edged and shadowed,
// fading and growing in while `open` and only taking input then. Its owner
// places and sizes it with place(); set transformOrigin to where it grows
// from.
Rectangle {
  id: popover
  required property var theme
  property bool open: false
  // Whole pixels: it's drawn through a layer (its shadow), and a layer at a
  // fractional position or size is resampled and blurs.
  function place(px, py, w, h) {
    if (w !== undefined) width = Math.ceil(w)
    if (h !== undefined) height = Math.ceil(h)
    x = Math.round(px)
    y = Math.round(py)
  }

  visible: opacity > 0.01
  enabled: open
  opacity: open ? 1 : 0
  scale: open ? 1 : 0.96
  Behavior on opacity { MotionAnimation { theme: popover.theme; pace: popover.open ? "fade" : "exit"; curve: "fade" } }
  Behavior on scale { MotionAnimation { theme: popover.theme; pace: popover.open ? "standard" : "exit" } }
  radius: 10
  color: theme.solid("raised")
  border.width: 1
  border.color: theme.fill("raised")
  layer.enabled: visible
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.5)
    shadowBlur: 0.8
    shadowVerticalOffset: 6
  }
}
