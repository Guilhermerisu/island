import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Notifications: how long banners stay, the sound they make,
// whether an app's notifications stack, whether they show the app's
// buttons, and whether their text is cut short.
ColumnLayout {
  id: page
  required property var view
  readonly property string settingsPageName: "Notifications"
  readonly property var system: view.host.theme.system
  readonly property var settings: view.settings
  visible: view.currentPage === settingsPageName
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    title: "Banners"
    SettingsRow {
      view: page.view
      icon: "󰔛"
      iconTint: page.system.orange
      label: "Banner duration"
      detail: "How long a banner stays on the island"
      keywords: "time seconds dismissed"
      SettingsPopUp {
        view: page.view
        options: [
          { label: "3 seconds", value: 3 }, { label: "5 seconds", value: 5 }, { label: "8 seconds", value: 8 },
          { label: "15 seconds", value: 15 }, { label: "30 seconds", value: 30 }, { label: "Until dismissed", value: 0 }
        ]
        value: page.settings.bannerSeconds
        onPicked: function(v) { page.settings.bannerSeconds = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰕾"
      iconTint: page.system.red
      label: "Sound"
      detail: "Plays when a banner appears"
      keywords: "chime alert audio"
      SettingsPopUp {
        view: page.view
        options: [
          { label: "None", value: "none" },
          { label: "Message", value: "message" },
          { label: "Instant message", value: "message-new-instant" },
          { label: "Bell", value: "bell" },
          { label: "Complete", value: "complete" },
          { label: "Attention", value: "window-attention" }
        ]
        value: page.settings.notificationSound || "none"
        onPicked: function(v) {
          page.settings.notificationSound = v
          page.view.host.playNotificationSound(v)
        }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰈤"
      iconTint: page.system.blue
      label: "Stack notifications"
      detail: "Groups each app's notifications into one, with a count"
      keywords: "group"
      SettingsSwitch {
        view: page.view
        checked: page.settings.stackNotifications
        onToggled: function(on) { page.settings.stackNotifications = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰆿"
      iconTint: page.system.green
      label: "Notification buttons"
      detail: "Shows the actions an app offers, like Reply or Open"
      keywords: "actions"
      SettingsSwitch {
        view: page.view
        checked: page.settings.notificationButtons
        onToggled: function(on) { page.settings.notificationButtons = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰦨"
      iconTint: page.system.gray
      label: "Full notification text"
      detail: "Shows the whole title and message instead of cutting them short"
      keywords: "truncate long"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.settings.notificationFullText
        onToggled: function(on) { page.settings.notificationFullText = on }
      }
    }
  }
}
