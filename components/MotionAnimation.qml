import QtQuick

// Shared response for geometry, selection and content. Behaviors retarget
// from their current value, so reversing a transition stays continuous.
NumberAnimation {
  property var theme: null
  property string pace: "standard"
  property string curve: "settle"
  duration: theme ? theme.motionDuration(pace) : 240
  easing.type: Easing.BezierSpline
  easing.bezierCurve: theme ? theme.motionCurve(curve) : [0.16, 1, 0.3, 1, 1, 1]
}
