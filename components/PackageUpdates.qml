import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io

// System updates and installs (pacman, yay, paru, omarchy-update), for the
// download live activity. pacman's lock file starts it; while it runs, this
// reads pacman's log for the phase and the packages done, and the network
// card's receive rate for the download speed (pacman 7 downloads as its own
// user, so its partial files can't be read). It ends when the lock is gone
// and none of those tools is running.
Item {
  id: tracker
  property bool enabled: true
  property string lockDir: "/var/lib/pacman"
  property string logPath: "/var/log/pacman.log"

  property bool active: false
  // "Syncing", "Downloading", "Installing", "Building", "Finishing"
  property string phase: ""
  property string current: ""
  property int count: 0
  property int removedCount: 0
  property real speed: 0
  property string tool: ""

  property string finishedTitle: ""
  property string finishedDetail: ""

  readonly property string status: phase === "Downloading" ? (speed > 0 ? formatSpeed(speed) : "Downloading")
    : phase === "Installing" ? (count > 0 ? count + (count === 1 ? " package" : " packages") : "Installing")
    : phase === "Building" ? "Building"
    : phase

  property real logOffset: 0
  property double startedAt: 0
  property real lastRx: -1
  property double lastRxAt: 0
  property bool sawTransaction: false
  property bool upgrade: false

  function formatSpeed(n) {
    if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB/s"
    if (n >= 1024) return Math.round(n / 1024) + " KB/s"
    return Math.round(n) + " B/s"
  }

  FolderListModel {
    id: lock
    folder: "file://" + tracker.lockDir
    nameFilters: ["db.lck"]
    showDirs: false
    showHidden: true
    onCountChanged: if (tracker.enabled && count > 0) tracker.start()
  }

  function start() {
    if (active) return
    active = true
    finishedTitle = ""
    phase = "Syncing"
    current = ""
    count = 0
    removedCount = 0
    speed = 0
    lastRx = -1
    sawTransaction = false
    upgrade = false
    startedAt = Date.now()
    logOffset = -1
    poll()
  }

  Timer {
    interval: 1000
    repeat: true
    running: tracker.active
    onTriggered: tracker.poll()
  }

  // One line per fact: the lock ("L"), running tools ("P name"), the package
  // makepkg is building ("B name"), bytes received ("R n"), the log's size
  // ("S n"), then the log since the run started.
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
      '[ -e "$2/db.lck" ] && echo L; '
      + 'pgrep -x "pacman|yay|paru|omarchy-update" | while read p; do echo "P $(cat /proc/$p/comm 2>/dev/null)"; done; '
      + 'for p in $(pgrep -x makepkg); do echo "B $(basename "$(readlink /proc/$p/cwd 2>/dev/null)")"; done; '
      + 'rx=0; for f in /sys/class/net/*/statistics/rx_bytes; do case "$f" in */lo/*) ;; *) rx=$((rx + $(cat "$f"))) ;; esac; done; echo "R $rx"; '
      + 'size=$(stat -c %s "$3" 2>/dev/null || echo 0); echo "S $size"; '
      + 'if [ "$1" -ge 0 ]; then echo "--LOG--"; tail -c +$(($1 + 1)) "$3"; fi',
      "sh", String(Math.floor(logOffset)), lockDir, logPath]
    scan.running = true
  }

  function apply(output) {
    var parts = output.split("--LOG--\n")
    var lines = parts[0].split("\n")
    var locked = false, tools = [], building = "", rx = -1, size = 0
    lines.forEach(function(line) {
      if (line === "L") locked = true
      else if (line.indexOf("P ") === 0) tools.push(line.slice(2))
      else if (line.indexOf("B ") === 0 && line.length > 2) building = line.slice(2)
      else if (line.indexOf("R ") === 0) rx = Number(line.slice(2))
      else if (line.indexOf("S ") === 0) size = Number(line.slice(2))
    })

    // First poll: read the log from a little before now, so the lines pacman
    // wrote just before taking the lock are included.
    if (logOffset < 0) {
      logOffset = Math.max(0, size - 4096)
      Qt.callLater(poll)
      return
    }

    tool = tools.indexOf("omarchy-update") >= 0 ? "omarchy"
      : tools.indexOf("paru") >= 0 ? "paru"
      : tools.indexOf("yay") >= 0 ? "yay"
      : "pacman"

    var now = Date.now()
    if (rx >= 0 && lastRx >= 0 && now > lastRxAt) {
      var instant = Math.max(0, (rx - lastRx) * 1000 / (now - lastRxAt))
      speed = speed ? speed * 0.6 + instant * 0.4 : instant
    }
    lastRx = rx
    lastRxAt = now

    var log = parts.length > 1 ? parts[1] : ""
    var done = 0, removed = 0, last = "", completed = false, hooks = false, started = sawTransaction
    log.split("\n").forEach(function(line) {
      var m = line.match(/^\[([^\]]+)\] \[(\w+)\] (.*)$/)
      if (!m) return
      var when = Date.parse(m[1].replace(/([+-]\d\d)(\d\d)$/, "$1:$2"))
      if (!isNaN(when) && when < startedAt - 10000) return
      var msg = m[3]
      var pkg = msg.match(/^(upgraded|installed|removed|downgraded|reinstalled) (\S+)/)
      if (m[2] === "PACMAN" && /starting full system upgrade/.test(msg)) tracker.upgrade = true
      if (msg === "transaction started") { started = true; completed = false; hooks = false }
      else if (msg === "transaction completed") completed = true
      else if (/^running '.*\.hook'/.test(msg)) hooks = true
      else if (pkg) { done++; last = pkg[2]; if (pkg[1] === "removed") removed++ }
    })
    sawTransaction = started
    count = done
    removedCount = removed
    if (last) current = last

    phase = building && !locked ? "Building"
      : completed || hooks ? "Finishing"
      : started ? "Installing"
      : locked && speed > 20480 ? "Downloading"
      : "Syncing"
    if (phase === "Building") current = building

    if (!locked && tools.length === 0 && !building) finish()
  }

  function finish() {
    active = false
    phase = ""
    if (count === 0) return
    finishedTitle = tool === "omarchy" ? "Omarchy Updated"
      : upgrade ? "System Updated"
      : removedCount === count ? (count === 1 ? "Package Removed" : "Packages Removed")
      : removedCount === 0 ? (count === 1 ? "Package Installed" : "Packages Installed")
      : "Packages Changed"
    var minutes = Math.round((Date.now() - startedAt) / 60000)
    finishedDetail = count + (count === 1 ? " package" : " packages")
      + (minutes >= 1 ? " · " + minutes + " min" : "")
    finishedTimer.restart()
  }

  Timer {
    id: finishedTimer
    interval: 6000
    onTriggered: tracker.finishedTitle = ""
  }
  function dismissFinished() {
    finishedTimer.stop()
    finishedTitle = ""
  }
}
