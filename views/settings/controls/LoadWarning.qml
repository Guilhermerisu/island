import QtQuick
import QtQuick.Layouts
import Quickshell

// Over every pane while island.json couldn't be read: why, what the island
// does meanwhile, and the file to fix. `view` is the SettingsView.
Rectangle {
  id: warning
  required property var view
  readonly property var store: view.host.settingsStore
  visible: store.loadError !== ""
  Layout.fillWidth: true
  implicitHeight: body.implicitHeight + 24
  radius: view.host.theme.radii.card
  color: view.host.theme.withAlpha(view.host.theme.system.orange, 0.14)
  border.width: 1
  border.color: view.host.theme.withAlpha(view.host.theme.system.orange, 0.45)
  RowLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 14
    anchors.rightMargin: 12
    spacing: 12
    Text {
      Layout.alignment: Qt.AlignTop
      text: "󰀦"
      color: warning.view.host.theme.system.orange
      font.family: warning.view.host.theme.fontFamily
      font.pixelSize: warning.view.host.theme.px(18)
    }
    Column {
      Layout.fillWidth: true
      spacing: 2
      Text {
        width: parent.width
        text: "island.json couldn't be read"
        color: warning.view.text
        font.family: warning.view.host.theme.textFontFamily
        font.letterSpacing: warning.view.host.theme.tracking(warning.view.host.theme.textFontFamily, warning.view.detailFontSize)
        font.pixelSize: warning.view.detailFontSize
        font.weight: Font.Medium
      }
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "The island is using the defaults (" + warning.store.loadError + "). A copy of the file is in island.json.broken; the next change made here writes a new island.json."
        color: warning.view.textMuted
        font.family: warning.view.host.theme.textFontFamily
        font.letterSpacing: warning.view.host.theme.tracking(warning.view.host.theme.textFontFamily, warning.view.detailCaptionFontSize)
        font.pixelSize: warning.view.detailCaptionFontSize
      }
    }
    SettingsButton {
      view: warning.view
      label: "Open File"
      onClicked: Quickshell.execDetached(["omarchy-launch-editor", warning.store.path])
    }
  }
}
