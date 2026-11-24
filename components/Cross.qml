import QtQuick
import QtQuick.Shapes

// The × of a small round button. A font glyph sits in its Text box by the
// font's ascent and descent, not by its ink, so 󰅖 landed off the centre of
// the button. This draws the glyph's outline (Material Design Icons "close",
// what 󰅖 is) around its own centre, at the size the glyph had. The box is
// square, in even pixels so centring it never lands on a half pixel.
Item {
  id: cross
  property color color: "white"
  property real pixelSize: 14

  implicitWidth: 2 * Math.round(pixelSize * 0.3)
  implicitHeight: implicitWidth

  Shape {
    x: cross.width / 2
    y: cross.height / 2
    transformOrigin: Item.TopLeft
    scale: cross.pixelSize / 24
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      // The icon's 24-unit grid (the Shape is scaled to it), moved so its
      // ink (5–19 on both axes) is centred on the origin.
      fillColor: cross.color
      strokeColor: "transparent"
      startX: 7; startY: -5.59
      PathLine { x: 5.59; y: -7 }
      PathLine { x: 0; y: -1.41 }
      PathLine { x: -5.59; y: -7 }
      PathLine { x: -7; y: -5.59 }
      PathLine { x: -1.41; y: 0 }
      PathLine { x: -7; y: 5.59 }
      PathLine { x: -5.59; y: 7 }
      PathLine { x: 0; y: 1.41 }
      PathLine { x: 5.59; y: 7 }
      PathLine { x: 7; y: 5.59 }
      PathLine { x: 1.41; y: 0 }
      PathLine { x: 7; y: -5.59 }
    }
  }
}
