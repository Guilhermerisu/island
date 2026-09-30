import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Live Activities: what shows on the pill while it happens.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "Live Activities"
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    title: "Show on the Pill"
    SettingsRow {
      view: page.view
      label: "Now Playing"
      detail: "Show the cover and sound wave while media plays"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.mediaPill
        onToggled: function(on) { page.view.settings.mediaPill = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "Clipboard"
      detail: "Show what you copied for a moment"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.clipboard
        onToggled: function(on) { page.view.settings.clipboard = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "Downloads"
      detail: "Show browser downloads in progress on the pill"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.downloads
        onToggled: function(on) { page.view.settings.downloads = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "System Updates"
      detail: "Show pacman, yay, paru, and Omarchy updates on the pill"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.systemUpdates
        onToggled: function(on) { page.view.settings.systemUpdates = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "Battery"
      detail: "Show when charging starts and when the battery runs low"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.batteryActivity
        onToggled: function(on) { page.view.settings.batteryActivity = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "Bluetooth Devices"
      detail: "Show devices connecting and disconnecting"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.bluetoothActivity
        onToggled: function(on) { page.view.settings.bluetoothActivity = on }
      }
    }
  }
}
