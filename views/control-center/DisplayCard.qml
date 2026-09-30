import QtQuick
import QtQuick.Layouts

// The Display card: the brightness slider. Loaded by the ControlCenter (and
// its gallery, as a preview).
CcSection {
  id: card
  readonly property var controls: center.controls
  readonly property bool galleryPreview: parent.galleryPreview
  anchors.fill: parent
  title: "Display"
  detail: card.controls.brightnessAvailable ? card.controls.brightness + "%" : "Unavailable"
  CcSlider {
    center: card.center
    visible: galleryPreview || card.controls.brightnessAvailable
    icon: "󰃠"
    value: card.controls.brightness / 100
    onMoved: function(v) {
      card.controls.setBrightness(Math.round(v * 100))
    }
  }
  Text {
    visible: !galleryPreview && !card.controls.brightnessAvailable
    text: "No brightness control available"
    color: card.center.textMuted
    font.family: "Adwaita Sans"
    font.pixelSize: 12
    Layout.fillWidth: true
  }
}
