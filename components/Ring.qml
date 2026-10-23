import QtQuick
import QtQuick.Shapes

// A usage ring: a faint track and an arc from the top, clockwise, with the
// percentage in its middle (or `text`, with an optional `caption` under it).
Item {
  id: ring
  required property var view
  property real value: 0          // 0–100
  property color color: "#0a84ff"
  property real thickness: 7
  property string text: Math.round(value) + "%"
  property string caption: ""
  implicitWidth: 84
  implicitHeight: 84

  property real shown: Math.max(0, Math.min(100, value))
  Behavior on shown { MotionAnimation { theme: ring.view.host.theme; pace: "data" } }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.view.host.theme.fill("raised")
      strokeWidth: ring.thickness
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2; radiusY: radiusX
        startAngle: 0; sweepAngle: 360
      }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.shown > 0.5 ? ring.color : "transparent"
      strokeWidth: ring.thickness
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2; radiusY: radiusX
        startAngle: -90; sweepAngle: 360 * ring.shown / 100
      }
    }
  }
  Column {
    anchors.centerIn: parent
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: ring.text
      color: ring.view.text
      font.family: ring.view.host.theme.textFontFamily
      font.letterSpacing: ring.view.host.theme.tracking(ring.view.host.theme.textFontFamily, Math.round(ring.width * 0.2))
      font.pixelSize: Math.round(ring.width * 0.2)
      font.weight: Font.DemiBold
      font.features: { "tnum": 1 }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: ring.caption !== ""
      text: ring.caption
      color: ring.view.textMuted
      font.family: ring.view.host.theme.textFontFamily
      font.letterSpacing: ring.view.host.theme.tracking(ring.view.host.theme.textFontFamily, Math.round(ring.width * 0.13))
      font.pixelSize: Math.round(ring.width * 0.13)
    }
  }
}
