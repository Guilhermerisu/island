import QtQuick

// A critically damped spring for the island's shape: `value` follows
// `target` and lands without overshooting. Unlike a timed animation it keeps
// its speed when the target changes mid-flight, so reversing an open or a
// close bends smoothly instead of restarting from rest. It is solved exactly
// each frame, so it stays smooth at any refresh rate.
FrameAnimation {
  id: spring
  property var theme: null
  property string pace: "morph"
  property real target: 0
  property real value: 0
  property real velocity: 0
  // Seconds per (undamped) oscillation, as SwiftUI's `response`; the value
  // is ~90% there after 0.6 of it and ~98% after 0.9. Follows the island's
  // motion speed.
  readonly property real response: (theme ? theme.motionDuration(pace) : 240) * 0.82 / 1000
  readonly property real omega: 2 * Math.PI / Math.max(0.01, response)

  Component.onCompleted: value = target
  onTargetChanged: if (!running) start()

  onTriggered: {
    // Frames longer than 50 ms (a stall) are treated as one short step.
    var dt = Math.min(frameTime, 0.05)
    var w = omega
    var offset = value - target
    var e = Math.exp(-w * dt)
    var k = (velocity + w * offset) * dt
    offset = (offset + k) * e
    velocity = (velocity - w * k) * e
    if (Math.abs(offset) < 0.1 && Math.abs(velocity) < 1) {
      value = target
      velocity = 0
      stop()
    } else {
      value = target + offset
    }
  }
}
