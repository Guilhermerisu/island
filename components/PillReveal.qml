import QtQuick

// Brings a live activity's parts in from a blur in turn, as the Dynamic
// Island's: the leading part first, then the middle, then the trailing one.
// Each `…In` runs 0 → 1 when `shown` turns on, and back to 0 when it turns
// off, quicker and the other way round (trailing first), while the pill
// fades out; turned back on mid-exit, the parts carry on from where they
// are. Give a part, for example the leading one:
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
  // The island this pill sits on (the nearest ancestor with a targetHeight).
  // A pill shown while the island is still shrinking from an open view
  // waits for it to have nearly shrunk, so its parts don't come in over
  // the view's content. Once in, they stay in as the island changes size.
  property Item island: null
  Component.onCompleted: {
    var p = parent
    while (p && p.targetHeight === undefined) p = p.parent
    island = p
  }
  readonly property bool fits: !island || island.height < island.targetHeight + 24
  property bool held: false
  readonly property bool wanted: shown && (fits || held)
  // Each part waits its turn only if it's fully out; a pill shown again
  // while still leaving carries on from where its parts are.
  property int middleDelay: 0
  property int trailingDelay: 0
  // Shown before the island fits: never-revealed parts (at 1, for a pill
  // created shown) drop out of sight until it does; leaving ones carry on.
  onShownChanged: {
    if (shown && !wanted && leadingIn === 1 && middleIn === 1 && trailingIn === 1)
      leadingIn = middleIn = trailingIn = 0
  }
  onWantedChanged: {
    if (wanted) {
      held = true
      leave.stop()
      if (leadingIn === 1 && middleIn === 1 && trailingIn === 1) leadingIn = middleIn = trailingIn = 0
      middleDelay = middleIn > 0 ? 0 : duration / 5
      trailingDelay = trailingIn > 0 ? 0 : duration * 2 / 5
      run.restart()
    } else {
      held = false
      run.stop()
      leave.restart()
    }
  }

  component Step: NumberAnimation {
    target: reveal
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
      PauseAnimation { duration: reveal.middleDelay }
      Step { property: "middleIn" }
    }
    SequentialAnimation {
      PauseAnimation { duration: reveal.trailingDelay }
      Step { property: "trailingIn" }
    }
  }
}
