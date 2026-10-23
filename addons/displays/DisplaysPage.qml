pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../views/settings/controls"

// The Displays pane, as macOS's: the monitors at the top, arranged as
// they are (drag one to move it, click to pick it), then the picked
// monitor's scale cards, brightness (when it has one), resolution,
// refresh rate, rotation, and colour (HDR, profile, 10-bit), and the text
// size everywhere. Edits stay pending until Apply (see DisplaysAddon),
// except brightness and text size, set at once.
ColumnLayout {
  id: page
  required property var view
  required property var displays
  property bool shown: false
  spacing: 20

  readonly property var entry: displays.selectedEntry
  readonly property bool on: !!entry && !entry.disabled
  readonly property bool busy: displays.confirming

  readonly property var rotations: ["Standard", "90°", "180°", "270°"]
  readonly property bool hdr: displays.isHdr(entry)
  // Hyprland's colour management presets, by macOS's names where it has one.
  readonly property var profiles: [
    { label: "Automatic", value: "auto" },
    { label: "sRGB", value: "srgb" },
    { label: "Display P3", value: "dp3" },
    { label: "DCI-P3", value: "dcip3" },
    { label: "Adobe RGB", value: "adobe" },
    { label: "Wide Gamut (BT.2020)", value: "wide" },
    { label: "From Display (EDID)", value: "edid" }
  ]
  // "60 Hertz", as macOS writes it: whole while it's within 0.1 of one and
  // no other rate on offer rounds to it too ("59.94 Hertz" beside "60 Hertz").
  function hz(rate, rates) {
    var n = Number(rate), r = Math.round(n)
    var clash = rates.some(function(o) { return Number(o) !== n && Math.round(Number(o)) === r })
    return (Math.abs(n - r) < 0.1 && !clash ? r : n) + " Hertz"
  }
  readonly property var rates: entry ? displays.ratesOf(entry.modes, entry.width, entry.height) : []

  Text {
    visible: page.displays.loaded && page.displays.draft.length === 0
    Layout.fillWidth: true
    Layout.leftMargin: 14
    text: "No displays found."
    color: page.view.textMuted
    font.family: page.view.host.theme.textFontFamily
    font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
    font.pixelSize: page.view.detailFontSize
  }

  // ---------- The monitors, arranged in place ----------
  DisplayHero {
    visible: page.displays.draft.length > 0
    Layout.fillWidth: true
    view: page.view
    displays: page.displays
  }
  // ---------- Whether the picked monitor is on ----------
  SettingsGroup {
    view: page.view
    visible: !!page.entry && page.displays.draft.length >= 2
    SettingsRow {
      view: page.view
      label: "Use as"
      last: true
      SettingsPopUp {
        view: page.view
        enabled: !page.busy && !(page.on && page.displays.enabledCount <= 1)
        options: [{ label: "Extended display", value: true }, { label: "Off", value: false }]
        value: page.on
        onPicked: function(value) { page.displays.setEnabled(page.entry.name, value) }
      }
    }
  }

  // ---------- Its scale, resolution, refresh rate, and rotation ----------
  SettingsGroup {
    view: page.view
    visible: page.on
    ScaleCards {
      Layout.fillWidth: true
      view: page.view
      displays: page.displays
      entry: page.entry
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: 14
      Layout.rightMargin: 14
      Layout.preferredHeight: 1
      color: page.view.divider
    }
    SettingsRow {
      view: page.view
      label: "Resolution"
      SettingsPopUp {
        view: page.view
        enabled: !page.busy
        options: page.entry ? page.displays.resolutionsOf(page.entry.modes).map(function(r) {
          // Written as it stands, as the screens above: turned, height first.
          var turned = page.entry.transform % 2 === 1
          return { label: turned ? r.height + " × " + r.width : r.width + " × " + r.height, value: r.width + "x" + r.height }
        }) : []
        value: page.entry ? page.entry.width + "x" + page.entry.height : ""
        onPicked: function(value) {
          var size = String(value).split("x")
          page.displays.setResolution(page.entry.name, Number(size[0]), Number(size[1]))
        }
      }
    }
    SettingsRow {
      view: page.view
      label: "Refresh rate"
      SettingsPopUp {
        view: page.view
        enabled: !page.busy
        options: page.rates.map(function(rate) { return { label: page.hz(rate, page.rates), value: rate } })
        value: page.entry ? page.entry.rate : ""
        onPicked: function(value) { page.displays.setRate(page.entry.name, value) }
      }
    }
    SettingsRow {
      view: page.view
      label: "Rotation"
      last: true
      SettingsPopUp {
        view: page.view
        enabled: !page.busy
        options: page.rotations.map(function(label, i) { return { label: label, value: String(i) } })
        value: page.entry ? String(page.entry.transform % 4) : "0"
        onPicked: function(value) { page.displays.setRotation(page.entry.name, Number(value)) }
      }
    }
  }

  // ---------- Brightness and text size, set at once ----------
  // Text size is for every display, so the group stays for one that's off.
  SettingsGroup {
    view: page.view
    visible: page.displays.draft.length > 0
    // Brightness only when the monitor's on and its brightness can be set.
    SettingsRow {
      view: page.view
      visible: page.on && page.displays.brightness >= 0
      label: "Brightness"
      PaneSlider {
        view: page.view
        value: (page.displays.brightness - 1) / 99
        // sun.min and sun.max, as macOS's.
        leading: "󰃠"
        trailing: "󰃠"
        leadingSize: 10
        trailingSize: 15
        onMoved: function(v) { page.displays.setBrightness(1 + v * 99) }
      }
    }
    SettingsRow {
      view: page.view
      label: "Text size"
      last: true
      PaneSlider {
        view: page.view
        readonly property var stopsList: page.displays.textStops
        stops: stopsList.length
        live: false
        value: Math.max(0, stopsList.indexOf(page.displays.textSize)) / (stopsList.length - 1)
        leading: "A"
        trailing: "A"
        leadingSize: 10
        trailingSize: 16
        onMoved: function(v) { page.displays.setTextSize(stopsList[Math.round(v * (stopsList.length - 1))]) }
      }
    }
  }

  // ---------- Its colour: HDR, the profile, 10-bit ----------
  SettingsGroup {
    view: page.view
    visible: page.on
    title: "Color"
    footer: page.hdr ? "HDR is experimental in Hyprland, and Night Shift is off while it's on. SDR brightness and saturation set how everything that isn't HDR looks."
      : page.entry && page.entry.bitdepth === 10 ? "Some apps can't capture the screen in 10-bit."
      : ""
    SettingsRow {
      view: page.view
      label: "High Dynamic Range"
      detail: "Show HDR video and games in full brightness"
      SettingsSwitch {
        view: page.view
        enabled: !page.busy
        checked: page.hdr
        onToggled: function(checked) { page.displays.setHdr(page.entry.name, checked) }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.hdr
      indent: 12
      label: "SDR brightness"
      SettingsPopUp {
        view: page.view
        enabled: !page.busy
        options: [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2].map(function(v) { return { label: Math.round(v * 100) + "%", value: String(v) } })
        value: page.entry ? String(page.entry.sdrBrightness) : "1"
        onPicked: function(value) { page.displays.setSdrBrightness(page.entry.name, Number(value)) }
      }
    }
    SettingsRow {
      view: page.view
      visible: page.hdr
      indent: 12
      label: "SDR saturation"
      SettingsPopUp {
        view: page.view
        enabled: !page.busy
        options: [0.8, 0.9, 0.95, 1, 1.05, 1.1, 1.2].map(function(v) { return { label: Math.round(v * 100) + "%", value: String(v) } })
        value: page.entry ? String(page.entry.sdrSaturation) : "1"
        onPicked: function(value) { page.displays.setSdrSaturation(page.entry.name, Number(value)) }
      }
    }
    SettingsRow {
      view: page.view
      label: "Color profile"
      SettingsPopUp {
        view: page.view
        enabled: !page.busy
        // Under HDR, only its primaries: BT.2020 or the display's own.
        options: page.hdr ? [{ label: "Wide Gamut (BT.2020)", value: "hdr" }, { label: "From Display (EDID)", value: "hdredid" }]
          : page.profiles
        value: page.entry ? page.entry.cm : "srgb"
        onPicked: function(value) { page.displays.setColorMode(page.entry.name, value) }
      }
    }
    SettingsRow {
      view: page.view
      label: "10-bit color"
      last: true
      SettingsSwitch {
        view: page.view
        // HDR needs it.
        enabled: !page.busy && !page.hdr
        opacity: enabled ? 1 : 0.5
        checked: !!page.entry && page.entry.bitdepth === 10
        onToggled: function(checked) { page.displays.setBitDepth(page.entry.name, checked ? 10 : 8) }
      }
    }
  }

  // ---------- Revert, Apply: only while there's something to apply ----------
  RowLayout {
    Layout.fillWidth: true
    visible: page.displays.dirty
    spacing: 8
    Item { Layout.fillWidth: true }
    SettingsButton {
      view: page.view
      label: "Revert"
      visible: page.displays.dirty
      enabled: !page.busy
      opacity: enabled ? 1 : 0.5
      onClicked: page.displays.discard()
    }
    SettingsButton {
      view: page.view
      label: "Apply"
      primary: true
      visible: page.displays.dirty
      enabled: !page.busy
      opacity: enabled ? 1 : 0.5
      onClicked: page.displays.apply()
    }
  }
}
