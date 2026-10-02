import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
  id: paneIcon
  required property var view
  property string glyph: ""
  property color tint: paneIcon.view.accent
  property bool neutral: !paneIcon.view.settings.colorfulSettingsIcons
  property bool onAccent: false
  implicitWidth: 20
  implicitHeight: 20

  readonly property color base: neutral ? (onAccent ? view.accentInk : view.well) : tint
  readonly property color lit: neutral ? Qt.lighter(base, 1.08) : Qt.lighter(tint, 1.32)
  readonly property color shade: neutral ? Qt.darker(base, 1.04) : Qt.darker(tint, 1.12)
  readonly property color ink: neutral ? (onAccent ? view.accent : view.textMuted) : "#ffffff"
  readonly property bool large: width >= 36

  function squircle(w, h, inset) {
    var points = []
    var steps = 64, n = 5
    var a = w / 2 - inset, b = h / 2 - inset
    for (var i = 0; i <= steps; i++) {
      var t = i / steps * 2 * Math.PI
      var c = Math.cos(t), s = Math.sin(t)
      points.push(Qt.point(w / 2 + a * Math.sign(c) * Math.pow(Math.abs(c), 2 / n),
                           h / 2 + b * Math.sign(s) * Math.pow(Math.abs(s), 2 / n)))
    }
    return points
  }
  readonly property var outline: squircle(width, height, 0)
  readonly property var rim: squircle(width, height, 0.5)

  Item {
    id: body
    anchors.fill: parent
    layer.enabled: !paneIcon.neutral || paneIcon.onAccent
    layer.samples: 4
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, paneIcon.large ? 0.35 : 0.28)
      shadowBlur: paneIcon.large ? 0.6 : 0.25
      shadowVerticalOffset: paneIcon.large ? 3 : 1
      shadowHorizontalOffset: 0
      autoPaddingEnabled: true
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: 0; y2: paneIcon.height
          GradientStop { position: 0; color: paneIcon.lit }
          GradientStop { position: 0.55; color: paneIcon.base }
          GradientStop { position: 1; color: paneIcon.shade }
        }
        PathPolyline { path: paneIcon.outline }
      }
      ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: 0; y2: paneIcon.height
          GradientStop { position: 0; color: Qt.rgba(1, 1, 1, paneIcon.neutral ? 0.06 : 0.22) }
          GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
        }
        PathPolyline { path: paneIcon.outline }
      }
      ShapePath {
        fillColor: "transparent"
        strokeWidth: 1
        strokeColor: Qt.rgba(1, 1, 1, paneIcon.neutral ? 0.06 : 0.18)
        PathPolyline { path: paneIcon.rim }
      }
    }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: paneIcon.large ? 1 : 0.5
      visible: !paneIcon.neutral
      text: paneIcon.glyph
      color: Qt.rgba(0, 0, 0, 0.18)
      font.family: paneIcon.view.host.theme.fontFamily
      font.pixelSize: glyphText.font.pixelSize
    }
    Text {
      id: glyphText
      anchors.centerIn: parent
      text: paneIcon.glyph
      color: paneIcon.ink
      font.family: paneIcon.view.host.theme.fontFamily
      font.pixelSize: Math.round(paneIcon.width * 0.6)
    }
  }
}
