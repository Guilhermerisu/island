import QtQuick
import QtQuick.Shapes

// The › that turns when a section opens. A font glyph turns about the centre
// of its Text box (ascent + descent), which sits off the glyph and moves with
// the font, so it swung sideways as it turned. This draws the glyph's outline
// (Material Design Icons "chevron-right", what 󰅂 is) around its own centre.
// The box is about the Text's (0.6 x 1.2 of `pixelSize`) so layouts stay put,
// in even pixels so centring it never lands on a half pixel.
Item {
  id: chev
  required property var theme
  property bool open: false
  property color color: "white"
  property real pixelSize: 14
  property real angle: open ? 90 : 0
  Behavior on angle { MotionAnimation { theme: chev.theme; pace: "standard" } }

  implicitWidth: 2 * Math.round(pixelSize * 0.3)
  implicitHeight: 2 * Math.round(pixelSize * 0.6)
  rotation: angle

  Shape {
    // On the item's centre, so its rotation is about the glyph.
    x: chev.width / 2
    y: chev.height / 2
    transformOrigin: Item.TopLeft
    scale: chev.pixelSize / 24
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      // The icon's 24-unit grid (the Shape is scaled to it), moved so its
      // ink (x 8.59–16, y 6–18) is centred on the origin.
      fillColor: chev.color
      strokeColor: "transparent"
      startX: -3.705; startY: 4.58
      PathLine { x: 0.875; y: 0 }
      PathLine { x: -3.705; y: -4.59 }
      PathLine { x: -2.295; y: -6 }
      PathLine { x: 3.705; y: 0 }
      PathLine { x: -2.295; y: 6 }
    }
  }
}
