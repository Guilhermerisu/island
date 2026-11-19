import QtQuick

// iOS-style bars driven by the CAVA service's real spectrum.
// Frequency bins are grouped to fit each view; no synthetic motion is added.
Row {
  id: wave
  property color color: "white"
  property bool playing: false
  property var spectrum: null
  readonly property var levels: visible && playing && spectrum?.playing ? spectrum.levels : null
  property int bars: 5
  property real barWidth: 3
  property real maxHeight: 18

  spacing: barWidth

  function levelAt(index) {
    if (!levels?.length || bars <= 0) return 0
    // RMS preserves a beat in a narrow band without exaggerating quiet bins.
    var start = Math.floor(index * levels.length / bars)
    var end = Math.max(start + 1, Math.floor((index + 1) * levels.length / bars))
    var power = 0, count = 0
    for (var i = start; i < Math.min(end, levels.length); i++) {
      var level = levels[i]
      power += level * level
      count++
    }
    return count ? Math.sqrt(power / count) : 0
  }

  Repeater {
    id: repeater
    model: wave.bars + 2
    onItemAdded: function(index, item) {
      if (!item.dot) wave.updateTargets()
    }
    delegate: Rectangle {
      required property int index
      objectName: "islandAudioBar_" + index
      readonly property bool dot: index === 0 || index === wave.bars + 1
      property real level: 0
      property real target: 0
      width: wave.barWidth
      height: dot ? wave.barWidth : wave.barWidth + (wave.maxHeight - wave.barWidth) * level
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: wave.color
      opacity: dot ? 0.8 : 1
    }
  }

  onLevelsChanged: updateTargets()
  onVisibleChanged: updateTargets()
  function updateTargets() {
    var moving = false
    for (var i = 1; i <= bars; i++) {
      var bar = repeater.itemAt(i)
      if (!bar) continue
      bar.target = levelAt(i - 1)
      if (!visible) bar.level = 0
      else if (Math.abs(bar.target - bar.level) >= 0.002) moving = true
      else bar.level = bar.target
    }
    pulse.running = moving
  }

  // Calculate the band energy only for a new input sample. Interpolate at
  // 30 Hz while the bars move, then stop at silence.
  Timer {
    id: pulse
    interval: 33
    repeat: true
    onTriggered: {
      var elapsed = interval / 1000
      var attack = 1 - Math.exp(-elapsed / 0.035)
      var release = 1 - Math.exp(-elapsed / 0.100)
      var moving = false
      for (var i = 1; i <= wave.bars; i++) {
        var bar = repeater.itemAt(i)
        if (!bar) continue
        var delta = bar.target - bar.level
        var next = bar.level + delta * (delta > 0 ? attack : release)
        if (Math.abs(bar.target - next) < 0.002) next = bar.target
        else moving = true
        bar.level = next
      }
      if (!moving) stop()
    }
  }
}
