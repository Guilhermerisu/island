import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Notifications: how long banners stay, and whether an app's
// notifications stack.
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
      label: "Banner Duration"
      detail: "How long a notification stays on the pill"
      SettingsPopUp {
        view: page.view
        options: [{ label: "3 seconds", value: 3 }, { label: "5 seconds", value: 5 }, { label: "8 seconds", value: 8 }]
        value: page.view.settings.bannerSeconds
        onPicked: function(v) { page.view.settings.bannerSeconds = v }
      }
    }
    SettingsRow {
      view: page.view
      label: "Stack Notifications"
      detail: "Group each app's notifications into one, with a count"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.stackNotifications
        onToggled: function(on) { page.view.settings.stackNotifications = on }
      }
    }
  }
}
