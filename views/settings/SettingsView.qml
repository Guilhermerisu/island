import QtQuick
import QtQuick.Layouts

// The island's own settings, laid out like iOS Settings: a navigation bar with
// a back button, then inset grouped rows with switches and segmented pickers.
// Opened from the control center's gear button; Esc goes back to it. Changes
// apply live and are saved to ~/.config/omarchy/island.json (see Island.qml).
ColumnLayout {
  id: settingsView
  required property var host
  property bool active: false
  readonly property var settings: host.settings

  readonly property color text: host.colorText
  readonly property color textMuted: host.colorMuted
  readonly property color card: host.withAlpha(host.colorText, 0.07)
  readonly property color well: host.withAlpha(host.colorText, 0.1)
  readonly property color divider: host.withAlpha(host.colorText, 0.08)
  readonly property int animDuration: 180 * host.motionScale

  spacing: 8
  onActiveChanged: if (active) Qt.callLater(function() { settingsView.forceActiveFocus() })
  Keys.onEscapePressed: host.view = "controls"

  // iOS switch: accent track when on, white knob sliding across.
  component SettingsSwitch: Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool checked)
    implicitWidth: 46
    implicitHeight: 28
    radius: 14
    color: checked ? settingsView.host.colorAccent : settingsView.well
    Behavior on color { ColorAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
    Rectangle {
      width: 24; height: 24; radius: 12
      y: 2
      x: sw.checked ? sw.width - width - 2 : 2
      color: "#ffffff"
      Behavior on x { NumberAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: sw.toggled(!sw.checked)
    }
  }

  // iOS segmented control for a few fixed values.
  component SettingsSegments: Rectangle {
    id: seg
    property var options: []   // [{ label, value }]
    property var value
    signal picked(var value)
    readonly property int index: {
      for (var i = 0; i < options.length; i++) if (options[i].value === value) return i
      return -1
    }
    implicitWidth: options.length * (options.length > 3 ? 70 : 62) + 4
    implicitHeight: 28
    radius: 9
    color: settingsView.well
    Rectangle {
      visible: seg.index >= 0
      y: 2
      height: parent.height - 4
      width: (parent.width - 4) / Math.max(1, seg.options.length)
      x: 2 + Math.max(0, seg.index) * width
      radius: 7
      color: settingsView.host.withAlpha(settingsView.text, 0.2)
      Behavior on x { NumberAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
    }
    Row {
      anchors.fill: parent
      anchors.margins: 2
      Repeater {
        model: seg.options
        delegate: Item {
          required property var modelData
          width: parent.width / seg.options.length
          height: parent.height
          Text {
            anchors.centerIn: parent
            text: modelData.label
            color: settingsView.text
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: seg.value === modelData.value ? Font.DemiBold : Font.Normal
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: seg.picked(modelData.value)
          }
        }
      }
    }
  }

  // One row of a group: label (and optional detail) on the left, a control
  // on the right, and a hairline under every row but the last.
  component SettingsRow: Item {
    id: row
    property string label: ""
    property string detail: ""
    property bool last: false
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: detail !== "" ? 58 : 48
    Column {
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.right: slot.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text {
        width: parent.width
        text: row.label
        elide: Text.ElideRight
        color: settingsView.text
        font.family: "Adwaita Sans"
        font.pixelSize: 14
        font.letterSpacing: -0.2
      }
      Text {
        width: parent.width
        visible: row.detail !== ""
        text: row.detail
        elide: Text.ElideRight
        color: settingsView.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: 11
      }
    }
    Item {
      id: slot
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
    Rectangle {
      visible: !row.last
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: settingsView.divider
    }
  }

  // A titled inset group of rows.
  component SettingsGroup: ColumnLayout {
    id: group
    property string title: ""
    default property alias rows: groupBody.data
    Layout.fillWidth: true
    spacing: 6
    Text {
      Layout.leftMargin: 16
      text: group.title.toUpperCase()
      color: settingsView.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 11
      font.letterSpacing: 0.4
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: groupBody.implicitHeight
      radius: 18
      color: settingsView.card
      ColumnLayout {
        id: groupBody
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
      }
    }
  }

  // ---------- Navigation bar ----------

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: 36
    Layout.bottomMargin: 4
    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 32; height: 32; radius: 16
      color: backMouse.containsMouse ? settingsView.host.withAlpha(settingsView.text, 0.16) : settingsView.well
      Behavior on color { ColorAnimation { duration: settingsView.animDuration } }
      Text {
        anchors.centerIn: parent
        text: "󰅁"
        color: settingsView.text
        font.family: settingsView.host.fontFamily
        font.pixelSize: 18
      }
      MouseArea {
        id: backMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: settingsView.host.view = "controls"
      }
    }
    Text {
      anchors.centerIn: parent
      text: "Settings"
      color: settingsView.text
      font.family: "Adwaita Sans"
      font.pixelSize: 16
      font.weight: Font.DemiBold
      font.letterSpacing: -0.3
    }
  }

  // ---------- Groups ----------

  SettingsGroup {
    title: "Motion"
    SettingsRow {
      label: "Animation Speed"
      SettingsSegments {
        options: [{ label: "Fast", value: 1 }, { label: "Normal", value: 1.5 }, { label: "Relaxed", value: 2 }]
        value: settingsView.settings.motionScale
        onPicked: function(v) { settingsView.settings.motionScale = v }
      }
    }
    SettingsRow {
      label: "Hover Lift"
      detail: "The clock pill lifts slightly under the pointer"
      last: true
      SettingsSwitch {
        checked: settingsView.settings.hoverLift
        onToggled: function(on) { settingsView.settings.hoverLift = on }
      }
    }
  }

  SettingsGroup {
    title: "Pill"
    SettingsRow {
      label: "Notch Style"
      detail: "Attach the island to the top edge, like a MacBook notch"
      SettingsSwitch {
        checked: settingsView.settings.notch
        onToggled: function(on) { settingsView.settings.notch = on }
      }
    }
    SettingsRow {
      label: "24-Hour Clock"
      SettingsSwitch {
        checked: settingsView.settings.clock24h
        onToggled: function(on) { settingsView.settings.clock24h = on }
      }
    }
    SettingsRow {
      label: "Now Playing"
      detail: "Show the cover and sound wave while media plays"
      SettingsSwitch {
        checked: settingsView.settings.mediaPill
        onToggled: function(on) { settingsView.settings.mediaPill = on }
      }
    }
    SettingsRow {
      label: "Volume HUD"
      detail: "Show the level when the volume changes"
      last: true
      SettingsSwitch {
        checked: settingsView.settings.volumeHud
        onToggled: function(on) { settingsView.settings.volumeHud = on }
      }
    }
  }

  SettingsGroup {
    title: "Search"
    SettingsRow {
      label: "Ask With"
      detail: "Answers launcher questions in the island"
      last: true
      SettingsSegments {
        options: [{ label: "Claude", value: "claude" }, { label: "Codex", value: "chatgpt" }, { label: "None", value: "none" }]
        value: settingsView.settings.askAi
        onPicked: function(v) { settingsView.settings.askAi = v }
      }
    }
  }

  SettingsGroup {
    title: "Live Activities"
    SettingsRow {
      label: "Clipboard"
      detail: "Show what you copied for a moment"
      SettingsSwitch {
        checked: settingsView.settings.clipboard
        onToggled: function(on) { settingsView.settings.clipboard = on }
      }
    }
    SettingsRow {
      label: "Downloads"
      detail: "Show browser downloads in progress on the pill"
      SettingsSwitch {
        checked: settingsView.settings.downloads
        onToggled: function(on) { settingsView.settings.downloads = on }
      }
    }
    SettingsRow {
      label: "System Updates"
      detail: "Show pacman, yay, paru, and Omarchy updates on the pill"
      last: true
      SettingsSwitch {
        checked: settingsView.settings.systemUpdates
        onToggled: function(on) { settingsView.settings.systemUpdates = on }
      }
    }
  }

  SettingsGroup {
    title: "Notifications"
    SettingsRow {
      label: "Banner Duration"
      last: true
      SettingsSegments {
        options: [{ label: "3 s", value: 3 }, { label: "5 s", value: 5 }, { label: "8 s", value: 8 }]
        value: settingsView.settings.bannerSeconds
        onPicked: function(v) { settingsView.settings.bannerSeconds = v }
      }
    }
  }
}
