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
    { kind: "workspace", key: "workspaceHud", title: "Workspace Indicator", description: "Show which workspace is active" },
    { kind: "downloads", key: "downloads", title: "Downloads", description: "Show active download progress" },
    { kind: "updates", key: "systemUpdates", title: "System Updates", description: "Show available system updates" },
    { kind: "bluetooth", key: "bluetoothActivity", title: "Bluetooth Devices", description: "Show Bluetooth connection status" },
    { kind: "battery", key: "batteryActivity", title: "Battery", description: "Charging and low battery alerts" },
    { kind: "volume", key: "volumeHud", title: "Volume", description: "Display the current volume level" },
    { kind: "clipboard", key: "clipboard", title: "Clipboard", description: "Preview recently copied content" }
  ]

  GridLayout {
    Layout.fillWidth: true
    columns: page.width < 420 ? 1 : 2
    columnSpacing: 16
    rowSpacing: 14
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
