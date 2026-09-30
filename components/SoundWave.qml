import QtQuick

// iOS-style "now playing" wave: bars that bounce to random heights while
// `playing`, flanked by a small dot at each end. Shared by the media pill and
// the player view. The bars ease toward their targets in ~60 steps a second
// instead of a vsync-driven animation: Qt only redraws when something moves,
// so this keeps a playing wave from repainting the island at the display's
// full refresh rate (360 Hz here) for bars a few pixels tall.
Row {
  id: wave
  property color color: "white"
  property bool playing: false
  property int bars: 5
  property real barWidth: 3
  property real maxHeight: 18

  spacing: barWidth

  Repeater {
    id: repeater
    model: wave.bars + 2
    delegate: Rectangle {
      required property int index
      readonly property bool dot: index === 0 || index === wave.bars + 1
      property real level: 0.3
      property real target: 0.3
      width: wave.barWidth
      height: dot ? wave.barWidth : wave.barWidth + (wave.maxHeight - wave.barWidth) * level
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: wave.color
      opacity: dot ? 0.8 : 1
    }
  }

  property real lastTick: 0
  property real retargetTime: 0
  property bool settling: true
  onPlayingChanged: settling = true
  Timer {
    interval: 16
    repeat: true
    running: wave.visible && (wave.playing || wave.settling)
    onRunningChanged: wave.lastTick = Date.now()
    onTriggered: {
      var now = Date.now()
      var elapsed = Math.min(64, Math.max(0, now - wave.lastTick))
      wave.lastTick = now
      wave.retargetTime += elapsed
      var middle = (wave.bars + 1) / 2
      var retarget = wave.retargetTime >= 180
      if (retarget) wave.retargetTime %= 180
      var response = 1 - Math.exp(-elapsed / 85)
      var moving = false
      for (var i = 1; i <= wave.bars; i++) {
        var bar = repeater.itemAt(i)
        if (!bar) continue
        // The middle bars swing wider than the outer ones, like iOS's.
        var reach = 1 - Math.abs(i - middle) / middle * 0.45
        if (!wave.playing) bar.target = 0.12
        else if (retarget) bar.target = (0.15 + Math.random() * 0.85) * reach
        bar.level += (bar.target - bar.level) * response
        if (Math.abs(bar.target - bar.level) < 0.002) bar.level = bar.target
        else moving = true
      }
      wave.settling = moving
    }
  }
}
