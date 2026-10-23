import QtQuick

// Brings a live activity's parts in from a blur in turn, as the Dynamic
// Island's: the leading part first, then the middle, then the trailing one.
// Each `…In` runs 0 → 1 when `shown` turns on, and back to 0 when it turns
// off, quicker and the other way round (trailing first), while the pill
// fades out. Give a part, for example the leading one:
//
//   opacity: reveal.leadingIn
//   PillPart { progress: reveal.leadingIn }
Item {
  id: reveal
  required property var theme
  property bool shown: false
  property real leadingIn: 1
  property real middleIn: 1
  property real trailingIn: 1
  readonly property int duration: theme.motionDuration("expressive")
  readonly property int exitDuration: theme.motionDuration("exit")

  visible: false
  onShownChanged: {
    if (shown) { leave.stop(); run.restart() }
    else { run.stop(); leave.restart() }
  }

  component Step: NumberAnimation {
    target: reveal
    from: 0
    to: 1
    duration: reveal.duration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: reveal.theme.motionCurve("settle")
  }
  component Out: NumberAnimation {
    target: reveal
    to: 0
    duration: reveal.exitDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: reveal.theme.motionCurve("exit")
  }
  ParallelAnimation {
    id: leave
    Out { property: "trailingIn" }
    SequentialAnimation {
      PauseAnimation { duration: reveal.exitDuration / 6 }
      Out { property: "middleIn" }
    }
    SequentialAnimation {
      PauseAnimation { duration: reveal.exitDuration / 3 }
      Out { property: "leadingIn" }
    }
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
