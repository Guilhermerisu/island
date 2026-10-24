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
  // Output picker, revealed by the › button. The rows are kept by sink name
  // while it's closed too, so a stream coming or going doesn't rebuild them
  // and opening the picker doesn't animate every row in. A ListView rather
  // than a Repeater, so an output that goes away fades out in place while
  // the rest slide up (the card's height follows, in ControlLayout).
  readonly property bool outputsShown: !galleryPreview && card.center.outputsOpen && !card.center.editMode
  KeyedListModel {
    id: outputRows
    // The label rides along, so a row still reads right while it fades out
    // after its node is gone.
    values: card.galleryPreview ? [] : card.controls.outputs.map(function(n) {
      return { name: String(n.name || n.id), label: String(n.description || n.nickname || n.name || "") }
    })
    keyOf: function(r) { return r.name }
  }
  // The live node for a row: the model holds plain values only.
  function outputFor(name) {
    var outputs = card.controls.outputs
    for (var i = 0; i < outputs.length; i++) if (String(outputs[i].name || outputs[i].id) === name) return outputs[i]
    return null
  }
  ListView {
    id: outputList
    Layout.fillWidth: true
    Layout.preferredHeight: contentHeight
    interactive: false
    spacing: 6
    // Fades with the picker opening and closing, while the card's height
    // eases; out on the shorter exit pace.
    opacity: card.outputsShown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: card.center.host.theme; pace: card.outputsShown ? "fade" : "exit"; curve: card.outputsShown ? "fade" : "exit" } }
    model: outputRows.model
    // An output plugged in while the picker is open fades in; one unplugged
    // fades out where it was. The first fill just appears.
    add: Transition {
      enabled: outputRows.primed && card.outputsShown
      MotionAnimation { theme: card.center.host.theme; property: "opacity"; from: 0; to: 1; pace: "fade"; curve: "fade" }
    }
    remove: Transition {
      enabled: card.outputsShown
      MotionAnimation { theme: card.center.host.theme; property: "opacity"; to: 0; pace: "exit"; curve: "exit" }
    }
    // Also settles opacity, in case a row was still fading in.
    displaced: Transition {
      MotionAnimation { theme: card.center.host.theme; property: "y"; pace: "standard" }
      MotionAnimation { theme: card.center.host.theme; property: "opacity"; to: 1; pace: "fade"; curve: "fade" }
    }
    delegate: CcDeviceRow {
      id: output
      required property var entry
      readonly property var modelData: card.outputFor(entry.name)
      width: ListView.view.width
      height: 32
      enabled: !!modelData
      center: card.center
      device: modelData || ({ description: entry.label })
      selected: !!modelData && modelData === card.controls.sink
      icon: "󰓃"
      onPicked: if (modelData) Pipewire.preferredDefaultAudioSink = modelData
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
