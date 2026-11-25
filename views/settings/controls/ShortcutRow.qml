import QtQuick
import "../../../components"
import QtQuick.Layouts

// One shortcut, like a row of macOS's Keyboard Shortcuts: the name, and the
// keys on the right as keycaps. Click the keys to type new ones; keys that are
// taken add a warning line with Cancel and Replace.
// `indent` sets a row in under the one it belongs to. With a `detail` line
// and `boxed`, it matches a SettingsRow with its keys in a field
// `fieldWidth` wide (an addon's options), its keycaps joined by "+".
// Otherwise (the Keybinds page) an optional `icon` tile leads the row and
// the keycaps sit side by side, all alike.
// `view` is the SettingsView, for its colours; `keybinds` the KeybindsPage.
Item {
  id: shortcutRow
  required property var view
  required property var keybinds
  property var entry: ({})
  property bool last: false
  property int indent: 0
  property string detail: ""
  property bool boxed: false
  property real fieldWidth: 200
  property string icon: ""
  property color iconTint: view.accent
  // As SettingsRow: at least 48, 12 at the sides, a 24 icon 12 from the text.
  readonly property real restHeight: Math.max(48, labelColumn.implicitHeight + 16)
  readonly property real textLeft: 12 + indent + (icon !== "" ? 36 : 0)
  readonly property real edgeMargin: 12
  // An assigned shortcut shows its clear button only while the row is
  // hovered (or the button has keyboard focus), as macOS's lists do.
  readonly property bool clearable: !!entry.keys && entry.removable !== false && !recording && !asking
  readonly property bool clearShown: clearable && (rowHover.hovered || clearButton.activeFocus)
  property real clearReveal: clearShown ? 1 : 0
  Behavior on clearReveal { MotionAnimation { theme: shortcutRow.view.host.theme; pace: "standard" } }
  HoverHandler { id: rowHover }
  PaneIcon {
    visible: shortcutRow.icon !== ""
    view: shortcutRow.view
    flat: true
    x: 12 + shortcutRow.indent
    y: (shortcutRow.restHeight - height) / 2
    width: 24
    height: 24
    glyph: shortcutRow.icon
    tint: shortcutRow.iconTint
  }
  readonly property bool recording: shortcutRow.keybinds.recordingId === entry.id
  readonly property bool asking: shortcutRow.keybinds.pendingId === entry.id && shortcutRow.keybinds.pendingConflict !== ""
  Layout.fillWidth: true
  implicitHeight: restHeight + (asking ? 22 : 0)
  Behavior on implicitHeight { MotionAnimation { theme: shortcutRow.view.host.theme; pace: "standard" } }
  // The warning line sits below the resting height; clipped, it rolls out
  // with the row instead of spilling over the next one.
  clip: true

  Column {
    id: labelColumn
    anchors.left: parent.left
    anchors.leftMargin: shortcutRow.textLeft
    anchors.right: keysField.left
    anchors.rightMargin: 10
    y: (shortcutRow.restHeight - height) / 2
    spacing: 2
    Text {
      width: parent.width
      text: shortcutRow.entry.label
      elide: Text.ElideRight
      color: shortcutRow.view.text
      font.family: shortcutRow.view.host.theme.textFontFamily
      font.letterSpacing: shortcutRow.view.host.theme.tracking(shortcutRow.view.host.theme.textFontFamily, shortcutRow.view.detailFontSize)
      font.pixelSize: shortcutRow.view.detailFontSize
      font.weight: shortcutRow.detail !== "" ? Font.Medium : Font.Normal
    }
    Text {
      width: parent.width
      visible: shortcutRow.detail !== ""
      text: shortcutRow.detail
      elide: Text.ElideRight
      color: shortcutRow.view.textMuted
      font.family: shortcutRow.view.host.theme.textFontFamily
      font.letterSpacing: shortcutRow.view.host.theme.tracking(shortcutRow.view.host.theme.textFontFamily, shortcutRow.view.detailCaptionFontSize)
      font.pixelSize: shortcutRow.view.detailCaptionFontSize
    }
  }
  Rectangle {
    id: keysField
    anchors.right: parent.right
    // Slides left to make room for the clear button while the row is hovered.
    anchors.rightMargin: shortcutRow.edgeMargin + (clearButton.width + 4) * shortcutRow.clearReveal
    y: (shortcutRow.restHeight - height) / 2
    readonly property bool caps: !shortcutRow.recording && shortcutRow.entry.keys !== ""
    width: shortcutRow.boxed ? shortcutRow.fieldWidth
      : Math.max(shortcutRow.recording ? 150 : 0, (caps ? keycaps.implicitWidth : keysText.implicitWidth) + (caps ? 8 : 16))
    height: 28
    radius: 6
    scale: keysMouse.pressed ? 0.98 : 1
    Behavior on scale { id: scaleMotion; MotionAnimation { theme: shortcutRow.view.host.theme; pace: towards(scaleMotion.targetValue, keysMouse.pressed ? "press" : "standard") } }
    // Cross-fades with Cancel and Replace while a conflict is asked about.
    opacity: shortcutRow.asking ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { id: opacityMotion; MotionAnimation { theme: shortcutRow.view.host.theme; pace: towards(opacityMotion.targetValue, shortcutRow.asking ? "exit" : "fade"); curve: "fade" } }
    color: shortcutRow.recording ? shortcutRow.view.host.theme.accentFill("soft")
      : shortcutRow.boxed ? shortcutRow.view.host.theme.fill(keysMouse.containsMouse ? "subtle" : "quiet")
      : keysMouse.containsMouse && !caps ? shortcutRow.view.well : shortcutRow.view.host.theme.withAlpha(shortcutRow.view.well, 0)
    // Boxed, it's a field as the text fields and pop-ups beside it.
    border.width: shortcutRow.boxed && !shortcutRow.recording ? 1 : 0
    border.color: shortcutRow.view.host.theme.fill("raised")
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
    // The keys as keycaps, as macOS shows shortcuts, joined by a quiet "+".
    Row {
      id: keycaps
      anchors.centerIn: parent
      visible: keysField.caps
      spacing: shortcutRow.boxed ? 6 : 4
      Repeater {
        model: keysField.caps ? shortcutRow.keybinds.shortcutText(shortcutRow.entry.keys).split(" + ") : []
        delegate: Row {
          id: capGroup
          required property string modelData
          required property int index
          spacing: 6
          Text {
            visible: shortcutRow.boxed && capGroup.index > 0
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            color: shortcutRow.view.textMuted
            font.family: shortcutRow.view.host.theme.textFontFamily
            font.pixelSize: shortcutRow.view.detailCaptionFontSize
          }
          Rectangle {
            id: cap
            readonly property string modelData: capGroup.modelData
            // A single-character key (",") still reads as a key, not a mark.
            width: Math.max(26, capText.implicitWidth + 14)
            height: shortcutRow.boxed ? 22 : 26
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
              font.weight: Font.DemiBold
            }
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
      // Still drawn while it fades out under Cancel and Replace; not clickable.
      enabled: !shortcutRow.asking
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: shortcutRow.recording ? shortcutRow.keybinds.stopRecording() : shortcutRow.keybinds.startRecording(shortcutRow.entry.id)
    }
  }
  SettingsButton {
    id: clearButton
    view: shortcutRow.view
    anchors.right: parent.right
    anchors.rightMargin: shortcutRow.edgeMargin
    y: (shortcutRow.restHeight - height) / 2
    implicitWidth: implicitHeight
    label: "×"
    opacity: shortcutRow.clearReveal
    visible: shortcutRow.clearable
    // Only reachable by hovering the row, which reveals it, or by Tab.
    onClicked: shortcutRow.keybinds.clearShortcut(shortcutRow.entry.id)
    activeFocusOnTab: shortcutRow.clearable
    Accessible.role: Accessible.Button
    Accessible.name: "Remove Shortcut" + " · " + shortcutRow.entry.label
    Accessible.onPressAction: if (shortcutRow.clearable) clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Tooltip { theme: clearButton.view.host.theme; text: "Remove Shortcut" }
  }
  Row {
    anchors.right: parent.right
    anchors.rightMargin: 10
    y: (shortcutRow.restHeight - 28) / 2
    spacing: 6
    opacity: shortcutRow.asking ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { id: opacityMotion2; MotionAnimation { theme: shortcutRow.view.host.theme; pace: towards(opacityMotion2.targetValue, shortcutRow.asking ? "fade" : "exit"); curve: "fade" } }
    SettingsButton { view: shortcutRow.view; label: "Cancel"; onClicked: shortcutRow.keybinds.cancelPending() }
    SettingsButton { view: shortcutRow.view; label: "Replace"; primary: true; onClicked: shortcutRow.keybinds.applyPending() }
  }
  Row {
    x: shortcutRow.textLeft
    y: shortcutRow.restHeight - 2
    spacing: 5
    opacity: shortcutRow.asking ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { id: opacityMotion3; MotionAnimation { theme: shortcutRow.view.host.theme; pace: towards(opacityMotion3.targetValue, shortcutRow.asking ? "fade" : "exit"); curve: "fade" } }
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
    anchors.leftMargin: shortcutRow.textLeft
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: shortcutRow.view.divider
  }
}
