import QtQuick

// iOS-style bars that bounce to random heights while media plays.
Row {
  id: wave
  property color color: "white"
  property bool playing: false
  readonly property bool active: visible && playing
  onActiveChanged: if (!active) settle()
  property int bars: 5
  property real barWidth: 3
  property real maxHeight: 18

  spacing: barWidth

  Repeater {
    id: repeater
    model: wave.bars + 2
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

  // Paused: ease the bars down to rest; hidden: drop them at once.
  function settle() {
    for (var i = 1; i <= bars; i++) {
      var bar = repeater.itemAt(i)
      if (!bar) continue
      bar.target = 0
      if (!visible) bar.level = 0
    }
    pulse.running = visible
  }

  // New random targets a few times a second. The middle bars swing wider
  // than the outer ones, like iOS's.
  Timer {
    interval: 180
    repeat: true
    triggeredOnStart: true
    running: wave.active
    onTriggered: {
      var middle = (wave.bars + 1) / 2
      for (var i = 1; i <= wave.bars; i++) {
        var bar = repeater.itemAt(i)
        if (!bar) continue
        var reach = 1 - Math.abs(i - middle) / middle * 0.45
        bar.target = (0.15 + Math.random() * 0.85) * reach
      }
      pulse.running = true
    }
  }

  // Interpolate at 30 Hz while the bars move, then stop at rest.
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
