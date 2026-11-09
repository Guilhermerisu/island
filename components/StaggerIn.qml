import QtQuick

// Put inside a part of an open view to have it come in after the ones before
// it: the header (step 0), then the tiles, then the lists, a beat apart. Only
// opening staggers: closing fades the whole view as one, and going straight
// from another view is the Surface's blur replace.
Item {
  id: part
  // The part, unless this sits beside it or inside a slot of it.
  property Item target: parent
  property int step: 0
  visible: false

  property Item surface: null
  Component.onCompleted: {
    var p = parent
    while (p && p.viewName === undefined) p = p.parent
    surface = p
  }
  readonly property bool revealed: !!surface && surface.revealed
  property real progress: 1
  onRevealedChanged: {
    if (!revealed) { run.stop(); return }
    if (surface.host.switchingSurface) { run.stop(); progress = 1; return }
    // Reopened while still fading out, it carries on from where it is.
    if (surface.opacity < 0.05) progress = 0
    run.restart()
  }
  Binding { target: part.target; property: "opacity"; value: part.progress; when: part.progress < 1 }
  Binding { target: part.target; property: "scale"; value: 0.985 + 0.015 * part.progress; when: part.progress < 1 }

  SequentialAnimation {
    id: run
    PauseAnimation { duration: part.surface ? part.surface.host.theme.scaled(20) * part.step : 0 }
    MotionAnimation {
      theme: part.surface ? part.surface.host.theme : null
      target: part
      property: "progress"
      to: 1
      pace: "standard"
      curve: "fade"
    }
  }
}
