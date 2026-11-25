import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → General: the clock, when the island hides or makes room, and
// the Omarchy menu. How it looks is Settings → Appearance.
ColumnLayout {
  id: page
  required property var view
  readonly property string settingsPageName: "General"
  readonly property var system: view.host.theme.system
  readonly property var settings: view.settings
  visible: view.currentPage === settingsPageName
  Layout.fillWidth: true
  spacing: page.view.groupSpacing

  SettingsGroup {
    view: page.view
    title: "Clock"
    SettingsRow {
      view: page.view
      icon: "󰅐"
      iconTint: page.system.orange
      label: "Time format"
      detail: "For the clock on the idle island"
      SettingsSegmented {
        view: page.view
        options: [{ label: "24-hour", value: true }, { label: "12-hour", value: false }]
        value: page.settings.clock24h
        onPicked: function(v) { page.settings.clock24h = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰖙"
      iconTint: page.system.yellow
      label: "Show AM/PM"
      detail: "Adds AM or PM after the time, as in 4:22 PM"
      visible: !page.settings.clock24h
      searchable: !page.settings.clock24h
      SettingsSwitch {
        view: page.view
        checked: page.settings.clockAmPm
        onToggled: function(on) { page.settings.clockAmPm = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰃰"
      iconTint: page.system.cyan
      label: "Clock style"
      detail: "Adds the day or date next to the time, or stacks them"
      keywords: "date day weekday year numeric stacked"
      last: true
      // The button names the style; the menu adds how each one looks now.
      SettingsPopUp {
        readonly property var names: ({
          time: "Time only",
          stackedDay: "Stacked: Time & Day",
          stackedDate: "Stacked: Time & Date",
          stackedFull: "Stacked: Time & Full Date",
          day: "Day and time",
          date: "Date and time",
          short: "Day, date and time",
          weekday: "Full weekday and time",
          full: "Full date & year",
          numeric: "Numeric date"
        })
        view: page.view
        options: page.view.host.clockFormats.map(function(format) {
          var name = names[format] || format
          var preview = page.view.host.isStackedClock(format)
            ? page.view.host.formatClockTime(page.view.host.clockDate) + " / " + page.view.host.formatClockSub(page.view.host.clockDate, format)
            : page.view.host.formatClock(page.view.host.clockDate, format)
          return { label: name + " · " + preview, short: name, value: format }
        })
        value: page.settings.clockFormat
        onPicked: function(v) { page.settings.clockFormat = v }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Windows"
    SettingsRow {
      view: page.view
      icon: "󰍽"
      iconTint: page.system.orange
      label: "Right-click to hide"
      detail: "Right-click the island to hide it, and the top edge of the screen to bring it back"
      SettingsSwitch {
        view: page.view
        checked: page.settings.hideOnRightClick
        onToggled: function(on) { page.settings.hideOnRightClick = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰊓"
      iconTint: page.system.blue
      label: "Hide during fullscreen"
      detail: "Slides away while a fullscreen app or video is showing"
      keywords: "autohide auto-hide"
      SettingsSwitch {
        view: page.view
        checked: page.settings.autoHideFullscreen
        onToggled: function(on) { page.settings.autoHideFullscreen = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󱇙"
      iconTint: page.system.green
      label: "Hide when windows are tiled"
      detail: "Slides away while tiled windows fill the workspace"
      keywords: "autohide auto-hide tiling"
      SettingsSwitch {
        view: page.view
        checked: page.settings.autoHideTiling
        onToggled: function(on) { page.settings.autoHideTiling = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰹑"
      iconTint: page.system.cyan
      label: "Keep windows below the island"
      detail: "Tiled windows leave room for the island instead of going under it"
      keywords: "gap margin overlap"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.settings.reserveSpace
        onToggled: function(on) { page.settings.reserveSpace = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Omarchy menu"
    SettingsRow {
      view: page.view
      icon: "󰀻"
      iconTint: page.system.blue
      label: "Include apps in search"
      detail: "Searching the menu also lists matching apps"
      keywords: "applications launcher"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.settings.menuApps
        onToggled: function(on) { page.settings.menuApps = on }
      }
    }
  }
}
