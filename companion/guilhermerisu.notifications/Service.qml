// The island's notification companion: Omarchy's own notification service,
// loaded as it is from the Omarchy install, with its toasts taken off the
// screen and everything it knows handed to the island.
//
// Nothing of Omarchy's daemon is copied or patched. It keeps owning
// org.freedesktop.Notifications, the stacks, the buttons, Do Not Disturb and
// the history (~/.local/state/omarchy/notifications/); this file only
//   - loads it, from wherever the running Omarchy keeps it,
//   - empties its toast surface (the Variants of PanelWindows),
//   - publishes what it shows to island-feed.json for the island,
//   - answers the island's requests (island-notifications IPC) by calling
//     the daemon's own functions, and ends banners when their time is up,
//     which the daemon leaves to its toast cards.
// What it needs from the daemon is listed in `needs`. If any of it is missing
// (an Omarchy that changed), or the daemon doesn't load, it says so in the
// log and Fallback.qml takes the bus name instead, so banners keep coming.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: service

  // Injected by omarchy-shell (the service loader).
  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string nativeUrl: "file://" + (omarchyPath || "/usr/share/omarchy") + "/shell/plugins/notifications/Service.qml"
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy"
  // The daemon's public members used below; its other internals are not touched.
  readonly property var needs: ["layout", "deedsFor", "runDeed", "activate", "closeToast", "doNotDisturb", "setDoNotDisturb"]

  // Omarchy's daemon, or null while starting or once Fallback.qml took over.
  property var core: null
  property var fallback: null

  // The same surface the stock service has, for what Omarchy asks of it (the
  // bar's Do Not Disturb indicator).
  readonly property bool doNotDisturb: core ? core.doNotDisturb === true : (fallback ? fallback.doNotDisturb : false)
  function setDoNotDisturb(value) {
    if (core) core.setDoNotDisturb(value)
    else if (fallback) fallback.doNotDisturb = !!value
  }

  Component.onCompleted: start()

  function start() {
    var comp = Qt.createComponent(nativeUrl, Component.PreferSynchronous)
    if (comp.status !== Component.Ready) return useFallback("couldn't load " + nativeUrl + ": " + comp.errorString())
    var daemon = comp.createObject(service)
    if (!daemon) return useFallback("couldn't start " + nativeUrl)
    var missing = service.needs.filter(function(name) { return !(name in daemon) })
    if (missing.length) {
      daemon.destroy()
      return useFallback("it no longer has " + missing.join(", "))
    }
    daemon.shell = Qt.binding(function() { return service.shell })
    // Its toasts: the one Variants it makes PanelWindows from. Created at
    // load, so the (empty, transparent) surfaces exist for an instant.
    var toasts = null
    for (var i = 0; i < daemon.data.length; i++)
      if (daemon.data[i].instances !== undefined && daemon.data[i].delegate !== undefined) toasts = daemon.data[i]
    if (toasts) toasts.model = []
    else console.warn("island notifications: couldn't find the toast surface of Omarchy's notification service; its own toasts will show beside the island's")
    core = daemon
    publish()
  }

  function useFallback(why) {
    console.error("island notifications: Omarchy's notification service isn't usable (" + why + "); using the basic fallback, without stacks, actions or history")
    fallback = fallbackComponent.createObject(service)
  }
  Component { id: fallbackComponent; Fallback { } }
  Connections {
    target: service.fallback
    ignoreUnknownSignals: true
    function onRowsChanged() { service.publish() }
  }

  // ------------------------------------------------------------- the feed
  //
  // island-feed.json: { version: 1, active: [row...] }, newest first. A row is
  //   key, originalId, timestamp (ms), app, appIcon, image, glyph, summary,
  //   body (one line), urgency, group (the app's stack), stack (how many are in
  //   it), actions [{ label }] (the buttons, in the order runDeed counts them).
  // The first six are what the previous companion wrote; the rest is new.
  readonly property string feedPath: stateDir + "/island-feed.json"
  property var rows: []
  property string written: ""

  Connections {
    target: service.core
    ignoreUnknownSignals: true
    function onLayoutChanged() { feedDebounce.restart() }
  }
  Timer { id: feedDebounce; interval: 30; onTriggered: service.publish() }

  FileView {
    id: feedFile
    path: service.feedPath
    atomicWrites: true
    printErrors: false
  }

  function nativeRows() {
    var out = []
    var decks = core.layout.decks
    for (var d = 0; d < decks.length; d++)
      for (var r = 0; r < decks[d].rows.length; r++) {
        var row = decks[d].rows[r]
        var key = String(row.key)
        out.push({ key: key, originalId: row.originalId, timestamp: Math.round(row.ts * 1000), app: row.app, appIcon: row.appIcon,
                   image: row.image, glyph: row.glyph, summary: row.summary, body: row.bodyLine, urgency: row.urgency,
                   group: row.groupKey, stack: decks[d].rows.length,
                   actions: core.deedsFor(key).map(function(deed) { return { label: deed.kind === "code" ? "Copy " + deed.value : deed.label } }),
                   duration: row.duration })
      }
    return out
  }

  function publish() {
    var live = core ? nativeRows() : (fallback ? fallback.rows : [])
    live.sort(function(a, b) { return b.timestamp - a.timestamp })
    rows = live
    track()
    var text = JSON.stringify({ version: 1, active: live.map(function(row) {
      var out = Object.assign({}, row)
      delete out.duration
      return out
    }) }) + "\n"
    if (text === written) return
    written = text
    feedFile.setText(text)
  }

  // ------------------------------------------------------------ lifetime
  //
  // A banner ends after its own duration (the daemon's: 5 to 30 seconds, a
  // critical one waits for you), counted from when it, or its latest text,
  // arrived.
  property var deadlines: ({})
  function track() {
    var next = {}
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      var seen = deadlines[row.key]
      var sig = row.summary + "\n" + row.body
      next[row.key] = seen && seen.sig === sig ? seen : { sig: sig, at: row.duration > 0 ? Date.now() + row.duration : 0 }
    }
    deadlines = next
  }
  Timer {
    interval: 1000
    repeat: true
    running: service.rows.length > 0
    onTriggered: {
      for (var key in service.deadlines)
        if (service.deadlines[key].at > 0 && service.deadlines[key].at <= Date.now()) service.dismissKey(key, "expired")
    }
  }

  // ----------------------------------------------------------- requests
  function dismissKey(key, reason) {
    if (core) core.closeToast(key, reason || "dismissed", true)
    else if (fallback) fallback.dismiss(key)
  }

  function mutateHistory(change) {
    if (!core || !Array.isArray(core.historyEntries) || typeof core.saveSoon !== "function") {
      console.warn("island notifications: Omarchy's notification service can't edit its history; nothing was changed")
      return
    }
    core.historyEntries = change(core.historyEntries)
    core.saveSoon("history")
  }

  ShellIpc {
    target: "island-notifications"

    function ping(): string { return service.core ? "native" : "fallback" }

    // The banner's own dismiss.
    function dismissKey(key: string): string { service.dismissKey(key); return "ok" }

    // A click: Omarchy's own routing (its command, the sender's default
    // action, the sender's window, its site), then the banner goes.
    function invokeKey(key: string): string {
      if (service.core) service.core.activate(key, true)
      else if (service.fallback) service.fallback.invoke(key)
      return "ok"
    }

    // Button n (from 1) of a banner, as it is listed in the feed.
    function runDeed(key: string, n: int): string {
      if (!service.core) return "none"
      return service.core.runDeed(key, n - 1) ? "ok" : "none"
    }

    // A history entry, or all of them.
    function forgetKey(key: string): string {
      service.mutateHistory(function(entries) { return entries.filter(function(entry) { return entry.key !== key }) })
      return "ok"
    }
    function clearHistory(): string {
      service.mutateHistory(function(entries) { return [] })
      return "ok"
    }
  }
}
