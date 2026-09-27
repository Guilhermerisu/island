import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Downloads in progress, for the download live activity. Browsers (and
// yt-dlp) write to a temporary file (.part, .crdownload) in the Downloads
// folder and rename it when it's done. Neither records the final size, so
// this reports bytes so far and speed, not a percentage. The folder is only
// polled while something is downloading.
Item {
  id: tracker
  property bool enabled: true
  property string folder: Quickshell.env("HOME") + "/Downloads"

  // [{ name, part, bytes, speed }] for each download in progress.
  property var items: []
  readonly property bool active: enabled && items.length > 0
  readonly property real speed: items.reduce(function(sum, d) { return sum + d.speed }, 0)
  readonly property real bytes: items.reduce(function(sum, d) { return sum + d.bytes }, 0)
  // The download that just finished, for a few seconds.
  property string finishedName: ""
  property real finishedBytes: 0
  readonly property string finishedPath: finishedName ? folder + "/" + finishedName : ""

  property var previous: ({})
  property var lastBytes: ({})
  property var pendingFinals: []

  Process {
    running: true
    command: ["xdg-user-dir", "DOWNLOAD"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { var dir = String(text || "").trim(); if (dir) tracker.folder = dir }
    }
  }

  FolderListModel {
    id: partials
    folder: "file://" + tracker.folder
    nameFilters: ["*.part", "*.crdownload"]
    showDirs: false
    showHidden: true
    onCountChanged: if (tracker.enabled) tracker.poll()
  }

  Timer {
    interval: 1000
    repeat: true
    running: tracker.enabled && (partials.count > 0 || tracker.pendingFinals.length > 0 || tracker.items.length > 0)
    onTriggered: tracker.poll()
  }

  // Lists each temporary file with its size ("P"), and which of the files
  // that just disappeared now exist under their final name ("D").
  Process {
    id: scan
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: tracker.apply(String(text || ""))
    }
  }
  function poll() {
    if (scan.running) return
    scan.command = ["sh", "-c",
      'cd "$1" || exit 0; shift; '
      + 'for f in *.part *.crdownload; do [ -f "$f" ] && printf "P\\t%s\\t%s\\n" "$(stat -c %s -- "$f")" "$f"; done; '
      + 'for f; do [ -s "$f" ] && printf "D\\t%s\\n" "$f"; done',
      "sh", folder].concat(pendingFinals)
    scan.running = true
  }

  function finalName(part) { return part.replace(/\.(part|crdownload)$/, "") }

  function apply(output) {
    var now = Date.now()
    var current = {}, rows = [], done = []
    output.split("\n").forEach(function(line) {
      var cols = line.split("\t")
      if (cols[0] === "P" && cols.length >= 3) current[cols.slice(2).join("\t")] = Number(cols[1]) || 0
      else if (cols[0] === "D" && cols.length >= 2) done.push(cols.slice(1).join("\t"))
    })
    for (var part in current) {
      var before = previous[part]
      var bytes = current[part]
      var speed = 0
      if (before && now > before.time) {
        var instant = Math.max(0, (bytes - before.bytes) * 1000 / (now - before.time))
        speed = before.speed ? before.speed * 0.6 + instant * 0.4 : instant
      }
      current[part] = { bytes: bytes, time: now, speed: speed }
      rows.push({ name: finalName(part), part: part, bytes: bytes, speed: speed })
    }
    var vanished = []
    for (var old in previous) {
      if (old in current) continue
      vanished.push(finalName(old))
      lastBytes[finalName(old)] = previous[old].bytes
    }
    previous = current
    items = rows
    pendingFinals = vanished
    if (done.length) {
      finishedName = done[done.length - 1]
      finishedBytes = lastBytes[finishedName] || 0
      lastBytes = ({})
      finishedTimer.restart()
    }
    if (vanished.length) Qt.callLater(poll)
  }

  Timer {
    id: finishedTimer
    interval: 4500
    onTriggered: tracker.finishedName = ""
  }
  function dismissFinished() {
    finishedTimer.stop()
    finishedName = ""
  }
}
