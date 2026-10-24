import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../components"

// The Microphone card: the input volume, and the input picker behind its ›
// button. Loaded by the ControlCenter (and its gallery, as a preview).
CcSection {
  id: card
  readonly property var controls: center.controls
  readonly property bool galleryPreview: parent.galleryPreview
  anchors.fill: parent
  title: "Microphone"
  detail: !card.controls.controlPresent("microphone") ? "Unavailable" : card.controls.microphoneMuted ? "Muted" : Math.round(card.controls.microphoneVolume * 100) + "%"
  showChevron: !galleryPreview && !card.center.editMode && card.controls.inputs.length > 1
  chevronOpen: card.center.inputsOpen
  chevronLabel: "Microphone Input"
  chevronHideLabel: "Hide Inputs"
  onChevronClicked: { card.center.inputsOpen = !card.center.inputsOpen; card.center.outputsOpen = false }

  CcSlider {
    center: card.center
    enabled: card.controls.microphoneReady
    icon: "󰍬"
    value: card.controls.microphoneVolume
    onMoved: function(v) {
      if (card.controls.microphoneReady) card.controls.microphoneSource.audio.volume = v
    }
    Tooltip { theme: center.host.theme; text: "Microphone Input Volume" }
  }
  // Input picker, as the Sound card's output picker: rows kept by source
  // name, fading in and out in place while the rest slide (the card's height
  // follows, in ControlLayout).
  readonly property bool inputsShown: !galleryPreview && card.center.inputsOpen && !card.center.editMode
  KeyedListModel {
    id: inputRows
    // The label rides along, so a row still reads right while it fades out
    // after its node is gone.
    values: card.galleryPreview ? [] : card.controls.inputs.map(function(n) {
      return { name: String(n.name || n.id), label: String(n.description || n.nickname || n.name || "") }
    })
    keyOf: function(r) { return r.name }
  }
  // The live node for a row: the model holds plain values only.
  function inputFor(name) {
    var inputs = card.controls.inputs
    for (var i = 0; i < inputs.length; i++) if (String(inputs[i].name || inputs[i].id) === name) return inputs[i]
    return null
  }
  ListView {
    Layout.fillWidth: true
    Layout.preferredHeight: contentHeight
    interactive: false
    spacing: 6
    opacity: card.inputsShown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: card.center.host.theme; pace: card.inputsShown ? "fade" : "exit"; curve: card.inputsShown ? "fade" : "exit" } }
    model: inputRows.model
    add: Transition {
      enabled: inputRows.primed && card.inputsShown
      MotionAnimation { theme: card.center.host.theme; property: "opacity"; from: 0; to: 1; pace: "fade"; curve: "fade" }
    }
    remove: Transition {
      enabled: card.inputsShown
      MotionAnimation { theme: card.center.host.theme; property: "opacity"; to: 0; pace: "exit"; curve: "exit" }
    }
    // Also settles opacity, in case a row was still fading in.
    displaced: Transition {
      MotionAnimation { theme: card.center.host.theme; property: "y"; pace: "standard" }
      MotionAnimation { theme: card.center.host.theme; property: "opacity"; to: 1; pace: "fade"; curve: "fade" }
    }
    delegate: CcDeviceRow {
      required property var entry
      readonly property var modelData: card.inputFor(entry.name)
      width: ListView.view.width
      height: 32
      enabled: !!modelData
      center: card.center
      device: modelData || ({ description: entry.label })
      selected: !!modelData && modelData === card.controls.microphoneSource
      icon: "󰍬"
      onPicked: if (modelData) Pipewire.preferredDefaultAudioSource = modelData
    }
  }
}
