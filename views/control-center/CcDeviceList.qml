import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../components"

// The list of audio outputs (or inputs) behind a Sound or Microphone ›: one
// CcDeviceRow per device, the one in use lit, a click makes it the default.
// Shared by the Normal cards (SoundCard, MicrophoneCard) and the popover of
// the compact sizes (CcLevelPopover). The rows are kept by node name while
// it's closed too, so a stream coming or going doesn't rebuild them and
// opening the picker doesn't animate every row in. A ListView rather than a
// Repeater, so a device that goes away fades out in place while the rest
// slide up (the card's height follows, in ControlLayout). `center` is the
// ControlCenter.
ListView {
  id: list
  required property var center
  // Inputs (the microphones) rather than outputs.
  property bool input: false
  // Open: fades in, and the rows animate for what comes and goes.
  property bool shown: false
  // The gallery's preview of a card, which lists nothing.
  property bool preview: false
  readonly property var controls: center.controls

  Layout.fillWidth: true
  Layout.preferredHeight: contentHeight
  interactive: false
  spacing: 6
  // Fades with the picker opening and closing, while the card's height
  // eases; out on the shorter exit pace.
  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: list.center.host.theme; pace: list.shown ? "fade" : "exit"; curve: list.shown ? "fade" : "exit" } }

  KeyedListModel {
    id: rows
    // The label rides along, so a row still reads right while it fades out
    // after its node is gone.
    values: list.preview ? [] : (list.input ? list.controls.inputs : list.controls.outputs).map(function(n) {
      return { name: String(n.name || n.id), label: String(n.description || n.nickname || n.name || "") }
    })
    keyOf: function(r) { return r.name }
  }
  // The live node for a row: the model holds plain values only.
  function nodeFor(name) {
    var nodes = list.input ? list.controls.inputs : list.controls.outputs
    for (var i = 0; i < nodes.length; i++) if (String(nodes[i].name || nodes[i].id) === name) return nodes[i]
    return null
  }

  model: rows.model
  // A device plugged in while the picker is open fades in; one unplugged
  // fades out where it was. The first fill just appears.
  add: Transition {
    enabled: rows.primed && list.shown
    MotionAnimation { theme: list.center.host.theme; property: "opacity"; from: 0; to: 1; pace: "fade"; curve: "fade" }
  }
  remove: Transition {
    enabled: list.shown
    MotionAnimation { theme: list.center.host.theme; property: "opacity"; to: 0; pace: "exit"; curve: "exit" }
  }
  // Also settles opacity, in case a row was still fading in.
  displaced: Transition {
    MotionAnimation { theme: list.center.host.theme; property: "y"; pace: "standard" }
    MotionAnimation { theme: list.center.host.theme; property: "opacity"; to: 1; pace: "fade"; curve: "fade" }
  }
  delegate: CcDeviceRow {
    required property var entry
    readonly property var modelData: list.nodeFor(entry.name)
    width: ListView.view.width
    height: 32
    enabled: !!modelData
    center: list.center
    device: modelData || ({ description: entry.label })
    selected: !!modelData && modelData === (list.input ? list.controls.microphoneSource : list.controls.sink)
    icon: list.input ? "󰍬" : "󰓃"
    onPicked: if (modelData) {
      if (list.input) Pipewire.preferredDefaultAudioSource = modelData
      else Pipewire.preferredDefaultAudioSink = modelData
    }
  }
}
