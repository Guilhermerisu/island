import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// The bar Storage settings draws (System Stats, Agents): a rounded track
// split into coloured segments, and (with `legend`) each segment's dot, name,
// and amount below.
//   segments  [{ label, value, color, text }], value in the same unit as total.
ColumnLayout {
  id: usage
  required property var view
  property var segments: []
  property real total: 1
  property bool legend: true
  property int barHeight: 10
  property real barRadius: barHeight / 2
  // The legend as Storage's: small square swatches, the name quiet and the
  // amount in the text colour (else round dots, the name in the text colour).
  property bool squareLegend: false
  spacing: 8

  Rectangle {
    id: track
    Layout.fillWidth: true
    Layout.preferredHeight: usage.barHeight
    radius: usage.barRadius
    color: usage.view.host.theme.fill("raised")
    // The segments, cut to the track's rounded ends.
    Rectangle {
      id: trackMask
      anchors.fill: parent
      radius: track.radius
      visible: false
      // Only while the bar is on screen, so a hidden one holds no buffers.
      layer.enabled: track.visible
    }
    Row {
      anchors.fill: parent
      layer.enabled: track.visible
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: trackMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
      }
      spacing: 1
      // By count, so a new reading's array updates the bars in place.
      Repeater {
        model: usage.segments.length
        delegate: Rectangle {
          required property int index
          readonly property var modelData: usage.segments[index] || ({})
          // The share eases, not the width, so the segment follows the track
          // at once while the island resizes.
          property real share: Math.min(1, (modelData.value || 0) / Math.max(1, usage.total))
          Behavior on share { MotionAnimation { theme: usage.view.host.theme; pace: "expressive" } }
          width: Math.max(0, track.width * share - 1)
          height: track.height
          color: modelData.color
        }
      }
    }
  }

  Flow {
    visible: usage.legend
    Layout.fillWidth: true
    spacing: 14
    Repeater {
      model: usage.legend ? usage.segments.length : 0
      delegate: Row {
        required property int index
        readonly property var modelData: usage.segments[index] || ({})
        spacing: 5
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: usage.squareLegend ? 7 : 8
          height: width
          radius: usage.squareLegend ? 2 : 4
          color: parent.modelData.color
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: usage.squareLegend ? usage.view.textMuted : usage.view.text
          font.family: usage.view.host.theme.textFontFamily
          font.letterSpacing: usage.view.host.theme.tracking(usage.view.host.theme.textFontFamily, usage.view.detailCaptionFontSize)
          font.features: { "tnum": 1 }
          font.pixelSize: usage.view.detailCaptionFontSize
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.text || ""
          color: usage.squareLegend ? usage.view.text : usage.view.textMuted
          font.family: usage.view.host.theme.textFontFamily
          font.letterSpacing: usage.view.host.theme.tracking(usage.view.host.theme.textFontFamily, usage.view.detailCaptionFontSize)
          font.features: { "tnum": 1 }
          font.pixelSize: usage.view.detailCaptionFontSize
        }
      }
    }
  }
}
