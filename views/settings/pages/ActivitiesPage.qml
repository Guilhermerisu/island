pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Live Activities: checkable static previews of the real pill.
ColumnLayout {
  id: page
  required property var view
  readonly property string settingsPageName: "Live Activities"
  visible: view.currentPage === settingsPageName
  Layout.fillWidth: true
  spacing: 20

  readonly property var activities: [
    { kind: "media", key: "mediaPill", title: "Now Playing", description: "Current track and album art", keywords: "music media cover sound wave" },
    { kind: "playback", key: "playbackOsd", title: "Play & Pause", description: "When a track plays or pauses", keywords: "music media playback" },
    { kind: "workspace", key: "workspaceHud", title: "Workspace", description: "The workspace you switch to", keywords: "workspaces hud" },
    { kind: "downloads", key: "downloads", title: "Downloads", description: "Download progress", keywords: "" },
    { kind: "recording", key: "screenRecordingActivity", title: "Screen Recording", description: "Time recorded; click to stop", keywords: "record" },
    { kind: "updates", key: "systemUpdates", title: "System Updates", description: "When updates are available", keywords: "packages" },
    { kind: "bluetooth", key: "bluetoothActivity", title: "Bluetooth", description: "When a device connects", keywords: "headphones" },
    { kind: "network", key: "networkActivity", title: "Network", description: "Wi-Fi and Ethernet changes", keywords: "wifi" },
    { kind: "battery", key: "batteryActivity", title: "Battery", description: "Charging and low battery", keywords: "power" },
    { kind: "volume", key: "volumeHud", title: "Volume", description: "The level as you change it", keywords: "sound hud osd" },
    { kind: "brightness", key: "brightnessHud", title: "Brightness", description: "The level as you change it", keywords: "screen hud osd" },
    { kind: "clipboard", key: "clipboard", title: "Clipboard", description: "What you just copied", keywords: "copy paste" }
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
        keywords: modelData.keywords
        checked: page.view.settings[modelData.key]
        onToggled: function(on) { page.view.settings[modelData.key] = on }
      }
    }
  }
}
