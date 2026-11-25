import QtQuick
import QtQuick.Layouts
import "../../components"

// The popover of a slider (Sound, Microphone, Display) in the control center's
// compact sizes, opened by CcControlState.openPopover: its slider, as in the
// Normal card, and for Sound and the microphone the list of sources behind the
// card's › (CcDeviceList), with the live level under the slider. Choosing a
// source does what the Normal card's picker does. `center` is the
// ControlCenter, `controlKey` the control.
Item {
  id: pop
  required property var center
  required property string controlKey
  readonly property var controls: center.controls
  readonly property bool microphone: controlKey === "microphone"
  readonly property bool sources: controlKey !== "display"
  // A layout's own size comes from its children, which have no width to ask.
  implicitWidth: 240
  implicitHeight: column.implicitHeight

  CcControlState { id: info; center: pop.center; controlKey: pop.controlKey }

  ColumnLayout {
    id: column
    anchors.fill: parent
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      Text {
        Layout.fillWidth: true
        text: info.title
        color: pop.center.text
        font.family: pop.center.host.theme.textFontFamily
        font.pixelSize: pop.center.host.theme.size.body
        font.weight: Font.DemiBold
        font.letterSpacing: pop.center.host.theme.tracking(pop.center.host.theme.textFontFamily, pop.center.host.theme.size.body)
      }
      Text {
        text: info.detail
        color: pop.center.textMuted
        font.family: pop.center.host.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: pop.center.host.theme.size.subheadline
        font.letterSpacing: pop.center.host.theme.tracking(pop.center.host.theme.textFontFamily, pop.center.host.theme.size.subheadline)
      }
    }
    CcSlider {
      center: pop.center
      icon: info.icon
      value: info.value
      enabled: info.available
      onMoved: function(v) { info.setValue(v) }
    }
    // Live level of the node in use, as under the Normal picker.
    PeakBar {
      center: pop.center
      node: pop.microphone ? pop.controls.microphoneSource : pop.controls.sink
      shown: pop.sources && info.hasSources
      muted: pop.microphone ? pop.controls.microphoneMuted : pop.controls.muted
    }
    // Takes what the popover has left and scrolls past it.
    CcDeviceList {
      Layout.fillHeight: true
      center: pop.center
      input: pop.microphone
      shown: pop.sources
      interactive: contentHeight > height
      clip: true
    }
  }
}
