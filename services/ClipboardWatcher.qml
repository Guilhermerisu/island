import QtQuick
import Quickshell.Io
import "file:///usr/share/omarchy/shell/plugins/clipboard/ClipboardHistory.js" as ClipboardHistory

// Watches Omarchy's clipboard history for something newly copied, for the
// clipboard pill. The entries already there when the island starts aren't
// news. The clipboard view sets `quietUntil` when it pastes, since pasting
// copies the entry again.
Item {
  id: watcher
  required property string home
  required property var settings
  property var last: null
  property double quietUntil: 0
  property string lastKey: ""
  property bool seeded: false
  signal copied()

  FileView {
    path: watcher.home + "/.local/state/omarchy/clipboard-history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: watcher.historyChanged(text())
  }
  function isHtml(text) {
    return /^\s*<(img|meta|html|!doctype|body|div|span|p|a|picture|figure|table)\b/i.test(String(text || ""))
  }
  function historyChanged(raw) {
    var history = ClipboardHistory.parseHistory(raw)
    var top = history.length ? history[0] : null
    if (top && top.type === "text" && isHtml(top.text) && history.length > 1 && history[1].type === "image")
      top = history[1]
    var key = top ? ClipboardHistory.entryKey(top) : ""
    var fresh = seeded && key !== "" && key !== lastKey
    lastKey = key
    seeded = true
    if (!fresh || !settings.clipboard || Date.now() < quietUntil) return
    last = top
    copied()
  }
}
