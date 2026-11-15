import QtQuick
import Quickshell.Io

// Checks GitHub for a newer island (20 seconds after the shell starts, then
// every six hours) and installs it. Only a git checkout of the plugin can
// update; the check is skipped otherwise. The update (update.sh) runs
// detached, since updating the plugin folder reloads the island, and restarts
// the shell when it's done. When it can't update, it says why through the
// island's updateFailed command, which lands in fail().
Item {
  id: updater
  required property string pluginDir
  // "", "available", or "updating".
  property string status: ""
  // A newer version is on GitHub.
  signal available()
  // The update didn't go ahead; the row is a banner saying why, which retries
  // when clicked.
  signal failed(var row)

  // The notification pill's row for an update banner; clicking it updates.
  function bannerRow(body) {
    return { summary: "Island Update", body: body, glyph: "󰚰", timestamp: Date.now(), islandUpdate: true }
  }
  function update() {
    if (status === "updating") return
    status = "updating"
    installUpdate.running = true
  }
  function fail(reason) {
    status = "available"
    failed({ summary: "Island Update Failed · Click to Retry", body: String(reason || "The update stopped without saying why."),
      glyph: "󰀦", timestamp: Date.now(), islandUpdate: true, islandFailure: true })
  }

  Timer {
    interval: 20000
    running: true
    repeat: true
    onTriggered: {
      interval = 6 * 3600 * 1000
      if (!updateCheck.running && updater.status !== "updating") updateCheck.running = true
    }
  }
  Process {
    id: updateCheck
    command: ["bash", "-c", "cd \"$1\" && [ -d .git ] || exit 0; export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -oBatchMode=yes'; remote=$(timeout 30 git ls-remote origin HEAD 2>/dev/null | cut -f1); [ -n \"$remote\" ] || exit 0; git merge-base --is-ancestor \"$remote\" HEAD 2>/dev/null || echo available", "update-check", updater.pluginDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text || "").trim() !== "available" || updater.status === "updating") return
        updater.status = "available"
        updater.available()
      }
    }
  }
  Process {
    id: installUpdate
    command: ["setsid", "-f", "bash", updater.pluginDir + "/services/update.sh", updater.pluginDir]
  }
}
