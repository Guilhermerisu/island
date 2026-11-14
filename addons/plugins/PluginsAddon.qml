import QtQuick
import Quickshell.Io
import ".."

// Plugins added with `omarchy plugin add`, as an island view (see PluginList)
// and a control center tile for each (see PluginTile), keyed
// "plugins.<plugin id>": it stays out of the control grid until added from the
// add panel (see Controls.isShown), then sits among the controls like any of
// them.
Addon {
  id: pluginsAddon
  views: [{ name: "plugins", width: 520, component: pluginList }]
  tiles: all.map(function(entry) { return { key: entry.id, title: entry.name, component: pluginTile } })
  Component {
    id: pluginList
    PluginList { addon: pluginsAddon; host: pluginsAddon.host; active: pluginsAddon.host.view === "plugins" }
  }
  Component {
    id: pluginTile
    PluginTile {
      center: parent.center
      addon: pluginsAddon
      // A stand-in for the moment a reloaded list drops it.
      entry: pluginsAddon.entryFor(String(parent.controlKey).slice(pluginsAddon.addon.id.length + 1))
        || ({ id: "", name: "", enabled: false, openable: false })
    }
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
  // What a plugin shows as its icon, as { text, family } (an empty family: the
  // island's icon font): what its bar widget draws, else the puzzle. Kept apart
  // from `all`, so an icon that changes doesn't rebuild the tiles.
  function iconOf(id) {
    return host.barWidgets.iconOf(id) || { text: "󰐱", family: "" }
  }
  function entryFor(id) {
    for (var i = 0; i < all.length; i++) if (all[i].id === id) return all[i]
    return null
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
