import QtQuick
import Quickshell
import Quickshell.Io

// Whether the guilhermerisu.notifications companion (and the rest of the
// island's setup: menu entries, keybindings) is installed, and running setup
// when the pill is clicked. companion/check.sh reports the state: "ok", or
// what's missing.
//
// Setup runs detached and reports through a status file: installing the
// companion makes the shell reload the island, which would otherwise end
// setup with it and lose track of how it went. Its output goes to
// island-setup.log next to the status file.
Item {
  id: setup
  required property string home
  readonly property string pluginDir: String(Qt.resolvedUrl("..")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string companionDir: pluginDir + "/companion"
  readonly property string menuPath: home + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy"

  property string status: ""
  property bool installing: false
  property bool running: false
  // Why the last setup failed, from the status file; empty when it didn't.
  property string failure: ""
  property bool recheck: false
  readonly property bool needsSetup: status !== "" && status !== "ok"
  readonly property string warning: installing ? "Setting up…"
    : status === "menu-invalid" ? "Fix omarchy-menu.jsonc"
    : failure !== "" ? "Setup failed · Click for details" : "Click to Setup"
  // A failed setup's reason, for the island to show as a banner; clicking the
  // banner runs setup again.
  signal failureBanner(var row)

  Component.onCompleted: check()
  function check() { companionCheck.running = true }

  Process {
    id: companionCheck
    command: ["bash", setup.companionDir + "/check.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        setup.status = String(text || "").trim()
        if (setup.recheck) { setup.recheck = false; Qt.callLater(setup.check); return }
        if (!setup.running) setup.installing = false
      }
    }
  }

  // A broken menu file can't take the island's entries, so the pill opens it
  // for fixing; the check runs again whenever it's saved.
  Process { id: menuEditor; command: ["omarchy-launch-editor", setup.menuPath] }
  FileView {
    path: setup.menuPath
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      if (!companionCheck.running && !setup.installing) setup.check()
    }
  }

  function pillClicked() {
    if (status === "menu-invalid") menuEditor.running = true
    else if (failure !== "") {
      failureBanner({ summary: "Island Setup Failed · Click to Retry", body: failure.charAt(0).toUpperCase() + failure.slice(1),
        glyph: "󰀦", timestamp: Date.now(), islandSetupRetry: true })
    }
    else install()
  }
  function install() {
    if (installing) return
    failure = ""
    installing = true
    companionInstall.running = true
  }
  Process {
    id: companionInstall
    command: ["setsid", "-f", "bash", "-c", "mkdir -p \"$(dirname \"$2\")\"; exec bash \"$1\" >\"$2\" 2>&1 </dev/null",
      "island-setup", setup.companionDir + "/install.sh", setup.stateDir + "/island-setup.log"]
  }
  FileView {
    id: statusFile
    path: setup.stateDir + "/island-setup"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: setup.readStatus(text())
  }
  // "running <started>", "done", or "failed". A run older than two minutes
  // was cut short.
  function readStatus(raw) {
    var parts = String(raw || "").trim().split(/\s+/)
    var isRunning = parts[0] === "running" && Date.now() / 1000 - Number(parts[1] || 0) < 120
    running = isRunning
    if (isRunning) { installing = true; return }
    failure = parts[0] === "failed" ? parts.slice(1).join(" ") || "setup stopped unexpectedly"
      : parts[0] === "running" ? "setup stopped before it finished" : ""
    // Keep showing "Setting up…" until the check below says how it went.
    if (companionCheck.running) recheck = true
    else check()
  }
  // The status file may not exist until setup creates it, which a file watch
  // can miss; look again while setup runs, and give up after two minutes.
  Timer {
    interval: 2000
    repeat: true
    running: setup.installing
    onTriggered: statusFile.reload()
  }
  Timer {
    interval: 120000
    running: setup.installing
    onTriggered: {
      setup.running = false
      setup.installing = false
      setup.failure = "setup didn't finish within two minutes"
      setup.check()
    }
  }
}
