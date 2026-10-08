import QtQuick
import Quickshell.Io

// Addons: niche features kept out of the core, each switched on in Settings →
// Addons and kept in its own folder here. An addon's files are only read
// while it's enabled: its root (an Addon) is loaded from its file then, and
// everything it adds to the island is declared inside that root.
Item {
  id: addons
  required property var host
  required property var settings

  // Each addon: id, name, icon (and its color, and optionally iconLayers drawn
  // in its place, see PaneIcon), description, whether it starts enabled, its
  // root file (relative to this folder), and its options
  // ({ key, label, detail, type: "switch" | "popup" | "text", default, choices,
  // placeholder }). Its views' keybindings are tagged with its id in
  // companion/bindings.sh.
  readonly property var entries: [
    { id: "weather", name: "Weather", icon: "󰖐", color: "#1f8ef1", default: false, source: "weather/WeatherAddon.qml",
      iconLayers: [
        { circle: true, color: "#ffd60a", x: 0.65, y: 0.37, size: 0.36 },
        { glyph: "󰅟", color: "#ffffff", opacity: 0.9, x: 0.45, y: 0.57, size: 0.74 }
      ],
      description: "Current conditions for your city",
      options: [
        { key: "city", label: "City", detail: "Looked up on Open-Meteo", type: "text", default: "", placeholder: "e.g. Lisbon" },
        { key: "fahrenheit", label: "Fahrenheit", detail: "Show °F instead of °C", type: "switch", default: false }
      ] },
    { id: "calendar", name: "Calendar", icon: "󰃭", color: "#f7f7f7", default: false, source: "calendar/CalendarAddon.qml",
      iconLayers: [
        { rect: true, color: "#f2564f", x: 0.5, y: 0.13, width: 1, height: 0.36 },
        { date: "month", color: "#ffffff", weight: Font.Bold, x: 0.5, y: 0.17, size: 0.2 },
        { date: "day", color: "#2c2c2e", weight: Font.Light, x: 0.5, y: 0.63, size: 0.56 }
      ],
      description: "Your month and the day's events",
      options: [
        { key: "urls", label: "Calendars", detail: "ICS links, separated by spaces", type: "text", default: "", placeholder: "https://…/basic.ics" }
      ] },
    { id: "timer", name: "Timer", icon: "󰔛", color: "#1c1c1e", default: false, source: "timer/TimerAddon.qml",
      iconLayers: [
        { rect: true, color: "#ff9f0a", x: 0.5, y: 0.13, width: 0.2, height: 0.08, radius: 0.5 },
        { circle: true, color: "#ff9f0a", x: 0.5, y: 0.56, size: 0.68 },
        { circle: true, color: "#1c1c1e", x: 0.5, y: 0.56, size: 0.52 },
        { rect: true, color: "#ffffff", x: 0.5, y: 0.47, width: 0.07, height: 0.2, radius: 0.5 },
        { circle: true, color: "#ffffff", x: 0.5, y: 0.56, size: 0.1 }
      ],
      description: "A countdown on the island" },
    { id: "stats", name: "System Stats", icon: "󰓅", color: "#232325", default: true, source: "stats/StatsAddon.qml",
      // Activity Monitor's: a red and a blue wave either side of a line,
      // over a faint grid.
      iconLayers: [1, 2, 3, 4, 5, 6, 7].reduce(function(grid, n) {
        return grid.concat([
          { rect: true, color: "#ffffff", opacity: 0.07, x: 0.5, y: n / 8, width: 1, height: 0.01 },
          { rect: true, color: "#ffffff", opacity: 0.07, x: n / 8, y: 0.5, width: 0.01, height: 1 }
        ])
      }, []).concat([
        { line: wave(-1, [0.22, 0.34, 0.49, 0.63, 0.76], [0.07, 0.15, 0.25, 0.12, 0.15]), color: "#ff6b5e", fill: true },
        { line: wave(1, [0.3, 0.42, 0.55, 0.67, 0.77], [0.08, 0.17, 0.27, 0.15, 0.08]), color: "#3d8bff", fill: true },
        { rect: true, color: "#ff6b5e", x: 0.5, y: 0.492, width: 1, height: 0.03 },
        { rect: true, color: "#3d8bff", x: 0.5, y: 0.518, width: 1, height: 0.025 }
      ]),
      description: "Live CPU, memory, GPU, and disk use" },
    { id: "tray", name: "System Tray", icon: "󰀻", color: "#5e5ce6", default: false, source: "tray/TrayAddon.qml",
      iconLayers: [
        { rect: true, color: "#ffffff", opacity: 0.95, x: 0.5, y: 0.26, width: 0.8, height: 0.14, radius: 0.5 },
        { circle: true, color: "#34c759", x: 0.56, y: 0.26, size: 0.07 },
        { circle: true, color: "#ff9f0a", x: 0.68, y: 0.26, size: 0.07 },
        { circle: true, color: "#5e5ce6", x: 0.8, y: 0.26, size: 0.07 },
        { rect: true, color: "#ffffff", opacity: 0.95, x: 0.66, y: 0.61, width: 0.52, height: 0.46, radius: 0.16 },
        { rect: true, color: "#c7c7cc", x: 0.66, y: 0.47, width: 0.34, height: 0.05, radius: 0.5 },
        { rect: true, color: "#5e5ce6", x: 0.66, y: 0.61, width: 0.44, height: 0.12, radius: 0.3 },
        { rect: true, color: "#ffffff", x: 0.66, y: 0.61, width: 0.34, height: 0.05, radius: 0.5 },
        { rect: true, color: "#c7c7cc", x: 0.66, y: 0.75, width: 0.34, height: 0.05, radius: 0.5 }
      ],
      description: "Apps tray icons and menus" },
    { id: "plugins", name: "Plugins", icon: "󰐱", color: "#ff9f0a", default: false, source: "plugins/PluginsAddon.qml",
      iconLayers: [
        { rect: true, color: "#ffffff", x: 0.33, y: 0.33, width: 0.3, height: 0.3, radius: 0.28 },
        { rect: true, color: "#ffffff", x: 0.67, y: 0.33, width: 0.3, height: 0.3, radius: 0.28 },
        { rect: true, color: "#ffffff", x: 0.33, y: 0.67, width: 0.3, height: 0.3, radius: 0.28 },
        { rect: true, color: "#ffffff", opacity: 0.4, x: 0.67, y: 0.67, width: 0.3, height: 0.3, radius: 0.28 },
        { glyph: "󰐕", color: "#ffffff", x: 0.67, y: 0.67, size: 0.28 }
      ],
      description: "Open and switch Omarchy plugins" },
    { id: "keyboard", name: "Keyboard Layout", icon: "󰌌", color: "#30b0c7", default: false, source: "keyboard/KeyboardAddon.qml",
      iconLayers: [{ rect: true, color: "#ffffff", x: 0.5, y: 0.55, width: 0.8, height: 0.5, radius: 0.16 }]
        .concat([0.41, 0.55].reduce(function(keys, y) {
          return keys.concat([0.23, 0.365, 0.5, 0.635, 0.77].map(function(x) {
            return { rect: true, color: "#a9bcc2", x: x, y: y, width: 0.1, height: 0.09, radius: 0.25 }
          }))
        }, []))
        .concat([{ rect: true, color: "#a9bcc2", x: 0.5, y: 0.69, width: 0.5, height: 0.09, radius: 0.4 }]),
      description: "Show the layout on the pill when it changes" },
    { id: "ask", name: "Ask AI", icon: "󰚩", color: "#000000", default: true, source: "ask/AskAddon.qml",
      // Siri's: a glass sphere on black, with a ribbon of light across it,
      // white in the middle and tinted orange and blue at its edges.
      iconLayers: [
        { circle: true, color: "#e5e5ea", opacity: 0.9, x: 0.5, y: 0.5, size: 0.78 },
        { circle: true, color: "#7c7c82", x: 0.5, y: 0.5, size: 0.75 },
        { circle: true, color: "#2c2c2e", opacity: 0.75, x: 0.5, y: 0.47, size: 0.62 },
        { circle: true, color: "#ffffff", opacity: 0.12, x: 0.42, y: 0.32, size: 0.3 },
        siriWave(0.2, 0.8, 0.012, "#ff9f0a", 0.45, 0.035),
        siriWave(0.2, 0.8, -0.012, "#64d2ff", 0.45, 0.035),
        siriWave(0.16, 0.84, 0, "#ffffff", 0.3, 0.09),
        siriWave(0.24, 0.76, 0, "#ffffff", 0.55, 0.045),
        siriWave(0.34, 0.66, 0, "#ffffff", 0.95, 0.03)
      ],
      description: "Answers launcher questions in the island",
      options: [
        { key: "with", label: "Ask With", detail: "Uses the command-line tool you're signed in to", type: "popup", default: "codex",
          choices: [{ label: "Claude", value: "claude" }, { label: "Codex", value: "codex" }] }
      ] }
  ]

  // A smooth wave off the icon's middle line, rising (sign -1) or falling,
  // with a bump of each height at each x; for the System Stats icon.
  function wave(sign, centers, heights) {
    var points = [[0, 0.5]]
    for (var x = 0; x <= 1.0001; x += 0.0125) {
      var y = 0
      for (var i = 0; i < centers.length; i++) y += heights[i] * Math.exp(-Math.pow((x - centers[i]) / 0.042, 2))
      points.push([x, 0.5 + sign * Math.min(0.34, y)])
    }
    points.push([1, 0.5])
    return points
  }
  // Part of Siri's ribbon of light, from x `from` to `to`, shifted down by
  // `dy`: an S across the sphere, for the Ask AI icon.
  function siriWave(from, to, dy, color, opacity, width) {
    var points = []
    for (var x = from; x <= to + 0.0001; x += 0.01)
      points.push([x, 0.54 + dy - 0.045 * Math.sin((x - 0.2) / 0.6 * 2 * Math.PI)])
    return { line: points, color: color, opacity: opacity, width: width }
  }
  function entry(id) {
    for (var i = 0; i < entries.length; i++) if (entries[i].id === id) return entries[i]
    return null
  }
  function isEnabled(id) {
    var saved = settings.addons || {}
    if (saved[id] !== undefined) return !!saved[id]
    var e = entry(id)
    return !!(e && e.default)
  }
  function setEnabled(id, on) {
    var next = Object.assign({}, settings.addons || {})
    next[id] = !!on
    settings.addons = next
  }
  function option(id, key) {
    var saved = (settings.addonOptions || {})[id] || {}
    if (saved[key] !== undefined) return saved[key]
    var e = entry(id)
    var options = e && e.options || []
    for (var i = 0; i < options.length; i++) if (options[i].key === key) return options[i].default
    return undefined
  }
  function setOption(id, key, value) {
    var next = Object.assign({}, settings.addonOptions || {})
    next[id] = Object.assign({}, next[id] || {})
    next[id][key] = value
    settings.addonOptions = next
  }

  // Ask AI was core, set by `askAi` ("claude", "chatgpt" for Codex, or
  // "none" for off): carried over once to its addon, then cleared. Late,
  // so the addon settings it fills in are loaded first.
  Connections {
    target: addons.settings
    function onAskAiChanged() { Qt.callLater(addons.migrateAsk) }
  }
  function migrateAsk() {
    var old = settings.askAi
    if (!old) return
    if ((settings.addons || {}).ask === undefined) setEnabled("ask", old !== "none")
    if (old === "claude" && ((settings.addonOptions || {}).ask || {}).with === undefined) setOption("ask", "with", "claude")
    settings.askAi = ""
  }

  // A disabled addon's keybindings are switched off in island-bindings.lua,
  // their keys kept (see companion/bindings.sh). Synced on start and on
  // each change; the script does nothing when the list is unchanged.
  readonly property string enabledIds: entries.filter(function(e) { return addons.isEnabled(e.id) })
    .map(function(e) { return e.id }).join(",")
  onEnabledIdsChanged: syncBindings()
  Component.onCompleted: { syncBindings(); Qt.callLater(migrateAsk) }
  property bool bindingsStale: false
  Process {
    id: bindingSync
    onExited: if (addons.bindingsStale) addons.syncBindings()
  }
  function syncBindings() {
    if (bindingSync.running) { bindingsStale = true; return }
    bindingsStale = false
    bindingSync.command = ["bash", host.setup.companionDir + "/bindings.sh", "addons", enabledIds]
    bindingSync.running = true
  }

  // The enabled addons' roots, in registry order.
  property var loaded: []
  function collect() {
    var roots = []
    for (var i = 0; i < slots.count; i++) {
      var slot = slots.itemAt(i)
      if (slot && slot.item) roots.push(slot.item)
    }
    loaded = roots
  }
  Repeater {
    id: slots
    model: addons.entries
    delegate: Loader {
      id: slot
      required property var modelData
      readonly property bool wanted: addons.isEnabled(modelData.id)
      onWantedChanged: load()
      Component.onCompleted: load()
      function load() {
        if (!wanted) { source = ""; return }
        var e = modelData
        slot.setSource(Qt.resolvedUrl(e.source), {
          host: addons.host,
          addon: {
            id: e.id, name: e.name,
            option: function(key) { return addons.option(e.id, key) },
            setOption: function(key, value) { addons.setOption(e.id, key, value) }
          }
        })
      }
      onItemChanged: addons.collect()
    }
  }

  // An enabled addon's root by id, or null.
  function root(id) {
    for (var i = 0; i < loaded.length; i++) if (loaded[i].addon.id === id) return loaded[i]
    return null
  }

  // The enabled addons' launcher rows for the typed text (see Addon.qml),
  // and what they add to its placeholder.
  function launcherRows(text) {
    var rows = []
    for (var i = 0; i < loaded.length; i++) {
      var row = loaded[i].launcherRow(text)
      if (row) rows.push(Object.assign({ addonRow: true }, row))
    }
    return rows
  }
  readonly property var launcherHints: loaded.map(function(own) { return own.launcherHint })
    .filter(function(hint) { return hint !== "" })

  // The live activity on the island now, if an addon's: the feedback kind
  // "addon:<id>" names it.
  function pillFor(kind) {
    if (String(kind).indexOf("addon:") !== 0) return null
    var id = String(kind).slice(6)
    for (var i = 0; i < loaded.length; i++)
      if (loaded[i].addon.id === id && loaded[i].pill) return loaded[i]
    return null
  }

  // The addon whose ongoing activity holds the resting island, if any: the
  // first in registry order with `ongoing` set.
  readonly property var ongoing: {
    for (var i = 0; i < loaded.length; i++)
      if (loaded[i].ongoing && loaded[i].pill) return loaded[i]
    return null
  }

  // Every enabled addon's views, and its control center tiles keyed
  // "<addon id>.<tile key>".
  readonly property var views: {
    var result = []
    for (var i = 0; i < loaded.length; i++) result = result.concat(loaded[i].views || [])
    return result
  }
  readonly property var tiles: {
    var result = []
    for (var i = 0; i < loaded.length; i++) {
      var own = loaded[i].tiles || []
      for (var j = 0; j < own.length; j++)
        result.push(Object.assign({}, own[j], { key: loaded[i].addon.id + "." + own[j].key }))
    }
    return result
  }
  // Every enabled addon's Settings panes, in registry order.
  readonly property var settingsPages: {
    var result = []
    for (var i = 0; i < loaded.length; i++) {
      // Drawn with its addon's icon unless it has its own.
      var own = entry(loaded[i].addon.id)
      result = result.concat((loaded[i].settingsPages || []).map(function(page) {
        return Object.assign({ icon: own.icon, color: own.color, iconLayers: own.iconLayers }, page)
      }))
    }
    return result
  }
  function settingsPage(title) {
    for (var i = 0; i < settingsPages.length; i++) if (settingsPages[i].title === title) return settingsPages[i]
    return null
  }
  function tileFor(key) {
    for (var i = 0; i < tiles.length; i++) if (tiles[i].key === key) return tiles[i]
    return null
  }
}
