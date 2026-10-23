import QtQuick

// A spring for the island's shape: `value` follows `target`, critically
// damped (landing without overshooting) unless given some `bounce`. Unlike a
// timed animation it keeps its speed when the target changes mid-flight, so
// reversing an open or a close bends smoothly instead of restarting from
// rest. It is solved exactly each frame, so it stays smooth at any refresh
// rate.
FrameAnimation {
  id: spring
  property var theme: null
  property string pace: "morph"
  property real target: 0
  property real value: 0
  property real velocity: 0
  // As SwiftUI's: 0 lands without overshooting; 0.2 swings about 1.5% of
  // the distance past the target and back. Can change mid-flight.
  property real bounce: 0
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
    var zeta = 1 - Math.max(0, Math.min(0.9, bounce))
    if (zeta >= 1) {
      var e = Math.exp(-w * dt)
      var k = (velocity + w * offset) * dt
      offset = (offset + k) * e
      velocity = (velocity - w * k) * e
    } else {
      // Underdamped: a decaying swing at the damped frequency.
      var wd = w * Math.sqrt(1 - zeta * zeta)
      var decay = Math.exp(-zeta * w * dt)
      var a = offset
      var b = (velocity + zeta * w * offset) / wd
      var c = Math.cos(wd * dt)
      var sn = Math.sin(wd * dt)
      offset = decay * (a * c + b * sn)
      velocity = decay * ((b * wd - zeta * w * a) * c - (a * wd + zeta * w * b) * sn)
    }
    if (Math.abs(offset) < 0.1 && Math.abs(velocity) < 1) {
      value = target
      velocity = 0
      stop()
    } else {
      value = target + offset
    }
  }
}
