import QtQuick

// Collapse to a dot before leaving. On return the dot stretches down from
// the edge, then opens into the island. Springs retain velocity on reversal.
Item {
  id: motion
  required property var theme
  property bool hidden: false
  property real expandedWidth: 100
  property real expandedHeight: 40
  property real restY: 8
  property real edgeProgress: 0
  readonly property real dotSize: 12
  property bool departing: false

  readonly property real edgeCollapse: Math.max(0, Math.min(1, edgeProgress))
  readonly property real edgeMorph: Math.max(-0.06, edgeCollapse === 0 ? edgeProgress : edgeCollapse)
  readonly property real collapseProgress: Math.max(edgeCollapse, Math.min(1, collapse.value / 100))
  readonly property real morphProgress: Math.max(-0.06, Math.min(1, collapse.value / 100))
  readonly property real flightProgress: Math.max(0, Math.min(1, flight.value / 100))
  readonly property real stretch: Math.sin(Math.PI * flightProgress) * 18
  readonly property real autoWidth: Math.max(dotSize, expandedWidth + (dotSize - expandedWidth) * morphProgress)
  readonly property real autoHeight: Math.max(dotSize, expandedHeight + (dotSize - expandedHeight) * morphProgress + stretch)
  readonly property real autoY: restY + (-dotSize - 24 - restY) * flightProgress
  // A narrow tip stretches out of the screen before blooming into the pill.
  readonly property real renderWidth: autoWidth + (22 - autoWidth) * edgeMorph
  readonly property real renderHeight: autoHeight + (10 - autoHeight) * edgeMorph
    + Math.sin(Math.PI * edgeCollapse) * 14
  readonly property real renderY: autoY - (restY + 14) * edgeMorph
  readonly property real contentOpacity: Math.pow(1 - collapseProgress, 2)
  readonly property bool animating: collapse.running || flight.running

  onHiddenChanged: {
    if (!hidden) departing = false
    else if (collapse.value >= 97) departing = true
  }
  Component.onCompleted: {
    // A shell reload while fullscreen must start out of sight.
    departing = hidden
    collapse.value = hidden ? 100 : 0
    flight.value = hidden ? 100 : 0
  }

  MotionSpring {
    id: collapse
    theme: motion.theme
    pace: motion.hidden ? "collapse" : "morph"
    bounce: motion.hidden ? 0 : 0.18
    target: motion.hidden || flight.value > 68 ? 100 : 0
    onValueChanged: if (motion.hidden && value >= 97) motion.departing = true
  }
  MotionSpring {
    id: flight
    theme: motion.theme
    pace: motion.hidden ? "exit" : "expressive"
    bounce: motion.hidden ? 0 : 0.12
    target: motion.departing ? 100 : 0
  }
}
