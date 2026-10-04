import QtQuick
import QtQuick.Shapes

// A usage ring: a faint track and an arc from the top, clockwise, with the
// percentage in its middle.
Item {
  id: ring
  required property var view
  property real value: 0          // 0–100
  property color color: "#0a84ff"
  property real thickness: 7
  implicitWidth: 84
  implicitHeight: 84

  property real shown: Math.max(0, Math.min(100, value))
  Behavior on shown { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.view.host.theme.withAlpha(ring.view.text, 0.1)
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
  Text {
    anchors.centerIn: parent
    text: Math.round(ring.value) + "%"
    color: ring.view.text
    font.family: "Adwaita Sans"
    font.pixelSize: Math.round(ring.width * 0.2)
    font.weight: Font.DemiBold
    font.features: { "tnum": 1 }
  }
}
