import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// System Stats: Activity Monitor's figures as a pane in Settings (see
// StatsPage). The sampler (sampler.py) runs while Settings is open on any
// screen, so the pane has figures the moment it's picked, printing a
// reading every five seconds; the latest is kept here.
Addon {
  id: stats
  settingsPages: [{
    title: "System Stats",
    source: Qt.resolvedUrl("StatsPage.qml"), properties: { stats: stats },
    about: "Live CPU, memory, GPU, and disk use.",
    search: "system stats activity monitor cpu processor load memory ram pressure swap gpu graphics vram disk storage processes quit force kill"
  }]

  readonly property bool sampling: host.view === "settings"
  onSamplingChanged: if (sampling) clear()

  property var latest: null
  function clear() { latest = null }
  function take(line) {
    try { latest = JSON.parse(line) } catch (e) {}
  }

  // Held off for a moment after the sampler dies on its own, so it starts
  // again rather than leaving the pane frozen.
  property bool resting: false
  Timer { id: rest; interval: 2000; onTriggered: stats.resting = false }
  Process {
    id: sampler
    running: stats.sampling && !stats.resting
    onExited: if (stats.sampling && !stats.resting) { stats.resting = true; rest.restart() }
    command: ["python3", decodeURIComponent(String(Qt.resolvedUrl("sampler.py")).replace("file://", ""))]
    stdout: SplitParser { onRead: function(line) { stats.take(line) } }
  }

  // Quit (SIGTERM) or Force Quit (SIGKILL) a row's processes of the user's,
  // as the latest reading has them: a lone process only if it's still the
  // same one (pid and start time), an app's all those under its window now.
  function quit(row, force) {
    var procs = latest ? latest.processes : []
    var same = function(p) { return p.pid === row.pid && p.start === row.start }
    if (!procs.some(same)) return
    var pids = procs.filter(function(p) {
      return p.uid === latest.uid && (row.pids ? p.app === row.app : same(p))
    }).map(function(p) { return String(p.pid) })
    if (pids.length) Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM"].concat(pids))
  }
}
