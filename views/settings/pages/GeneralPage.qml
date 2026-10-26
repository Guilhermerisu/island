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
        value: page.view.settings.clockFormat
        onPicked: function(v) { page.view.settings.clockFormat = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰁌"
      iconTint: page.system.blue
      label: "Expand on hover"
      detail: "Reveal workspace, battery, weather and media when hovering over the idle pill"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.hoverExpand
        onToggled: function(on) { page.view.settings.hoverExpand = on }
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
    id: glanceGroup
    view: page.view
    title: "Glance on hover"
    visible: page.view.settings.hoverExpand

    function iconFor(kind) {
      switch (kind) {
      case "workspace": return "󱂬"
      case "battery": return "󰁹"
      case "network": return "󰤨"
      case "weather": return "󰖐"
      case "media": return "󰝚"
      case "volume": return "󰕾"
      case "none": return "󰅖"
      default: return "󰜔"
      }
    }

    function tintFor(kind) {
      switch (kind) {
      case "workspace": return page.system.blue
      case "battery": return page.system.green
      case "network": return page.system.cyan
      case "weather": return page.system.yellow
      case "media": return page.system.purple
      case "volume": return page.system.orange
      case "none": return page.system.gray
      default: return page.system.blue
      }
    }

    readonly property var moduleChoices: [
      { label: "󱂬  Workspace", short: "Workspace", value: "workspace" },
      { label: "󰁹  Battery", short: "Battery", value: "battery" },
      { label: "󰤨  Network", short: "Network", value: "network" },
      { label: "󰖐  Weather", short: "Weather", value: "weather" },
      { label: "󰝚  Now Playing", short: "Now Playing", value: "media" },
      { label: "󰕾  Volume", short: "Volume", value: "volume" },
      { label: "󰅖  None", short: "None", value: "none" }
    ]

    SettingsRow {
      view: page.view
      icon: glanceGroup.iconFor(page.view.settings.glanceLeft1 || "workspace")
      iconTint: glanceGroup.tintFor(page.view.settings.glanceLeft1 || "workspace")
      label: "Left slot 1"
      detail: "First item on the left side"
      SettingsPopUp {
        view: page.view
        options: glanceGroup.moduleChoices
        value: page.view.settings.glanceLeft1 || "workspace"
        onPicked: function(v) { page.view.settings.glanceLeft1 = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: glanceGroup.iconFor(page.view.settings.glanceLeft2 || "battery")
      iconTint: glanceGroup.tintFor(page.view.settings.glanceLeft2 || "battery")
      label: "Left slot 2"
      detail: "Second item on the left side"
      SettingsPopUp {
        view: page.view
        options: glanceGroup.moduleChoices
        value: page.view.settings.glanceLeft2 || "battery"
        onPicked: function(v) { page.view.settings.glanceLeft2 = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: glanceGroup.iconFor(page.view.settings.glanceRight1 || "weather")
      iconTint: glanceGroup.tintFor(page.view.settings.glanceRight1 || "weather")
      label: "Right slot 1"
      detail: "First item on the right side"
      SettingsPopUp {
        view: page.view
        options: glanceGroup.moduleChoices
        value: page.view.settings.glanceRight1 || "weather"
        onPicked: function(v) { page.view.settings.glanceRight1 = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: glanceGroup.iconFor(page.view.settings.glanceRight2 || "volume")
      iconTint: glanceGroup.tintFor(page.view.settings.glanceRight2 || "volume")
      label: "Right slot 2"
      detail: "Second item on the right side"
      SettingsPopUp {
        view: page.view
        options: glanceGroup.moduleChoices
        value: page.view.settings.glanceRight2 || "volume"
        onPicked: function(v) { page.view.settings.glanceRight2 = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰝚"
      iconTint: page.system.purple
      label: "Floating music pill"
      detail: "Show a satellite player pill under the island when music is playing"
      last: page.view.settings.glanceMediaSatellite === false
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.glanceMediaSatellite !== false
        onToggled: function(on) { page.view.settings.glanceMediaSatellite = on }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.view.settings.glanceMediaSatellite !== false
      icon: "󰃚"
      iconTint: page.system.purple
      label: "Music pill border"
      detail: "Draw a thin subtle outline around the floating music pill"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.glanceMediaSatelliteBorder !== false
        onToggled: function(on) { page.view.settings.glanceMediaSatelliteBorder = on }
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
