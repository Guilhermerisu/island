import QtQuick

// iOS-style "now playing" wave: bars that bounce to random heights while
// `playing`, flanked by a small dot at each end. Shared by the media pill and
// the player view.
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
      width: wave.barWidth
      height: dot ? wave.barWidth : wave.barWidth + (wave.maxHeight - wave.barWidth) * level
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: wave.color
      opacity: dot ? 0.8 : 1
      Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    }
  }

  Timer {
    interval: 170
    repeat: true
    running: wave.playing && wave.visible
    onTriggered: {
      var middle = (wave.bars + 1) / 2
      for (var i = 1; i <= wave.bars; i++) {
        var bar = repeater.itemAt(i)
        // The middle bars swing wider than the outer ones, like iOS's.
        var reach = 1 - Math.abs(i - middle) / middle * 0.45
        if (bar) bar.level = (0.15 + Math.random() * 0.85) * reach
      }
    }
  }
}
