import QtQuick
import Quickshell
import Quickshell.Io
import "../components/IconSource.js" as IconSource

// The island's side of the guilhermerisu.notifications companion, which wraps
// Omarchy's own notification service. The companion writes the notifications
// on screen to island-feed.json; the closed ones are in Omarchy's own
// history.json. This reads both, and dismisses, invokes and presses buttons
// through the companion (`omarchy-shell island-notifications`). It also
// decides how a notification looks: its icon, its title, and the brand tile
// Claude Code and Codex get.
Item {
  id: client
  required property string home
  // True while the history is on screen (the control center); it's only
  // read then.
  required property bool historyVisible
  readonly property string feedPath: home + "/.local/state/omarchy/notifications/island-feed.json"
  readonly property string historyPath: home + "/.local/state/omarchy/notifications/history.json"
  readonly property int historyLimit: 30

  property var active: []
  // The closed ones, from Omarchy's history.json.
  property var closed: []
  // The one the notification pill shows; the island's own banners (setup,
  // updates) are set here too.
  property var last: null
  property double lastStamp: 0
  // The newest ones, on-screen or closed, for the control center.
  property var history: []
  // The same, an app's notifications together: [{ id, head, rest: [...] }],
  // newest stack first. A notification with no app group stands alone, and
  // all of them do with `stacked` off.
  property var stacks: []
  property bool stacked: false
  onStackedChanged: rebuild()
  // A notification new to the feed.
  signal arrived(var row)

  onHistoryVisibleChanged: if (historyVisible) refreshHistory()

  function iconSource(row, appIconOnly) {
    if (!row) return ""
    if (agent(row)) return ""
    return IconSource.source((appIconOnly ? "" : row.image) || row.appIcon)
  }
  function agent(row) {
    // The timer addon's, sent under its own app name (see TimerAddon).
    if (String(row.app || "") === "Island Timer") return "timer"
    var summary = String(row.summary || "")
    if (summary === "Claude Code") return "claude"
    if (summary === "Gemini" || summary === "Antigravity" || summary === "agy") return "gemini"
    var fromTerminal = /ghostty|kitty|alacritty|foot|wezterm/i.test(String(row.appIcon || "") + " " + String(row.app || ""))
    if (summary === "Codex" || (fromTerminal && /^(Ghostty|kitty|Alacritty|foot|WezTerm)$/.test(summary))) return "codex"
    return ""
  }
  readonly property var brands: ({
    claude: { glyph: "", tile: "#d97757", ink: "#ffffff" },
    codex: { glyph: "", tile: "#f2f2f2", ink: "#000000" },
    gemini: { glyph: "✦", tile: "#1a73e8", ink: "#ffffff" },
    timer: { glyph: "󰔛", tile: "#ff9f0a", ink: "#ffffff" }
  })
  function brand(row) {
    var name = row ? agent(row) : ""
    return name ? brands[name] : null
  }
  function title(row) {
    if (!row) return "Notification"
    if (agent(row) === "codex") return "Codex"
    if (agent(row) === "gemini") return "Gemini"
    return String(row.summary || row.app || "Notification")
  }
  function age(timestamp, now) {
    var ms = (now || Date.now()) - Number(timestamp || 0)
    if (!timestamp || ms < 60000) return "now"
    if (ms < 3600000) return Math.floor(ms / 60000) + "m ago"
    if (ms < 86400000) return Math.floor(ms / 3600000) + "h ago"
    return Qt.formatDateTime(new Date(Number(timestamp)), "d MMM")
  }

  FileView {
    path: client.feedPath
    watchChanges: true
    printErrors: false
    onLoaded: client.loadFeed(text())
    onFileChanged: reload()
  }
  function loadFeed(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      var rows = Array.isArray(parsed.active) ? parsed.active : []
      active = rows
      rebuild()
      if (!rows.length) return
      // A newer one than any announced, not the older one a dismissal
      // uncovers; a replaced or replayed notification is newer again.
      var current = rows[0]
      var stamp = Number(current.shown || current.timestamp || 0)
      if (stamp <= lastStamp) return
      lastStamp = stamp
      last = current
      arrived(current)
    } catch (e) {
      console.warn("island: notification feed parse failed", e)
    }
  }

  FileView {
    id: historyFile
    path: client.historyPath
    watchChanges: true
    printErrors: false
    onLoaded: client.loadHistory(text())
    onFileChanged: reload()
  }
  function refreshHistory() { historyFile.reload() }
  // The entries as Omarchy stores them (docs/notifications.md; ts is seconds,
  // the body is markup) in the shape of the feed's rows.
  function loadHistory(raw) {
    var rows = []
    try {
      var parsed = JSON.parse(raw || "[]")
      for (var i = 0; Array.isArray(parsed) && i < parsed.length; i++) {
        var e = parsed[i]
        if (!e || typeof e !== "object" || !e.key) continue
        rows.push({ key: String(e.key), originalId: e.originalId, timestamp: Math.round(Number(e.ts || e.closed_ts || 0) * 1000),
          app: e.app, appIcon: e.appIcon, glyph: e.glyph, summary: e.summary, body: plain(e.body), urgency: e.urgency,
          group: e.groupKey, actions: [], isActive: false })
      }
    } catch (err) {
      console.warn("island: notification history parse failed", err)
    }
    closed = rows
    rebuild()
  }
  // The body as one line of text: no markup, no entities.
  function plain(markup) {
    return String(markup || "").replace(/<br\s*\/?>/gi, " ").replace(/<[^>]+>/g, "")
      .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&")
      .replace(/\s+/g, " ").trim()
  }
  // On-screen ones first among equals, then by when they came; stacked by app.
  function rebuild() {
    var rows = []
    var seen = {}
    for (var j = 0; j < active.length; j++) {
      var row = Object.assign({}, active[j])
      row.isActive = true
      seen[key(row)] = true
      rows.push(row)
    }
    for (var c = 0; c < closed.length; c++) if (!seen[key(closed[c])]) rows.push(closed[c])
    rows.sort(function(a, b) { return Number(b.timestamp || 0) - Number(a.timestamp || 0) })
    history = rows.slice(0, historyLimit)
    var byGroup = {}
    var out = []
    for (var k = 0; k < history.length; k++) {
      var group = stacked ? String(history[k].group || "") : ""
      if (group && byGroup[group]) { byGroup[group].rest.push(history[k]); continue }
      var stack = { id: group || key(history[k]), head: history[k], rest: [] }
      if (group) byGroup[group] = stack
      out.push(stack)
    }
    stacks = out
  }

  // The companion's key; the feed of the previous companion had none.
  function key(row) {
    return row.key ? String(row.key) : String(row.timestamp) + ":" + String(row.originalId)
  }
  // Runs one of the companion's per-notification methods (dismissKey,
  // invokeKey, forgetKey) on `row`.
  function command(method, row) {
    proc.command = ["omarchy-shell", "island-notifications", method, key(row)]
    proc.running = true
  }
  Process { id: proc; running: false }
  // Presses button `index` (from 0) of an on-screen notification.
  function runAction(row, index) {
    proc.command = ["omarchy-shell", "island-notifications", "runDeed", key(row), String(index + 1)]
    proc.running = true
  }

  // Takes the user to where a notification came from. One still on screen
  // (`live`) is invoked through the companion: its default action, or else the
  // sending app's window. One only in the history has nothing left to invoke,
  // so the sending app's window is focused here.
  function open(row, live) {
    if (live || row.isActive) command("invokeKey", row)
    else if (row.app) {
      focusProc.command = ["omarchy-hyprland-focus-app", String(row.app)]
      focusProc.startDetached()
    }
  }
  Process { id: focusProc }

  function clearAll() {
    history = []
    stacks = []
    proc.command = ["bash", "-c", "omarchy-shell notifications dismissAll; omarchy-shell island-notifications clearHistory"]
    proc.running = true
  }
  // An on-screen one is dismissed through the companion, a closed one is
  // taken out of Omarchy's history.
  function dismiss(row) {
    var rowKey = key(row)
    active = active.filter(function(r) { return key(r) !== rowKey })
    closed = closed.filter(function(r) { return key(r) !== rowKey })
    rebuild()
    command(row.isActive ? "dismissKey" : "forgetKey", row)
  }
}
