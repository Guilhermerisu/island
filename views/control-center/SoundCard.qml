import QtQuick
import QtQuick.Layouts
import "../../components"

// The Sound card: the volume slider, and the output picker behind its ›
// button. Loaded by the ControlCenter (and its gallery, as a preview).
CcSection {
  id: card
  readonly property var controls: center.controls
  readonly property bool galleryPreview: parent.galleryPreview
  anchors.fill: parent
  title: "Sound"
  vertical: !galleryPreview && card.controls.isVertical("sound") && card.controls.controlPresent("sound")
  detail: !card.controls.controlPresent("sound") ? "Unavailable" : card.controls.muted ? "Muted" : Math.round(card.controls.volume * 100) + "%"
  showChevron: !galleryPreview && !card.center.editMode && card.controls.outputs.length > 0
  chevronOpen: card.center.outputsOpen
  onChevronClicked: { card.center.outputsOpen = !card.center.outputsOpen; card.center.inputsOpen = false }
  // Silence the output, keeping its volume for when it's back. Hidden in
  // edit mode, like the ›: the card is a drag handle then.
  toggleIcon: galleryPreview || card.center.editMode || !card.controls.controlPresent("sound") ? "" : card.controls.muted ? "󰖁" : "󰕾"
  toggleOn: card.controls.muted
  toggleTip: card.controls.muted ? "Unmute" : "Mute"
  onToggleClicked: if (card.controls.sink && card.controls.sink.audio) card.controls.sink.audio.muted = !card.controls.muted

  CcSlider {
    center: card.center
    vertical: card.vertical
    title: card.title
    detail: card.detail
    visible: galleryPreview || card.controls.controlPresent("sound")
    icon: card.controls.muted || card.controls.volume <= 0 ? "󰖁" : card.controls.volume < 0.34 ? "󰕿" : card.controls.volume < 0.67 ? "󰖀" : "󰕾"
    value: card.controls.muted ? 0 : card.controls.volume
    onMoved: function(v) {
      card.controls.sink.audio.volume = v
      if (card.controls.sink.audio.muted && v > 0) card.controls.sink.audio.muted = false
    }
  }
  // Output picker, revealed by the › button (the list is CcDeviceList, which
  // the compact sizes' popover shows too).
  readonly property bool outputsShown: !galleryPreview && !card.vertical && card.center.outputsOpen && !card.center.editMode
  // Live output level, as the Microphone card's. Only listens to the sink
  // while the picker is open.
  PeakBar {
    center: card.center
    node: card.controls.sink
    shown: card.outputsShown
    muted: card.controls.muted
  }
  CcDeviceList {
    center: card.center
    shown: card.outputsShown
    preview: card.galleryPreview
  }
  Text {
    visible: !galleryPreview && !card.controls.controlPresent("sound")
    text: "No audio output available"
    wrapMode: Text.WordWrap
    color: card.center.textMuted
    font.family: card.center.host.theme.textFontFamily
    font.letterSpacing: card.center.host.theme.tracking(card.center.host.theme.textFontFamily, card.center.host.theme.size.callout)
    font.features: { "tnum": 1 }
    font.pixelSize: card.center.host.theme.size.callout
    Layout.fillWidth: true
  }
}
