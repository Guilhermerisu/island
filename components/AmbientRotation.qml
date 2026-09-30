import QtQuick

// Keep long-running indicators smooth without repainting at a high-refresh
// monitor's full rate. Elapsed time prevents timer jitter from changing speed.
Timer {
  id: spin
  required property Item target
  property int period: 1400
  property real lastTick: 0
  interval: 16
  repeat: true
  onRunningChanged: lastTick = Date.now()
  onTriggered: {
    var now = Date.now()
    var elapsed = Math.min(64, Math.max(0, now - lastTick))
    lastTick = now
    target.rotation = (target.rotation + 360 * elapsed / period) % 360
  }
}
