import QtQuick

// Addons: niche features kept out of the core, each switched on in Settings →
// Addons and kept in its own folder here. An addon's files are only read
// while it's enabled: its root (an Addon) is loaded from its file then, and
// everything it adds to the island is declared inside that root.
Item {
  id: addons
  required property var host
  required property var settings

  // Each addon: id, name, icon, description, whether it starts enabled, its
  // root file (relative to this folder), the bindings.sh ids it owns, and its
  // options ({ key, label, detail, type: "switch" | "popup", default, choices }).
  readonly property var entries: []

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

  // The live activity on the island now, if an addon's: the feedback kind
  // "addon:<id>" names it.
  function pillFor(kind) {
    if (String(kind).indexOf("addon:") !== 0) return null
    var id = String(kind).slice(6)
    for (var i = 0; i < loaded.length; i++)
      if (loaded[i].addon.id === id && loaded[i].pill) return loaded[i]
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
  function tileFor(key) {
    for (var i = 0; i < tiles.length; i++) if (tiles[i].key === key) return tiles[i]
    return null
  }
}
