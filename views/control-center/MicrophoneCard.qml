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
  Repeater {
    model: !galleryPreview && card.center.inputsOpen && !card.center.editMode ? card.controls.inputs : []
    delegate: Rectangle {
      id: inputRow
      required property var modelData
      readonly property bool isDefault: modelData === card.controls.microphoneSource
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      radius: 7
      color: inputMouse.containsMouse ? card.center.host.theme.withAlpha(card.center.text, 0.08) : "transparent"
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: inputCheck.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: String(inputRow.modelData.description || inputRow.modelData.nickname || inputRow.modelData.name || "")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: inputRow.isDefault ? card.center.text : card.center.textMuted
        font.family: center.host.theme.textFontFamily
        font.pixelSize: 12
      }
      Text {
        id: inputCheck
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: inputRow.isDefault
        text: "󰄬"
        color: card.center.accent
        font.family: card.center.iconFont
        font.pixelSize: 14
      }
      MouseArea {
        id: inputMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Pipewire.preferredDefaultAudioSource = inputRow.modelData
      }
    }
  }
}
