import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → General: the pill, when it hides, appearance and motion.
ColumnLayout {
  id: page
  required property var view
  readonly property var system: view.host.theme.system
  visible: view.currentPage === "General"
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    title: "Pill"
    SettingsRow {
      view: page.view
      icon: "󰅐"
      iconTint: page.system.orange
      label: "Time format"
      detail: "Shown when the island is idle"
      SettingsSegmented {
        view: page.view
        options: [{ label: "24-hour", value: true }, { label: "12-hour", value: false }]
        value: page.view.settings.clock24h
        onPicked: function(v) { page.view.settings.clock24h = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰖙"
      iconTint: page.system.yellow
      label: "Show AM/PM"
      detail: "After the time, as in 4:22 PM"
      visible: !page.view.settings.clock24h
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.clockAmPm
        onToggled: function(on) { page.view.settings.clockAmPm = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰃰"
      iconTint: "#30b0c7"
      label: "Clock style"
      detail: "The time alone, or with the day or date"
      // The button names the style; the menu adds how each one looks now.
      SettingsPopUp {
        readonly property var names: ({ time: "Time only", day: "Day", date: "Date", short: "Day and date", weekday: "Full weekday" })
        view: page.view
        options: page.view.host.clockFormats.map(function(format) {
          var name = names[format] || format
          return { label: name + " · " + page.view.host.formatClock(page.view.host.clockDate, format), short: name, value: format }
        })
        value: page.view.settings.clockFormat
        onPicked: function(v) { page.view.settings.clockFormat = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰌢"
      iconTint: page.system.indigo
      label: "Notch style"
      detail: "Attach the island to the top edge, like a MacBook notch"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.notch
        onToggled: function(on) { page.view.settings.notch = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Hide automatically"
    SettingsRow {
      view: page.view
      icon: "󰊓"
      iconTint: page.system.blue
      label: "When a window is fullscreen"
      detail: "Slides the island away during fullscreen apps and video"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.autoHideFullscreen
        onToggled: function(on) { page.view.settings.autoHideFullscreen = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󱇙"
      iconTint: page.system.green
      label: "When windows are tiled"
      detail: "Hides the island while tiled windows fill the workspace"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.autoHideTiling
        onToggled: function(on) { page.view.settings.autoHideTiling = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Appearance"
    SettingsRow {
      view: page.view
      icon: "󰸌"
      iconTint: "#ff375f"
      label: "Colorful live activities"
      detail: "Use each activity's own accent color"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.colorfulLiveActivities
        onToggled: function(on) { page.view.settings.colorfulLiveActivities = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󱂫"
      iconTint: "#2f6fed"
      label: "Colorful sidebar icons"
      detail: "macOS-style colored icons throughout settings"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.colorfulSettingsIcons
        onToggled: function(on) { page.view.settings.colorfulSettingsIcons = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Typography"
    SettingsRow {
      view: page.view
      icon: "󰛖"
      iconTint: page.system.purple
      label: "Font"
      detail: "Island default, Omarchy's menu font, or your own"
      SettingsPopUp {
        view: page.view
        options: [
          { label: "Island default", value: "island" },
          { label: "Omarchy default", value: "omarchy" },
          { label: "Custom", value: "custom" }
        ]
        value: page.view.settings.textFontMode
        onPicked: function(v) { page.view.settings.textFontMode = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰬈"
      iconTint: page.system.purple
      label: "Custom font"
      detail: "Search the installed fonts"
      visible: page.view.settings.textFontMode === "custom"
      SettingsFontPicker {
        view: page.view
        value: page.view.settings.customFont
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰊄"
      iconTint: page.system.gray
      label: "Text size"
      detail: "Scales text inside the pill and expanded views"
      last: true
      SettingsSegmented {
        view: page.view
        options: [{ label: "S", value: 0.9 }, { label: "M", value: 1 }, { label: "L", value: 1.15 }, { label: "XL", value: 1.3 }]
        value: page.view.settings.textScale
        onPicked: function(v) { page.view.settings.textScale = v }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Motion"
    SettingsRow {
      view: page.view
      icon: "󰓅"
      iconTint: page.system.green
      label: "Animation speed"
      detail: "How quickly the island morphs and settles"
      last: true
      SettingsSegmented {
        view: page.view
        options: [{ label: "Fast", value: 1 }, { label: "Normal", value: 1.5 }, { label: "Relaxed", value: 2 }]
        value: page.view.settings.motionScale
        onPicked: function(v) { page.view.settings.motionScale = v }
      }
    }
  }
}
