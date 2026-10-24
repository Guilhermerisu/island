import QtQuick

// Put inside a live activity's part to bring it in from a blur with
// PillReveal: as `progress` (one of the reveal's …In) runs 0 → 1, the part
// grows from `scaleFrom` and sharpens. Its opacity stays the part's own to
// set, usually to the same progress:
//
//   Text {
//     opacity: reveal.leadingIn
//     PillPart { progress: reveal.leadingIn }
//   }
Item {
  id: part
  // The part, unless this sits somewhere else in it (a ClippingRectangle's
  // children are inside its clip).
  property Item target: parent
  property real progress: 1
  // The sides grow from 0.9, the middle from 0.94.
  property real scaleFrom: 0.9
  visible: false

  Binding { target: part.target; property: "scale"; value: part.scaleFrom + (1 - part.scaleFrom) * part.progress }
  // Only mid-reveal: fully out (a hidden pill) or fully in needs no blur.
  Binding { target: part.target; property: "layer.enabled"; value: part.progress > 0 && part.progress < 1 }
  Binding { target: part.target; property: "layer.effect"; value: blur }
  Component { id: blur; PillBlur { blur: 1 - part.progress } }
}
