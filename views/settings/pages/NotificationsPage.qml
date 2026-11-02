import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Notifications: how long banners stay.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "Notifications"
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    title: "Banners"
    SettingsRow {
      view: page.view
      label: "Banner Style"
      detail: "A one-line banner as tall as the pill, or the full card"
      SettingsSegmented {
        view: page.view
        options: [{ label: "Compact", value: "compact" }, { label: "Expanded", value: "expanded" }]
        value: page.view.settings.notificationStyle
        onPicked: function(v) { page.view.settings.notificationStyle = v }
      }
    }
    SettingsRow {
      view: page.view
      label: "Silenced apps"
      detail: "No banners from these (names, separated by commas); they still reach the history"
      SettingsTextField {
        view: page.view
        value: page.view.settings.mutedApps
        placeholder: "Slack, Discord"
        onCommitted: function(v) { page.view.settings.mutedApps = v }
      }
    }
    SettingsRow {
      view: page.view
      label: "Banner Duration"
      detail: "How long a notification stays on the pill"
      last: true
      SettingsPopUp {
        view: page.view
        options: [{ label: "3 seconds", value: 3 }, { label: "5 seconds", value: 5 }, { label: "8 seconds", value: 8 }]
        value: page.view.settings.bannerSeconds
        onPicked: function(v) { page.view.settings.bannerSeconds = v }
      }
    }
  }
}
