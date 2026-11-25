import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Appearance: the island's shape, what hovering it shows,
// colours, text and motion.
ColumnLayout {
  id: page
  required property var view
  readonly property string settingsPageName: "Appearance"
  readonly property var system: view.host.theme.system
  readonly property var settings: view.settings
  readonly property string hoverStyle: settings.hoverStyle || "none"
  visible: view.currentPage === settingsPageName
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    title: "Island"
    SettingsRow {
      view: page.view
      icon: "󰌢"
      iconTint: page.system.indigo
      label: "Notch style"
      detail: "Joins the island to the top edge of the screen, like a MacBook notch"
      SettingsSwitch {
        view: page.view
        checked: page.settings.notch
        onToggled: function(on) { page.settings.notch = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰄮"
      iconTint: page.system.gray
      label: "Outline"
      detail: "Draws a thin light border around the idle island"
      keywords: "border"
      SettingsSwitch {
        view: page.view
        checked: page.settings.restingOutline
        onToggled: function(on) { page.settings.restingOutline = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰃟"
      iconTint: page.system.gray
      label: "Theme background"
      detail: "Uses your Omarchy theme's background color instead of black"
      keywords: "colour color"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.settings.themeBackground === true
        onToggled: function(on) { page.settings.themeBackground = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Hover"
    SettingsRow {
      view: page.view
      icon: "󰁌"
      iconTint: page.system.blue
      label: "Hover style"
      detail: "What appears when the pointer rests on the idle island"
      keywords: "glance capsules expand"
      last: true
      SettingsPopUp {
        view: page.view
        options: [
          { label: "󰁌  Expand into Glance", short: "Glance", value: "expand" },
          { label: "󰂚  Capsules on both sides", short: "Capsules", value: "capsules" },
          { label: "󰅖  Nothing", short: "Nothing", value: "none" }
        ]
        value: page.hoverStyle
        onPicked: function(v) { page.settings.hoverStyle = v }
      }
    }
  }

  SettingsGroup {
    id: glanceGroup
    view: page.view
    title: "Glance"
    visible: page.hoverStyle === "expand"
    searchable: page.hoverStyle === "expand"

    readonly property var kinds: ({
      workspace: { label: "Workspace", icon: "󱂬", tint: page.system.blue },
      battery: { label: "Battery", icon: "󰁹", tint: page.system.green },
      network: { label: "Network", icon: "󰤨", tint: page.system.cyan },
      weather: { label: "Weather", icon: "󰖐", tint: page.system.yellow },
      media: { label: "Now Playing", icon: "󰝚", tint: page.system.purple },
      volume: { label: "Volume", icon: "󰕾", tint: page.system.orange },
      none: { label: "None", icon: "󰅖", tint: page.system.gray }
    })
    readonly property var order: ["workspace", "battery", "network", "weather", "media", "volume", "none"]
    readonly property var slots: [
      { key: "glanceLeft1", label: "Left slot 1", detail: "The first item on the left", fallback: "workspace" },
      { key: "glanceLeft2", label: "Left slot 2", detail: "The second item on the left", fallback: "battery" },
      { key: "glanceRight1", label: "Right slot 1", detail: "The first item on the right", fallback: "weather" },
      { key: "glanceRight2", label: "Right slot 2", detail: "The second item on the right", fallback: "volume" }
    ]
    function valueOf(slot) { return page.settings[slot.key] || slot.fallback }
    // The slot other than `slot` showing `kind`, if any.
    function slotWith(kind, slot) {
      if (kind === "none") return null
      for (var i = 0; i < slots.length; i++)
        if (slots[i].key !== slot.key && valueOf(slots[i]) === kind) return slots[i]
      return null
    }
    // Each slot shows a different item: one already in another slot trades
    // places with this one.
    function pick(slot, kind) {
      var other = slotWith(kind, slot)
      if (other) page.settings[other.key] = valueOf(slot)
      page.settings[slot.key] = kind
    }

    Repeater {
      model: glanceGroup.slots
      delegate: SettingsRow {
        id: slotRow
        required property var modelData
        readonly property string kind: glanceGroup.valueOf(modelData)
        view: page.view
        icon: (glanceGroup.kinds[kind] || glanceGroup.kinds.none).icon
        iconTint: (glanceGroup.kinds[kind] || glanceGroup.kinds.none).tint
        label: modelData.label
        detail: modelData.detail
        keywords: "glance"
        SettingsPopUp {
          view: page.view
          options: glanceGroup.order.map(function(kind) {
            var item = glanceGroup.kinds[kind]
            var other = glanceGroup.slotWith(kind, slotRow.modelData)
            return { label: item.icon + "  " + item.label + (other ? "  · swaps with " + other.label : ""), short: item.label, value: kind }
          })
          value: slotRow.kind
          onPicked: function(v) { glanceGroup.pick(slotRow.modelData, v) }
        }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰝚"
      iconTint: page.system.purple
      label: "Music pill"
      detail: "Shows a small player under the island while music plays"
      keywords: "glance media satellite"
      last: page.settings.glanceMediaSatellite === false
      SettingsSwitch {
        view: page.view
        checked: page.settings.glanceMediaSatellite !== false
        onToggled: function(on) { page.settings.glanceMediaSatellite = on }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.settings.glanceMediaSatellite !== false
      searchable: page.settings.glanceMediaSatellite !== false
      icon: "󰃚"
      iconTint: page.system.purple
      label: "Music pill outline"
      detail: "Draws a thin border around the music pill"
      keywords: "glance media satellite outline"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.settings.glanceMediaSatelliteBorder !== false
        onToggled: function(on) { page.settings.glanceMediaSatelliteBorder = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Capsules"
    visible: page.hoverStyle === "capsules"
    searchable: page.hoverStyle === "capsules"
    SettingsRow {
      view: page.view
      icon: "󰀻"
      iconTint: page.system.purple
      label: "Tray"
      detail: "Tray icons and Omarchy updates"
      SettingsSwitch {
        view: page.view
        checked: page.settings.capsuleTray !== false
        onToggled: function(on) { page.settings.capsuleTray = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰂚"
      iconTint: page.system.orange
      label: "Notifications"
      detail: "How many notifications are in the history"
      SettingsSwitch {
        view: page.view
        checked: page.settings.capsuleNotifications !== false
        onToggled: function(on) { page.settings.capsuleNotifications = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰒓"
      iconTint: page.system.gray
      label: "System"
      detail: "Bluetooth, network, volume, and battery"
      SettingsSwitch {
        view: page.view
        checked: page.settings.capsuleSystem !== false
        onToggled: function(on) { page.settings.capsuleSystem = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󱂬"
      iconTint: page.system.blue
      label: "Workspaces"
      detail: "Buttons to switch workspaces"
      SettingsSwitch {
        view: page.view
        checked: !!page.settings.capsuleWorkspaces
        onToggled: function(on) { page.settings.capsuleWorkspaces = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰝚"
      iconTint: page.system.cyan
      label: "Now Playing"
      detail: "The current track, with play and pause"
      SettingsSwitch {
        view: page.view
        checked: !!page.settings.capsuleMedia
        onToggled: function(on) { page.settings.capsuleMedia = on }
      }
    }
    // It needs the Plugins addon for the list, so turning it on turns that on.
    SettingsRow {
      view: page.view
      last: !page.view.host.addons.isEnabled("calendar") && !page.view.host.addons.isEnabled("weather")
      icon: "󰐱"
      iconTint: page.system.orange
      label: "Plugins"
      detail: "Buttons to open your plugins; adds the Plugins addon"
      SettingsSwitch {
        view: page.view
        checked: !!page.settings.capsulePlugins && page.view.host.addons.isEnabled("plugins")
        onToggled: function(on) {
          page.settings.capsulePlugins = on
          if (on) page.view.host.addons.setEnabled("plugins", true)
        }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.view.host.addons.isEnabled("calendar")
      searchable: page.view.host.addons.isEnabled("calendar")
      last: !page.view.host.addons.isEnabled("weather")
      icon: "󰃭"
      iconTint: page.system.red
      label: "Next event"
      detail: "Your next calendar event, when it starts within the hour"
      SettingsSwitch {
        view: page.view
        checked: !!page.settings.capsuleEvent
        onToggled: function(on) { page.settings.capsuleEvent = on }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.view.host.addons.isEnabled("weather")
      searchable: page.view.host.addons.isEnabled("weather")
      last: true
      icon: "󰖐"
      iconTint: page.system.yellow
      label: "Weather"
      detail: "Current conditions and temperature"
      SettingsSwitch {
        view: page.view
        checked: !!page.settings.capsuleWeather
        onToggled: function(on) { page.settings.capsuleWeather = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Colors"
    SettingsRow {
      view: page.view
      icon: "󰸌"
      iconTint: page.system.red
      label: "Colorful live activities"
      detail: "Gives each activity its own color instead of the theme accent"
      keywords: "colour"
      SettingsSwitch {
        view: page.view
        checked: page.settings.colorfulLiveActivities
        onToggled: function(on) { page.settings.colorfulLiveActivities = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󱂫"
      iconTint: page.system.blue
      label: "Colorful settings icons"
      detail: "Shows Settings icons in color instead of gray"
      keywords: "colour sidebar"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.settings.colorfulSettingsIcons
        onToggled: function(on) { page.settings.colorfulSettingsIcons = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Text"
    SettingsRow {
      view: page.view
      icon: "󰛖"
      iconTint: page.system.purple
      label: "Font"
      detail: "The font for all island text"
      keywords: "typeface"
      SettingsPopUp {
        view: page.view
        options: [
          { label: "Island default", value: "island" },
          { label: "Omarchy menu font", value: "omarchy" },
          { label: "Custom", value: "custom" }
        ]
        value: page.settings.textFontMode
        onPicked: function(v) { page.settings.textFontMode = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰬈"
      iconTint: page.system.purple
      label: "Custom font"
      detail: "Any font installed on this computer"
      keywords: "typeface"
      visible: page.settings.textFontMode === "custom"
      searchable: page.settings.textFontMode === "custom"
      SettingsFontPicker {
        view: page.view
        value: page.settings.customFont
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰊄"
      iconTint: page.system.gray
      label: "Text size"
      detail: "Scales all text on the island"
      keywords: "font scale bigger smaller"
      last: true
      SettingsSegmented {
        view: page.view
        options: [{ label: "S", value: 0.9 }, { label: "M", value: 1 }, { label: "L", value: 1.15 }, { label: "XL", value: 1.3 }]
        value: page.settings.textScale
        onPicked: function(v) { page.settings.textScale = v }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Animation"
    SettingsRow {
      view: page.view
      icon: "󰓅"
      iconTint: page.system.green
      label: "Animation speed"
      detail: "How fast the island changes shape"
      keywords: "animations"
      last: true
      SettingsSegmented {
        view: page.view
        options: [{ label: "Fast", value: 1 }, { label: "Normal", value: 1.5 }, { label: "Relaxed", value: 2 }]
        value: page.settings.motionScale
        onPicked: function(v) { page.settings.motionScale = v }
      }
    }
  }
}
