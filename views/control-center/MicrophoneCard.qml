import QtQuick
import QtQuick.Layouts

// The Microphone card: the input volume, and the input picker behind its ›
// button. Loaded by the ControlCenter (and its gallery, as a preview).
CcSection {
  id: card
  readonly property var controls: center.controls
  readonly property bool galleryPreview: parent.galleryPreview
  anchors.fill: parent
  title: "Microphone"
  vertical: !galleryPreview && card.controls.isVertical("microphone")
  detail: !card.controls.controlPresent("microphone") ? "Unavailable" : card.controls.microphoneMuted ? "Muted" : Math.round(card.controls.microphoneVolume * 100) + "%"
  showChevron: !galleryPreview && !card.center.editMode && card.controls.inputs.length > 0
  chevronOpen: card.center.inputsOpen
  chevronLabel: "Microphone Input"
  chevronHideLabel: "Hide Inputs"
  onChevronClicked: { card.center.inputsOpen = !card.center.inputsOpen; card.center.outputsOpen = false }
  // Hidden in edit mode, like the ›: the card is a drag handle then.
  toggleIcon: galleryPreview || card.center.editMode || !card.controls.controlPresent("microphone") ? "" : card.controls.microphoneMuted ? "󰍭" : "󰍬"
  toggleTip: card.controls.microphoneMuted ? "Unmute" : "Mute"
  onToggleClicked: card.controls.toggleMicrophoneMute()

  CcSlider {
    center: card.center
    vertical: card.vertical
    title: card.title
    detail: card.detail
    enabled: card.controls.microphoneReady
    icon: "󰍬"
    value: card.controls.microphoneVolume
    onMoved: function(v) {
      if (card.controls.microphoneReady) card.controls.microphoneSource.audio.volume = v
    }
  }
  // Input picker, as the Sound card's output picker (CcDeviceList).
  readonly property bool inputsShown: !galleryPreview && !card.vertical && card.center.inputsOpen && !card.center.editMode
  // Live input level. Only listens to the mic while the picker is open.
  PeakBar {
    center: card.center
    node: card.controls.microphoneSource
    shown: card.inputsShown
    muted: card.controls.microphoneMuted
  }
  CcDeviceList {
    center: card.center
    input: true
    shown: card.inputsShown
    preview: card.galleryPreview
  }
}
