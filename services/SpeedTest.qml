import QtQuick
import Quickshell.Io

// Omarchy's internet speed test, run through its own helper
// (omarchy-network-speedtest) the way the native omarchy.speedtest panel does:
// a download phase, then an upload phase. The helper prints one Mbps reading
// per line while it measures, so the last line of a phase is the live figure;
// a failure leaves a message on its stderr. Nothing is measured without
// start(), and stop() ends the traffic: the helper execs the transfer client,
// so killing the process is enough.
Item {
  id: st

  // The view is on screen. Turning it off cancels a test in flight and drops
  // the figures.
  property bool active: false
  // The helper is on PATH (checked when `active` turns on).
  property bool available: false
  property bool running: false
  property string phase: ""       // "down" | "up" | ""
  property real download: 0       // Mbps
  property real upload: 0
  property string error: ""
  // A finished test, so the figures stand and are not just reset to zero.
  property bool done: false

  readonly property string helper: "omarchy-network-speedtest"
  // Set while a cancelled process is still exiting (Process.running stays
  // true until then) and a new run is already wanted.
  property bool restart: false
  property bool cancelled: false
  property string stderrText: ""

  onActiveChanged: {
    if (active) { probe.running = false; probe.running = true }
    else { stop(); download = 0; upload = 0; error = ""; done = false }
  }

  function start() {
    if (!available) return
    if (proc.running) { if (cancelled) restart = true; return }
    error = ""
    download = 0
    upload = 0
    done = false
    running = true
    runPhase("down")
  }

  function stop() {
    restart = false
    watchdog.stop()
    // Clear the phase first: onExited moves on to the upload phase otherwise.
    phase = ""
    running = false
    if (proc.running) { cancelled = true; proc.running = false }
  }

  function runPhase(next) {
    cancelled = false
    phase = next
    stderrText = ""
    proc.command = [helper, next]
    proc.running = true
    watchdog.restart()
  }

  function fail(message) {
    watchdog.stop()
    error = message
    phase = ""
    running = false
  }

  function reading(line) {
    var mbps = parseFloat(line)
    if (!isFinite(mbps) || mbps < 0) return
    if (phase === "down") download = mbps
    else if (phase === "up") upload = mbps
  }

  // Only to hide the button when the helper (an Omarchy 4.5 script) is not
  // there, so a missing one is not an error to the user.
  Process {
    id: probe
    command: ["sh", "-c", 'command -v "$1" >/dev/null', "--", st.helper]
    onExited: function(code) { st.available = code === 0 }
  }

  Process {
    id: proc
    stdout: SplitParser { onRead: function(line) { st.reading(line) } }
    // Exit and stream end come in no fixed order: a failure that exited first
    // shows the generic message, replaced by the helper's own once it lands.
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        st.stderrText = String(text || "").trim()
        if (st.error !== "" && st.stderrText !== "") st.error = st.stderrText
      }
    }
    onExited: function(code) {
      watchdog.stop()
      if (st.restart) {
        st.restart = false
        st.cancelled = false
        if (st.active) Qt.callLater(st.start)
        return
      }
      if (st.cancelled) { st.cancelled = false; return }
      if (code !== 0) { st.fail(st.stderrText || "The speed test failed"); return }
      if (st.phase === "down") { st.runPhase("up"); return }
      st.phase = ""
      st.running = false
      st.done = true
    }
  }

  // The helper owns the warm-up and the measuring window; this is only for
  // one that never exits.
  Timer {
    id: watchdog
    interval: 20000
    onTriggered: {
      st.fail("The speed test timed out")
      if (proc.running) { st.cancelled = true; proc.running = false }
    }
  }

  Component.onDestruction: if (proc.running) proc.running = false
}
