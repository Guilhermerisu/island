import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// The bar Storage settings draws: a rounded track split into coloured
// segments, and (with `legend`) each segment's dot, name, and amount below.
//   segments  [{ label, value, color, text }], value in the same unit as total.
ColumnLayout {
  id: usage
  required property var view
  property var segments: []
  property real total: 1
  property bool legend: true
  property int barHeight: 10
  property real barRadius: barHeight / 2
  spacing: 8

  Rectangle {
    id: track
    Layout.fillWidth: true
    Layout.preferredHeight: usage.barHeight
    radius: usage.barRadius
    color: usage.view.host.theme.withAlpha(usage.view.text, 0.12)
    // The segments, cut to the track's rounded ends.
    Rectangle {
      id: trackMask
      anchors.fill: parent
      radius: track.radius
      visible: false
      layer.enabled: true
    }
    Row {
      anchors.fill: parent
      layer.enabled: true
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
          width: Math.max(0, track.width * Math.min(1, (modelData.value || 0) / Math.max(1, usage.total)) - 1)
          height: track.height
          color: modelData.color
          Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
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
          width: 8
          height: 8
          radius: 4
          color: parent.modelData.color
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: usage.view.text
          font.family: "Adwaita Sans"
          font.pixelSize: usage.view.detailCaptionFontSize
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.text || ""
          color: usage.view.textMuted
          font.family: "Adwaita Sans"
          font.pixelSize: usage.view.detailCaptionFontSize
        }
      }
    }
  }
}
