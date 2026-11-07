import QtQuick
import Quickshell.Io
import ".."

// Plugins added with `omarchy plugin add`, as an island view (see PluginList)
// and as two control center zones: the same list ("list", the view as every
// addon's zone is), and tiles for the plugins the user pinned ("pinned", drawn
// by PluginsZone).
Addon {
  id: pluginsAddon
  views: [{ name: "plugins", width: 520, component: pluginList }]
  zones: ({ pinned: pinnedZone })
  Component {
    id: pluginList
    PluginList { addon: pluginsAddon; host: pluginsAddon.host; active: pluginsAddon.host.view === "plugins" }
  }
  Component {
    id: pinnedZone
    PluginsZone { addon: pluginsAddon; center: parent.center }
  }

  readonly property var openKinds: ["panel", "overlay", "menu"]
  property var listed: []
  property bool loading: false
  // Every plugin but the bar in use and the island's notifications companion
  // (setup manages that one), with whether it opens: a panel, overlay, or menu,
  // or a bar widget Island hosts.
  readonly property var all: listed.map(function(p) {
    return Object.assign({}, p, {
      openable: p.kinds.some(function(k) { return pluginsAddon.openKinds.indexOf(k) !== -1 })
        || pluginsAddon.host.barWidgets.has(p.id)
    })
  })
  function entryFor(id) {
    for (var i = 0; i < all.length; i++) if (all[i].id === id) return all[i]
    return null
  }

  // The plugins pinned to the control center, in order: the settings hold
  // "plugins.<id>" for each. One that's gone stays saved, not shown.
  readonly property string pinPrefix: "plugins."
  readonly property var pinnedIds: String(host.settings.controlCenterPlugins || "").split(",")
    .filter(function(key) { return key.indexOf(pinPrefix) === 0 }).map(function(key) { return key.slice(pinPrefix.length) })
  readonly property var pinned: pinnedIds.map(entryFor).filter(function(entry) { return !!entry })
  readonly property var unpinned: all.filter(function(entry) { return pinnedIds.indexOf(entry.id) === -1 })
  function savePinned(ids) {
    host.settings.controlCenterPlugins = ids.map(function(id) { return pinPrefix + id }).join(",")
  }
  // Pins `id`, or moves it if pinned already: before the pinned plugin
  // `beforeId`, or at the end without it.
  function pin(id, beforeId) {
    var ids = pinnedIds.filter(function(other) { return other !== id })
    var at = beforeId ? ids.indexOf(beforeId) : -1
    ids.splice(at === -1 ? ids.length : at, 0, id)
    savePinned(ids)
  }
  function unpin(id) {
    savePinned(pinnedIds.filter(function(other) { return other !== id }))
  }

  Component.onCompleted: refresh()
  Connections {
    target: pluginsAddon.host
    function onViewChanged() { if (pluginsAddon.host.view === "controls") pluginsAddon.refresh() }
  }

  Process {
    id: listProc
    command: ["omarchy-plugin-list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        pluginsAddon.loading = false
        try {
          pluginsAddon.listed = JSON.parse(text).filter(function(p) {
            return !p.firstParty && (p.kinds || []).indexOf("bar") === -1 && p.id !== "guilhermerisu.notifications"
          }).map(function(p) {
            return {
              key: p.id, id: String(p.id), name: String(p.name || p.id), kinds: p.kinds || [],
              enabled: !!p.enabled, canDisable: p.canDisable !== false
            }
          })
        } catch (e) {}
      }
    }
  }
  function refresh() {
    if (listProc.running) return
    loading = true
    listProc.running = true
    keysProc.running = true
    // Slower, and these rarely change: not each time the control center opens.
    if (host.view !== "controls") boundProc.running = true
  }

  // Each plugin's shortcut, by plugin id (see companion/bindings.sh): set in
  // Settings, else bound elsewhere (the user's own bindings).
  readonly property var keysById: Object.assign({}, boundKeys, savedKeys)
  property var savedKeys: ({})
  property var boundKeys: ({})
  Process {
    id: boundProc
    command: ["bash", pluginsAddon.host.setup.companionDir + "/bindings.sh", "bound"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var keys = {}
        String(text || "").split("\n").forEach(function(line) {
          var cols = line.split("\t")
          var match = String(cols[2] || "").match(/^omarchy-shell shell toggle (\S+)/)
          if (match && !keys[match[1]]) keys[match[1]] = cols[0]
        })
        pluginsAddon.boundKeys = keys
      }
    }
  }
  Process {
    id: keysProc
    command: ["bash", pluginsAddon.host.setup.companionDir + "/bindings.sh", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var keys = {}
        String(text || "").split("\n").forEach(function(line) {
          var cols = line.split("\t")
          if (cols[0].indexOf("plugin:") === 0) keys[cols[0].slice(7)] = cols[2] || ""
        })
        pluginsAddon.savedKeys = keys
      }
    }
  }
  readonly property var keyNames: ({ SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt", ESCAPE: "Esc", RETURN: "Enter" })
  function keyText(keys) {
    if (!keys) return "None"
    return keys.split(" + ").map(function(part) {
      return keyNames[part] || (part.length <= 3 ? part : part.charAt(0) + part.slice(1).toLowerCase())
    }).join(" + ")
  }

  Process {
    id: toggleProc
    onExited: pluginsAddon.refresh()
  }
  function setEnabled(entry, enabled) {
    if (!entry || toggleProc.running || (!enabled && !entry.canDisable)) return
    toggleProc.command = [enabled ? "omarchy-plugin-enable" : "omarchy-plugin-disable", entry.id]
    toggleProc.running = true
  }

  // Close first so the plugin's window, not the island, gets the keyboard.
  Process { id: runner }
  function open(entry) {
    host.view = "rest"
    runner.command = ["bash", "-c", 'sleep 0.15; exec omarchy-shell shell toggle "$1" "{}"', "--", entry.id]
    runner.startDetached()
  }
}
