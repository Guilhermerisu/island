import QtQuick
import "../../../components"
import QtQuick.Layouts

// One shortcut, like a row of macOS's Keyboard Shortcuts: the name, and the
// keys on the right as keycaps. Click the keys to type new ones; keys that are
// taken add a warning line with Cancel and Replace.
// `indent` sets a row in under the one it belongs to.
// `view` is the SettingsView, for its colours; `keybinds` the KeybindsPage.
Item {
  id: shortcutRow
  required property var view
  required property var keybinds
  property var entry: ({})
  property bool last: false
  property int indent: 0
  readonly property bool recording: shortcutRow.keybinds.recordingId === entry.id
  readonly property bool asking: shortcutRow.keybinds.pendingId === entry.id && shortcutRow.keybinds.pendingConflict !== ""
  Layout.fillWidth: true
  implicitHeight: asking ? 66 : 44
  Behavior on implicitHeight { MotionAnimation { theme: shortcutRow.view.host.theme; pace: "standard" } }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: 14 + shortcutRow.indent
    anchors.right: keysField.left
    anchors.rightMargin: 10
    y: 22 - height / 2
    text: shortcutRow.entry.label
    elide: Text.ElideRight
    color: shortcutRow.view.text
    font.family: shortcutRow.view.host.theme.textFontFamily
    font.letterSpacing: shortcutRow.view.host.theme.tracking(shortcutRow.view.host.theme.textFontFamily, shortcutRow.view.detailFontSize)
    font.pixelSize: shortcutRow.view.detailFontSize
  }
  Rectangle {
    id: keysField
    anchors.right: parent.right
    anchors.rightMargin: 10
    y: 8
    readonly property bool caps: !shortcutRow.recording && shortcutRow.entry.keys !== ""
    width: Math.max(shortcutRow.recording ? 150 : 0, (caps ? keycaps.implicitWidth : keysText.implicitWidth) + (caps ? 8 : 16))
    height: 28
    radius: 6
    scale: keysMouse.pressed ? 0.98 : 1
    Behavior on scale { MotionAnimation { theme: shortcutRow.view.host.theme; pace: keysMouse.pressed ? "press" : "standard" } }
    visible: !shortcutRow.asking
    color: shortcutRow.recording ? shortcutRow.view.host.theme.accentFill("soft")
      : keysMouse.containsMouse && !caps ? shortcutRow.view.well : shortcutRow.view.host.theme.withAlpha(shortcutRow.view.well, 0)
    Behavior on width { MotionAnimation { theme: shortcutRow.view.host.theme; pace: "standard" } }
    Behavior on color { MotionColorAnimation { theme: shortcutRow.view.host.theme } }
    // Focus ring: settles in from slightly larger, like macOS's.
    Rectangle {
      anchors.centerIn: parent
      width: parent.width + 6
      height: parent.height + 6
      radius: parent.radius + 3
      color: "transparent"
      border.width: 3
      border.color: shortcutRow.view.host.theme.accentFill("ring")
      opacity: shortcutRow.recording ? 1 : 0
      scale: shortcutRow.recording ? 1 : 1.12
      Behavior on opacity { MotionAnimation { theme: shortcutRow.view.host.theme; pace: "fade"; curve: "fade" } }
      Behavior on scale { MotionAnimation { theme: shortcutRow.view.host.theme; pace: "standard" } }
    }
    // The keys as keycaps, as macOS shows shortcuts.
    Row {
      id: keycaps
      anchors.centerIn: parent
      visible: keysField.caps
      spacing: 6
      Repeater {
        model: keysField.caps ? shortcutRow.keybinds.shortcutText(shortcutRow.entry.keys).split(" + ") : []
        delegate: Rectangle {
          id: cap
          required property string modelData
          width: Math.max(height, capText.implicitWidth + 12)
          height: 22
          radius: shortcutRow.view.host.theme.radii.small
          color: shortcutRow.view.host.theme.solid(keysMouse.containsMouse ? "stronger" : "raised")
          border.width: 1
          border.color: shortcutRow.view.host.theme.fill("subtle")
          Behavior on color { MotionColorAnimation { theme: shortcutRow.view.host.theme } }
          // The key's lower edge, as a keycap's.
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: parent.radius / 2
            anchors.rightMargin: parent.radius / 2
            height: 1
            color: Qt.rgba(0, 0, 0, 0.35)
          }
          Text {
            id: capText
            anchors.centerIn: parent
            text: cap.modelData
            color: shortcutRow.view.text
            font.family: shortcutRow.view.host.theme.textFontFamily
            font.letterSpacing: shortcutRow.view.host.theme.tracking(shortcutRow.view.host.theme.textFontFamily, shortcutRow.view.detailCaptionFontSize)
            font.pixelSize: shortcutRow.view.detailCaptionFontSize
            font.weight: Font.Medium
          }
        }
      }
    }
    Text {
      id: keysText
      visible: !keysField.caps
      anchors.centerIn: parent
      text: shortcutRow.recording ? (shortcutRow.keybinds.recordHint || "Type Shortcut") : shortcutRow.keybinds.shortcutText(shortcutRow.entry.keys)
      color: shortcutRow.recording ? shortcutRow.view.accent
        : shortcutRow.entry.keys === "" ? shortcutRow.view.textMuted : shortcutRow.view.text
      font.family: shortcutRow.view.host.theme.textFontFamily
      font.letterSpacing: shortcutRow.view.host.theme.tracking(shortcutRow.view.host.theme.textFontFamily, shortcutRow.view.detailFontSize)
      font.pixelSize: shortcutRow.view.detailFontSize
      Behavior on color { MotionColorAnimation { theme: shortcutRow.view.host.theme } }
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
    y: 8
    spacing: 6
    visible: shortcutRow.asking
    SettingsButton { view: shortcutRow.view; label: "Cancel"; onClicked: shortcutRow.keybinds.cancelPending() }
    SettingsButton { view: shortcutRow.view; label: "Replace"; primary: true; onClicked: shortcutRow.keybinds.applyPending() }
  }
  Row {
    x: 14 + shortcutRow.indent
    y: 42
    spacing: 5
    visible: shortcutRow.asking
    Text {
      text: "󰀪"
      color: "#febc2e"
      font.family: shortcutRow.view.host.theme.fontFamily
      font.pixelSize: shortcutRow.view.host.theme.px(12)
    }
    Text {
      text: shortcutRow.keybinds.shortcutText(shortcutRow.keybinds.pendingKeys) + " is used by " + shortcutRow.keybinds.pendingConflict
      color: shortcutRow.view.textMuted
      font.family: shortcutRow.view.host.theme.textFontFamily
      font.letterSpacing: shortcutRow.view.host.theme.tracking(shortcutRow.view.host.theme.textFontFamily, shortcutRow.view.detailCaptionFontSize)
      font.pixelSize: shortcutRow.view.detailCaptionFontSize
    }
  }
  Rectangle {
    visible: !shortcutRow.last
    anchors.left: parent.left
    anchors.leftMargin: 14 + shortcutRow.indent
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.bottom: parent.bottom
    height: 1
    color: shortcutRow.view.divider
  }
}
