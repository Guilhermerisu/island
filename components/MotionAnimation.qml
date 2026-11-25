import QtQuick

// Shared response for geometry, selection and content. Behaviors retarget
// from their current value, so reversing a transition stays continuous.
//
// A Behavior's pace or curve chosen by the same change that moves it
// (`shown ? "fade" : "exit"`) has to name where it's heading, through towards:
//
//   Behavior on opacity { id: fade; MotionAnimation { pace: towards(fade.targetValue, shown ? "fade" : "exit") } }
//
// Qt sets the animation off before it re-reads a binding that only follows
// the change, so a bare condition gives the last move's pace (a press at
// the release's speed, a view opening at its closing speed). The new
// targetValue is set first, so a binding that reads it is up to date.
NumberAnimation {
  property var theme: null
  property string pace: "standard"
  property string curve: "settle"
  duration: theme ? theme.motionDuration(pace) : 240
  easing.type: Easing.BezierSpline
  easing.bezierCurve: theme ? theme.motionCurve(curve) : [0.16, 1, 0.3, 1, 1, 1]
  // `choice`, read again whenever the Behavior's target changes.
  function towards(target, choice) { return choice }
}
