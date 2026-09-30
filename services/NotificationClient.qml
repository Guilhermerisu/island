import QtQuick
import Quickshell
import Quickshell.Io

// The island's side of the guilhermerisu.notifications companion. The
// companion writes the notifications on screen to island-feed.json and keeps
// the rest as files in its history folder; this reads both, and dismisses and
// invokes through `omarchy-shell notifications`. It also decides how a
// notification looks: its icon, its title, and the brand tile Claude Code and
// Codex get.
Item {
  id: client
  required property string home
  // True while the history is on screen (the control center); it's only
  // read then.
  required property bool historyVisible
  readonly property string feedPath: home + "/.local/state/omarchy/island-feed.json"
  readonly property string historyDir: home + "/.local/state/omarchy/notifications/history/"

  property var active: []
  // The one the notification pill shows; the island's own banners (setup,
  // updates) are set here too.
  property var last: null
  property string lastKey: ""
  // The newest ten, on-screen ones first, for the control center.
  property var history: []
  // A notification new to the feed.
  signal arrived(var row)

  onHistoryVisibleChanged: if (historyVisible) refreshHistory()

  function iconSource(row, appIconOnly) {
    if (!row) return ""
    if (agent(row)) return ""
    var value = String((appIconOnly ? "" : row.image) || row.appIcon || "")
    if (value === "") return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return "file://" + value
    return Quickshell.iconPath(value, true)
  }
  function agent(row) {
    var summary = String(row.summary || "")
    if (summary === "Claude Code") return "claude"
    var fromTerminal = /ghostty|kitty|alacritty|foot|wezterm/i.test(String(row.appIcon || "") + " " + String(row.app || ""))
    if (summary === "Codex" || (fromTerminal && /^(Ghostty|kitty|Alacritty|foot|WezTerm)$/.test(summary))) return "codex"
    return ""
  }
  readonly property var brands: ({
    claude: { glyph: "", tile: "#d97757", ink: "#ffffff" },
    codex: { glyph: "", tile: "#f2f2f2", ink: "#000000" }
  })
  function brand(row) {
    var name = row ? agent(row) : ""
    return name ? brands[name] : null
  }
  function title(row) {
    if (!row) return "Notification"
    if (agent(row) === "codex") return "Codex"
    return String(row.summary || row.app || "Notification")
  }
  function age(timestamp) {
    var ms = Date.now() - Number(timestamp || 0)
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
      if (historyVisible) refreshHistory()
      if (!rows.length) return
      var current = rows[0]
      var currentKey = key(current)
      if (currentKey === lastKey) return
      lastKey = currentKey
      last = current
      arrived(current)
    } catch (e) {
      console.warn("island: notification feed parse failed", e)
    }
  }

  Process {
    id: historyProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: client.loadHistory(text)
    }
  }
  function refreshHistory() {
    if (historyProc.running) return
    historyProc.command = ["bash", "-c", "awk 1 \"$1\"/*.json 2>/dev/null || true", "--", historyDir]
    historyProc.running = true
  }
  function loadHistory(raw) {
    var rows = []
    for (var j = 0; j < active.length; j++) {
      var row = Object.assign({}, active[j])
      row.isActive = true
      rows.push(row)
    }
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].trim()) continue
      try { rows.push(JSON.parse(lines[i])) } catch (e) { }
    }
    rows.sort(function(a, b) { return Number(b.timestamp || 0) - Number(a.timestamp || 0) })
    history = rows.slice(0, 10)
  }

  function key(row) {
    return String(row.timestamp) + ":" + String(row.originalId)
  }
  // Runs one of the companion's per-notification methods (dismissKey,
  // invokeKey) on `row`.
  function command(method, row) {
    proc.command = ["omarchy-shell", "notifications", method, key(row)]
    proc.running = true
  }
  Process { id: proc; running: false; onExited: client.refreshHistory() }

  function clearAll() {
    history = []
    proc.command = ["bash", "-c", "omarchy-shell notifications dismissAll; omarchy-shell notifications clear"]
    proc.running = true
  }
  // An on-screen one is dismissed through the companion; one already in the
  // history is deleted with its images.
  function dismiss(row) {
    var rowKey = key(row)
    history = history.filter(function(r) { return key(r) !== rowKey })
    if (row.isActive) {
      proc.command = ["omarchy-shell", "notifications", "dismissKey", rowKey]
    } else {
      var stem = String(row.timestamp) + "-" + String(row.originalId)
      proc.command = ["bash", "-c", "rm -f \"$1/$2.json\" \"$1/../images/$2\"-*", "--", historyDir, stem]
    }
    proc.running = true
  }
}
