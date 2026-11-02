import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Omarchy's screen recording (omarchy-capture-screenrecording), for the
// recording live activity and the control center's Screen Recording control.
// Once gpu-screen-recorder is capturing, Omarchy's script writes the video's
// path to a marker file, and removes it once the video is saved, however the
// recording was started or stopped. While that file is there, the recorder's
// process tells recording from saving (the script trims and normalizes the
// video after it stops); nothing is polled otherwise.
Item {
  id: recorder
  // Omarchy 4.5 keeps the marker in the session runtime dir, with the same
  // fallback its script uses; 4.0 keeps it in /tmp.
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    || ((Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy")
  readonly property string stateFile: (marker.count > 0 ? runtimeDir : "/tmp") + "/omarchy-screenrecord-filename"

  readonly property bool present: marker.count > 0 || legacyMarker.count > 0
  // "idle", "recording", or "saving"
  property string phase: "idle"
  readonly property bool active: phase !== "idle"
  readonly property bool recording: phase === "recording"
  property string path: ""
  property real startedAt: 0
  property real now: Date.now()
  readonly property real elapsed: recording && startedAt > 0 ? Math.max(0, now - startedAt) : 0

  FolderListModel {
    id: marker
    folder: "file://" + recorder.runtimeDir
    nameFilters: ["omarchy-screenrecord-filename"]
    showDirs: false
    onCountChanged: recorder.check()
  }

  FolderListModel {
    id: legacyMarker
    folder: "file:///tmp"
    nameFilters: ["omarchy-screenrecord-filename"]
    showDirs: false
    onCountChanged: recorder.check()
  }

  FileView {
    path: recorder.present ? recorder.stateFile : ""
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      recorder.path = String(text() || "").trim()
      recorder.startedAt = recorder.startFromName(recorder.path) || recorder.startedAt || Date.now()
    }
  }

  // The script's own process counts as saving, so a marker left behind by a
  // recorder that died doesn't hold the island.
  Process {
    id: status
    command: ["sh", "-c", "pgrep -f '^(gpu-screen-recorder|wf-recorder)' >/dev/null && echo recording || { pgrep -f '[o]marchy-capture-screenrecording' >/dev/null && echo saving || echo idle; }"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var phase = String(text || "").trim()
        if (!recorder.present || phase === "") phase = "idle"
        recorder.phase = phase
      }
    }
  }
  function check() {
    if (!present) {
      phase = "idle"
      path = ""
      startedAt = 0
      return
    }
    if (phase === "idle") phase = "recording"
    if (!status.running) status.running = true
  }

  Timer {
    interval: 1000
    repeat: true
    running: recorder.present
    onTriggered: {
      recorder.now = Date.now()
      recorder.check()
    }
  }

  // "…/screenrecording-2026-10-21_14-30-05.mp4" → when it started (ms).
  function startFromName(file) {
    var m = /screenrecording-(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})/.exec(file)
    return m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() : 0
  }

  // Through Omarchy, which stops gpu-screen-recorder so the video is saved.
  function stop() {
    if (!recording) return
    phase = "saving"
    Quickshell.execDetached(["omarchy-capture-screenrecording", "--stop-recording"])
  }

  // "00:42", "12:05", or "1:02:03".
  function timeText(ms) {
    var total = Math.floor(ms / 1000)
    var h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, s = total % 60
    var two = function(n) { return (n < 10 ? "0" : "") + n }
    return h > 0 ? h + ":" + two(m) + ":" + two(s) : two(m) + ":" + two(s)
  }
}
