import QtQuick
import QtQuick.Layouts

// One shortcut, like a row of macOS's Keyboard Shortcuts: the name, and the
// keys on the right. Click the keys to type new ones; keys that are
// taken add a warning line with Cancel and Replace.
// `view` is the SettingsView, for its colours; `keybinds` the KeybindsPage.
Item {
  id: shortcutRow
  required property var view
  required property var keybinds
  property var entry: ({})
  property bool last: false
  readonly property bool recording: shortcutRow.keybinds.recordingId === entry.id
  readonly property bool asking: shortcutRow.keybinds.pendingId === entry.id && shortcutRow.keybinds.pendingConflict !== ""
  Layout.fillWidth: true
  implicitHeight: asking ? 64 : 42
  Behavior on implicitHeight { NumberAnimation { duration: shortcutRow.view.animDuration; easing.type: Easing.OutCubic } }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.right: keysField.left
    anchors.rightMargin: 10
    y: 10
    text: shortcutRow.entry.label
    elide: Text.ElideRight
    color: shortcutRow.view.text
    font.family: "Adwaita Sans"
    font.pixelSize: shortcutRow.view.detailFontSize
  }
  Rectangle {
    id: keysField
    anchors.right: parent.right
    anchors.rightMargin: 10
    y: 7
    width: Math.max(shortcutRow.recording ? 150 : 0, keysText.implicitWidth + 16)
    height: 28
    radius: 6
    visible: !shortcutRow.asking
    color: shortcutRow.recording ? shortcutRow.view.host.theme.withAlpha(shortcutRow.view.accent, 0.16)
      : keysMouse.containsMouse ? shortcutRow.view.well : shortcutRow.view.host.theme.withAlpha(shortcutRow.view.well, 0)
    Behavior on width { NumberAnimation { duration: shortcutRow.view.animDuration; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: shortcutRow.view.animDuration; easing.type: Easing.OutCubic } }
    // Focus ring: settles in from slightly larger, like macOS's.
    Rectangle {
      anchors.centerIn: parent
      width: parent.width + 6
      height: parent.height + 6
      radius: parent.radius + 3
      color: "transparent"
      border.width: 3
      border.color: shortcutRow.view.host.theme.withAlpha(shortcutRow.view.accent, 0.55)
      opacity: shortcutRow.recording ? 1 : 0
      scale: shortcutRow.recording ? 1 : 1.12
      Behavior on opacity { NumberAnimation { duration: shortcutRow.view.animDuration; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: shortcutRow.view.animDuration * 1.2; easing.type: Easing.OutCubic } }
    }
    Text {
      id: keysText
      anchors.centerIn: parent
      text: shortcutRow.recording ? (shortcutRow.keybinds.recordHint || "Type Shortcut") : shortcutRow.keybinds.shortcutText(shortcutRow.entry.keys)
      color: shortcutRow.recording ? shortcutRow.view.accent
        : shortcutRow.entry.keys === "" ? shortcutRow.view.textMuted : shortcutRow.view.text
      font.family: "Adwaita Sans"
      font.pixelSize: shortcutRow.view.detailFontSize
      Behavior on color { ColorAnimation { duration: shortcutRow.view.animDuration; easing.type: Easing.OutCubic } }
    }
    MouseArea {
      id: keysMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: shortcutRow.recording ? shortcutRow.keybinds.stopRecording() : shortcutRow.keybinds.startRecording(shortcutRow.entry.id)
    }
  }
  Row {
    anchors.right: parent.right
    anchors.rightMargin: 10
    y: 7
    spacing: 6
    visible: shortcutRow.asking
    SettingsButton { view: shortcutRow.view; label: "Cancel"; onClicked: shortcutRow.keybinds.cancelPending() }
    SettingsButton { view: shortcutRow.view; label: "Replace"; primary: true; onClicked: shortcutRow.keybinds.applyPending() }
  }
  Row {
    x: 14
    y: 40
    spacing: 5
    visible: shortcutRow.asking
    Text {
      text: "󰀪"
      color: "#febc2e"
      font.family: shortcutRow.view.host.theme.fontFamily
      font.pixelSize: 12
    }
    Text {
      text: shortcutRow.keybinds.shortcutText(shortcutRow.keybinds.pendingKeys) + " is used by " + shortcutRow.keybinds.pendingConflict
      color: shortcutRow.view.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: shortcutRow.view.detailCaptionFontSize
    }
  }
  Rectangle {
    visible: !shortcutRow.last
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.bottom: parent.bottom
    height: 1
    color: shortcutRow.view.divider
  }
}
