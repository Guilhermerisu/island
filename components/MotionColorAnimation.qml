import QtQuick

// Color changes ease evenly, independently of a control's physical response.
ColorAnimation {
  property var theme: null
  duration: theme ? theme.motionDuration("quick") : 165
  easing.type: Easing.BezierSpline
  easing.bezierCurve: theme ? theme.motionCurve("fade") : [0.2, 0, 0.2, 1, 1, 1]
}
