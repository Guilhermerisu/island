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
  vertical: !galleryPreview && card.controls.isVertical("microphone")
  detail: !card.controls.controlPresent("microphone") ? "Unavailable" : card.controls.microphoneMuted ? "Muted" : Math.round(card.controls.microphoneVolume * 100) + "%"
  showChevron: !galleryPreview && !card.center.editMode && card.controls.inputs.length > 1
  chevronOpen: card.center.inputsOpen
  chevronLabel: "Microphone Input"
  chevronHideLabel: "Hide Inputs"
  onChevronClicked: { card.center.inputsOpen = !card.center.inputsOpen; card.center.outputsOpen = false }
  // Hidden in edit mode, like the ›: the card is a drag handle then.
  toggleIcon: galleryPreview || card.center.editMode || !card.controls.controlPresent("microphone") ? "" : card.controls.microphoneMuted ? "󰍭" : "󰍬"
  toggleOn: card.controls.microphoneMuted
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
    Tooltip { theme: center.host.theme; text: "Microphone Input Volume" }
  }
  // Input picker, as the Sound card's output picker: rows kept by source
  // name, fading in and out in place while the rest slide (the card's height
  // follows, in ControlLayout).
  readonly property bool inputsShown: !galleryPreview && !card.vertical && card.center.inputsOpen && !card.center.editMode
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
  // Live input level, as Omarchy's audio panel. Only listens to the mic while
  // the picker is open.
  PwNodePeakMonitor {
    id: peakMonitor
    node: card.controls.microphoneSource
    enabled: card.inputsShown && !!card.controls.microphoneSource
  }
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 4
    radius: 2
    color: card.center.host.theme.fill("strong")
    opacity: card.inputsShown ? (card.controls.microphoneMuted ? 0.35 : 1) : 0
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: card.center.host.theme; pace: card.inputsShown ? "fade" : "exit"; curve: card.inputsShown ? "fade" : "exit" } }
    Rectangle {
      height: parent.height
      radius: parent.radius
      width: parent.width * Math.max(0, Math.min(1, peakMonitor.peak))
      color: "white"
      Behavior on width { NumberAnimation { duration: 70 } }
    }
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
