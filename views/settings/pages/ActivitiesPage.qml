pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Live Activities: checkable static previews of the real pill.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "Live Activities"
  Layout.fillWidth: true
  spacing: 20

  readonly property var activities: [
    { kind: "media", key: "mediaPill", title: "Now Playing", description: "Track details and album artwork" },
    { kind: "playback", key: "playbackOsd", title: "Play & Pause", description: "Resume or skip a paused track" },
    { kind: "workspace", key: "workspaceHud", title: "Workspace Indicator", description: "Show which workspace is active" },
    { kind: "downloads", key: "downloads", title: "Downloads", description: "Show active download progress" },
    { kind: "recording", key: "screenRecordingActivity", title: "Screen Recording", description: "Show time recorded; click to stop" },
    { kind: "updates", key: "systemUpdates", title: "System Updates", description: "Show available system updates" },
    { kind: "bluetooth", key: "bluetoothActivity", title: "Bluetooth Devices", description: "Show Bluetooth connection status" },
    { kind: "network", key: "networkActivity", title: "Network", description: "Wi-Fi and Ethernet status" },
    { kind: "battery", key: "batteryActivity", title: "Battery", description: "Charging and low battery alerts" },
    { kind: "volume", key: "volumeHud", title: "Volume", description: "Display the current volume level" },
    { kind: "brightness", key: "brightnessHud", title: "Brightness", description: "Display the brightness level" },
    { kind: "clipboard", key: "clipboard", title: "Clipboard", description: "Preview recently copied content" }
  ]

  readonly property int enabledCount: activities.filter(function(activity) { return !!view.settings[activity.key] }).length

  // As a group's title (see SettingsGroup), with how many are on.
  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 14
    Layout.rightMargin: 14
    Layout.bottomMargin: -12
    Text {
      Layout.fillWidth: true
      text: "Activities"
      color: page.view.textMuted
      font.family: page.view.host.theme.textFontFamily
      font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
      font.pixelSize: page.view.detailFontSize
      font.weight: Font.Medium
    }
    Text {
      text: page.enabledCount + " of " + page.activities.length + " on"
      color: page.view.textMuted
      font.family: page.view.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
      font.pixelSize: page.view.detailFontSize
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: page.width < 420 ? 1 : 2
    columnSpacing: 12
    rowSpacing: 12
    Repeater {
      model: page.activities
      delegate: ActivityCard {
        required property var modelData
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        view: page.view
        kind: modelData.kind
        title: modelData.title
        description: modelData.description
        checked: page.view.settings[modelData.key]
        onToggled: function(on) { page.view.settings[modelData.key] = on }
      }
    }
  }
}
