import QtQuick

// Brings a live activity's parts in from a blur in turn, as the Dynamic
// Island's: the leading part first, then the middle, then the trailing one.
// Each `…In` runs 0 → 1 when `shown` turns on, and stays at 1 while the pill
// fades out. Give a part, for example the leading one:
//
//   opacity: reveal.leadingIn
//   scale: 0.9 + 0.1 * reveal.leadingIn
//   layer.enabled: reveal.leadingIn < 1
//   layer.effect: PillBlur { blur: 1 - reveal.leadingIn }
Item {
  id: reveal
  required property var theme
  property bool shown: false
  property real leadingIn: 1
  property real middleIn: 1
  property real trailingIn: 1
  readonly property int duration: theme.motionDuration("expressive")

  visible: false
  onShownChanged: if (shown) run.restart()

  component Step: NumberAnimation {
    target: reveal
    from: 0
    to: 1
    duration: reveal.duration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: reveal.theme.motionCurve("settle")
  }
  ParallelAnimation {
    id: run
    Step { property: "leadingIn" }
    SequentialAnimation {
      PropertyAction { target: reveal; property: "middleIn"; value: 0 }
      PauseAnimation { duration: reveal.duration / 5 }
      Step { property: "middleIn" }
    }
    SequentialAnimation {
      PropertyAction { target: reveal; property: "trailingIn"; value: 0 }
      PauseAnimation { duration: reveal.duration * 2 / 5 }
      Step { property: "trailingIn" }
    }
  }
}
