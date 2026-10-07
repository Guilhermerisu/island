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
    delegate: Rectangle {
      id: outputRow
      required property var modelData
      readonly property bool isDefault: modelData === card.controls.sink
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      radius: 7
      color: outputMouse.containsMouse ? card.center.host.theme.withAlpha(card.center.text, 0.08) : "transparent"
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: outputCheck.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: String(outputRow.modelData.description || outputRow.modelData.nickname || outputRow.modelData.name || "")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: outputRow.isDefault ? card.center.text : card.center.textMuted
        font.family: card.center.host.theme.textFontFamily
        font.pixelSize: 12
      }
      Text {
        id: outputCheck
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: outputRow.isDefault
        text: "󰄬"
        color: card.center.accent
        font.family: card.center.iconFont
        font.pixelSize: 14
      }
      MouseArea {
        id: outputMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Pipewire.preferredDefaultAudioSink = outputRow.modelData
      }
    }
  }
  Text {
    visible: !galleryPreview && !card.controls.controlPresent("sound")
    text: "No audio output available"
    color: card.center.textMuted
    font.family: card.center.host.theme.textFontFamily
    font.pixelSize: 12
    Layout.fillWidth: true
  }
}
