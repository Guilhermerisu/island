import QtQuick
import QtQuick.Layouts
import "../controls"
import "../../../components"

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
      icon: "󰌢"
      iconTint: page.system.indigo
      label: "Notch style"
      detail: "Attach the island to the top edge, like a MacBook notch"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.notch
        onToggled: function(on) { page.view.settings.notch = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰩨"
      iconTint: page.system.orange
      label: "Pill size"
      detail: "Scales the island; open views shrink about half as much"
      SettingsSlider {
        view: page.view
        from: 0.6
        to: 1
        value: page.view.settings.pillScale
        onMoved: function(v) { page.view.settings.pillScale = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰁝"
      iconTint: page.system.cyan
      label: "Top margin"
      detail: "Gap between the screen edge and the island (not in notch style)"
      SettingsSlider {
        view: page.view
        from: 0
        to: 32
        step: 1
        value: page.view.settings.topGap
        onMoved: function(v) { page.view.settings.topGap = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰁅"
      iconTint: page.system.cyan
      label: "Bottom margin"
      detail: "Extra space between the island and windows in top bar mode"
      SettingsSlider {
        view: page.view
        from: 0
        to: 32
        step: 1
        value: page.view.settings.barGap
        onMoved: function(v) { page.view.settings.barGap = v }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰘔"
      iconTint: page.system.green
      label: "Top bar"
      detail: "Keep windows from sliding under the island; the hide-bar toggle is ignored"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.reserveTop
        onToggled: function(on) { page.view.settings.reserveTop = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰁌"
      iconTint: page.system.blue
      label: "Hover style"
      detail: "What happens when hovering over the idle island"
      last: true
      SettingsPopUp {
        view: page.view
        options: [
          { label: "󰁌  Expand island (Glance)", short: "Expand", value: "expand" },
          { label: "󰂚  Flanking capsules", short: "Capsules", value: "capsules" },
          { label: "󰂚  Capsules, always shown", short: "Always", value: "always" },
          { label: "󰅖  Disabled", short: "Disabled", value: "none" }
        ]
        value: page.view.settings.hoverStyle || (page.view.settings.hoverCapsules ? "capsules" : page.view.settings.hoverExpand ? "expand" : "none")
        onPicked: function(v) {
          page.view.settings.hoverStyle = v
          page.view.settings.hoverExpand = (v === "expand")
          page.view.settings.hoverCapsules = (v === "capsules" || v === "always")
        }
      }
    }
  }

  SettingsGroup {
    id: glanceGroup
    view: page.view
    title: "Glance on hover"
    visible: (page.view.settings.hoverStyle || (page.view.settings.hoverCapsules ? "capsules" : page.view.settings.hoverExpand ? "expand" : "none")) === "expand"

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
    title: "Capsules on hover"
    visible: ["capsules", "always"].indexOf(page.view.settings.hoverStyle || (page.view.settings.hoverCapsules ? "capsules" : page.view.settings.hoverExpand ? "expand" : "none")) >= 0
    // Where each capsule sits around the island: a line read left to right,
    // the island in the middle, of the capsules switched on below. Drag one
    // along it (across the island too) or use its arrows; Settings lowers
    // under the pill meanwhile, so the capsules show in their new places.
    // Saved as "left nearest-first|right nearest-first".
    SettingsRow {
      id: arrangeRow
      view: page.view
      icon: "󰕰"
      iconTint: page.system.indigo
      label: "Arrangement"
      detail: "Drag the capsules around the island"
      readonly property var names: ({ event: "Event", tray: "Tray", workspaces: "Workspaces", media: "Media", weather: "Weather", notifications: "Notifications", system: "System" })
      readonly property var on: ({
        event: !!page.view.settings.capsuleEvent, tray: page.view.settings.capsuleTray !== false,
        workspaces: !!page.view.settings.capsuleWorkspaces, media: !!page.view.settings.capsuleMedia,
        weather: !!page.view.settings.capsuleWeather, notifications: page.view.settings.capsuleNotifications !== false,
        system: page.view.settings.capsuleSystem !== false
      })
      readonly property string defaultOrder: "event,tray,workspaces,media|weather,notifications,system"
      // Every capsule, left to right, with the island.
      readonly property var line: {
        var sides = String(page.view.settings.capsuleOrder || defaultOrder).split("|")
        var left = (sides[0] || "").split(",").filter(function(k) { return k in names })
        var right = (sides[1] || "").split(",").filter(function(k) { return k in names && left.indexOf(k) < 0 })
        var fb = defaultOrder.split("|")
        fb[0].split(",").forEach(function(k) { if (left.indexOf(k) < 0 && right.indexOf(k) < 0) left.push(k) })
        fb[1].split(",").forEach(function(k) { if (left.indexOf(k) < 0 && right.indexOf(k) < 0) right.push(k) })
        return left.slice().reverse().concat(["island"], right)
      }
      // The ones shown: switched on, and the island.
      readonly property var shownLine: line.filter(function(k) { return k === "island" || on[k] })
      function save(full) {
        var at = full.indexOf("island")
        page.view.settings.capsuleOrder = full.slice(0, at).reverse().join(",") + "|" + full.slice(at + 1).join(",")
      }
      // Moves a shown capsule past its shown neighbour; hidden ones keep their place.
      function move(key, by) {
        var shown = shownLine, i = shown.indexOf(key), j = i + by
        if (i < 0 || j < 0 || j >= shown.length) return
        var full = line.slice(), a = full.indexOf(key), b = full.indexOf(shown[j])
        full[a] = shown[j]
        full[b] = key
        save(full)
        page.view.host.preview("capsules", 3000)
      }
    }
    // Kept by name, so a reorder moves the pills (and the Flow slides them
    // over) instead of rebuilding them mid-drag.
    KeyedListModel { id: arrangeModel; values: arrangeRow.shownLine }
    Flow {
      id: arrangeFlow
      Layout.fillWidth: true
      Layout.leftMargin: 14
      Layout.rightMargin: 14
      Layout.bottomMargin: 10
      spacing: 6
      // The others slide into their new places.
      move: Transition { MotionAnimation { theme: page.view.host.theme; property: "x"; pace: "standard" } }
      HoverHandler {
        onHoveredChanged: hovered ? page.view.host.holdPreview("capsules") : page.view.host.preview("capsules", 1500)
      }
      Repeater {
        model: arrangeModel.model
        delegate: Item {
          id: pill
          required property var entry
          required property int index
          readonly property string modelData: String(entry)
          readonly property bool island: modelData === "island"
          readonly property bool dragging: drag.active
          z: dragging ? 10 : 0
          height: 28
          width: pillRow.implicitWidth + 12
          // Where the pointer is along the Flow while dragging.
          property real pointerX: 0
          property real grabX: 0

          // The pill itself: under the pointer while dragged (lifted a
          // little), easing back into its slot on release.
          Rectangle {
            id: face
            width: parent.width
            height: parent.height
            radius: 14
            x: pill.dragging ? pill.pointerX - pill.grabX - pill.x : 0
            Behavior on x { enabled: !pill.dragging; MotionAnimation { theme: page.view.host.theme; pace: "standard" } }
            scale: pill.dragging ? 1.08 : 1
            Behavior on scale { MotionAnimation { theme: page.view.host.theme; pace: "quick" } }
            color: pill.island ? page.view.accent : pill.dragging ? page.view.host.theme.fill("stronger") : page.view.host.theme.fill("raised")
            Behavior on color { MotionColorAnimation { theme: page.view.host.theme } }
            border.width: pill.dragging ? 1 : 0
            border.color: page.view.host.theme.fill("strong")
            Row {
              id: pillRow
              anchors.centerIn: parent
              spacing: 4
              Text {
                visible: !pill.island
                text: "‹"
                color: leftArrow.containsMouse ? "#ffffff" : page.view.textMuted
                font.pixelSize: page.view.host.theme.px(15)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { id: leftArrow; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: arrangeRow.move(pill.modelData, -1) }
              }
              Text {
                text: pill.island ? "Island" : arrangeRow.names[pill.modelData]
                color: pill.island ? page.view.host.theme.accentText : "#ffffff"
                font.family: page.view.host.theme.textFontFamily
                font.pixelSize: page.view.host.theme.px(12)
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                visible: !pill.island
                text: "›"
                color: rightArrow.containsMouse ? "#ffffff" : page.view.textMuted
                font.pixelSize: page.view.host.theme.px(15)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { id: rightArrow; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: arrangeRow.move(pill.modelData, 1) }
              }
            }
          }
          HoverHandler { enabled: !pill.island; cursorShape: pill.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
          DragHandler {
            id: drag
            enabled: !pill.island
            target: null
            yAxis.enabled: false
            onActiveChanged: if (active) {
              pill.grabX = centroid.pressPosition.x
              pill.pointerX = pill.x + pill.grabX
            }
            onCentroidChanged: {
              if (!active) return
              pill.pointerX = pill.mapToItem(arrangeFlow, centroid.position.x, 0).x
              // Past a neighbour's middle: trade places with it.
              var kids = arrangeFlow.children
              for (var i = 0; i < kids.length; i++) {
                var other = kids[i]
                if (other === pill || other.index === undefined) continue
                var center = other.x + other.width / 2
                if (other.index === pill.index + 1 && pill.pointerX > center) { arrangeRow.move(pill.modelData, 1); break }
                if (other.index === pill.index - 1 && pill.pointerX < center) { arrangeRow.move(pill.modelData, -1); break }
              }
            }
          }
        }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰀻"
      iconTint: page.system.purple
      label: "Tray apps"
      detail: "Tray icons and Omarchy updates"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.capsuleTray !== false
        onToggled: function(on) { page.view.settings.capsuleTray = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰂚"
      iconTint: page.system.orange
      label: "Notifications"
      detail: "How many are in the history"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.capsuleNotifications !== false
        onToggled: function(on) { page.view.settings.capsuleNotifications = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰒓"
      iconTint: page.system.gray
      label: "System"
      detail: "Bluetooth, network, volume and battery"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.capsuleSystem !== false
        onToggled: function(on) { page.view.settings.capsuleSystem = on }
      }
    }
    SettingsRow {
      view: page.view
      icon: "󱂬"
      iconTint: page.system.blue
      label: "Workspaces"
      detail: "Tiles to switch between them"
      SettingsSwitch {
        view: page.view
        checked: !!page.view.settings.capsuleWorkspaces
        onToggled: function(on) { page.view.settings.capsuleWorkspaces = on }
      }
    }
    SettingsRow {
      view: page.view
      last: !page.view.host.addons.isEnabled("calendar") && !page.view.host.addons.isEnabled("weather")
      icon: "󰝚"
      iconTint: page.system.cyan
      label: "Now playing"
      detail: "The track, with play and pause"
      SettingsSwitch {
        view: page.view
        checked: !!page.view.settings.capsuleMedia
        onToggled: function(on) { page.view.settings.capsuleMedia = on }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.view.host.addons.isEnabled("calendar")
      last: !page.view.host.addons.isEnabled("weather")
      icon: "󰃭"
      iconTint: page.system.red
      label: "Next event"
      detail: "When one starts within the hour"
      SettingsSwitch {
        view: page.view
        checked: !!page.view.settings.capsuleEvent
        onToggled: function(on) { page.view.settings.capsuleEvent = on }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.view.host.addons.isEnabled("weather")
      last: true
      icon: "󰖐"
      iconTint: page.system.yellow
      label: "Weather"
      detail: "Current conditions and temperature"
      SettingsSwitch {
        view: page.view
        checked: !!page.view.settings.capsuleWeather
        onToggled: function(on) { page.view.settings.capsuleWeather = on }
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
    title: "Omarchy Menu"
    SettingsRow {
      view: page.view
      icon: "󰀻"
      iconTint: page.system.blue
      label: "Search apps"
      detail: "Lists matching apps when searching the menu"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.menuApps
        onToggled: function(on) { page.view.settings.menuApps = on }
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
