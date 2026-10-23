import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../components"

// The Sound card: the volume slider, and the output picker behind its ›
// button. Loaded by the ControlCenter (and its gallery, as a preview).
CcSection {
  id: card
  readonly property var controls: center.controls
  readonly property bool galleryPreview: parent.galleryPreview
  anchors.fill: parent
  title: "Sound"
  detail: !card.controls.controlPresent("sound") ? "Unavailable" : card.controls.muted ? "Muted" : Math.round(card.controls.volume * 100) + "%"
  showChevron: !galleryPreview && !card.center.editMode && card.controls.outputs.length > 1
  chevronOpen: card.center.outputsOpen
  onChevronClicked: { card.center.outputsOpen = !card.center.outputsOpen; card.center.inputsOpen = false }

  CcSlider {
    center: card.center
    visible: galleryPreview || card.controls.controlPresent("sound")
    icon: card.controls.muted || card.controls.volume <= 0 ? "󰖁" : card.controls.volume < 0.34 ? "󰕿" : card.controls.volume < 0.67 ? "󰖀" : "󰕾"
    value: card.controls.muted ? 0 : card.controls.volume
    onMoved: function(v) {
      card.controls.sink.audio.volume = v
      if (card.controls.sink.audio.muted && v > 0) card.controls.sink.audio.muted = false
    }
  }
  // Output picker, revealed by the › button.
  Repeater {
    model: !galleryPreview && card.center.outputsOpen && !card.center.editMode ? card.controls.outputs : []
    delegate: CcDeviceRow {
      required property var modelData
      center: card.center
      device: modelData
      selected: modelData === card.controls.sink
      icon: "󰓃"
      onPicked: Pipewire.preferredDefaultAudioSink = modelData
    }
  }
  Text {
    visible: !galleryPreview && !card.controls.controlPresent("sound")
    text: "No audio output available"
    color: card.center.textMuted
    font.family: card.center.host.theme.textFontFamily
    font.letterSpacing: card.center.host.theme.tracking(card.center.host.theme.textFontFamily, card.center.host.theme.px(12))
    font.features: { "tnum": 1 }
    font.pixelSize: card.center.host.theme.px(12)
    Layout.fillWidth: true
  }
}
