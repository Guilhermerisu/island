import QtQuick
import QtQuick.Shapes

// The time left as a ring, as iOS's timer: a dim track with the remainder
// over it, from the top, clockwise, shrinking back as the time runs out.
Item {
  id: ring
  property real progress: 1
  property color color: "#ff9f0a"
  property color track: Qt.rgba(1, 159 / 255, 10 / 255, 0.3)
  property real thickness: 3.5
  implicitWidth: 26
  implicitHeight: 26

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.track
      strokeWidth: ring.thickness
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2; radiusY: radiusX
        startAngle: 0; sweepAngle: 360
      }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.color
      strokeWidth: ring.thickness
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2; radiusY: radiusX
        startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, ring.progress))
      }
    }
  }
}
