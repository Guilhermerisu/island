import QtQuick
import Quickshell.Io
import ".."

// A countdown timer, as iOS's: set in the timer view (see TimerView), then
// counting down on the resting island (see TimerPill), and a notification
// when it ends. A control center tile (see TimerTile) shows it and opens
// the view. Kept in memory only: a restart of the shell drops it.
Addon {
  id: timerAddon
  views: [{ name: "timer", width: 440, padding: 20, component: timerView }]
  tiles: [{ key: "timer", title: "Timer", component: timerTile }]
  pill: Component { TimerPill { timer: timerAddon } }
  ongoing: phase !== "idle"
  pillWidth: 240
  function pillClicked() { host.view = "timer" }

  Component {
    id: timerView
    TimerView { timer: timerAddon; active: timerAddon.host.view === "timer" }
  }
  Component {
    id: timerTile
    TimerTile { timer: timerAddon; center: parent.center }
  }

  // iOS's timer orange, on the dark island whatever the theme.
  readonly property color tint: "#ff9f0a"
  readonly property color tintDim: Qt.rgba(1, 159 / 255, 10 / 255, 0.35)
  readonly property color tintWell: Qt.rgba(1, 159 / 255, 10 / 255, 0.22)

  // "idle", "running", or "paused"
  property string phase: "idle"
  // The length it was set to, when a running one ends, and what a paused
  // one has left (ms).
  property real duration: 0
  property real endsAt: 0
  property real pausedLeft: 0
  property real now: Date.now()
  readonly property real remaining: phase === "running" ? Math.max(0, endsAt - now)
    : phase === "paused" ? pausedLeft : 0
  // How much is left, 1 to 0.
  readonly property real progress: duration > 0 ? remaining / duration : 0

  Timer {
    interval: 100
    repeat: true
    running: timerAddon.phase === "running"
    onTriggered: {
      timerAddon.now = Date.now()
      if (timerAddon.now >= timerAddon.endsAt) timerAddon.finish()
    }
  }

  function start(ms) {
    duration = ms
    now = Date.now()
    endsAt = now + ms
    phase = "running"
  }
  function pause() {
    if (phase !== "running") return
    pausedLeft = Math.max(0, endsAt - Date.now())
    phase = "paused"
  }
  function resume() {
    if (phase !== "paused") return
    now = Date.now()
    endsAt = now + pausedLeft
    phase = "running"
  }
  function togglePause() { phase === "running" ? pause() : resume() }
  function cancel() { phase = "idle" }

  // Ended: unset, and said so in a notification ("Timer", "Your 15 min timer
  // is up"), which the island draws with the timer's own orange icon (see
  // NotificationClient).
  Process { id: notifier }
  function finish() {
    phase = "idle"
    notifier.command = ["notify-send", "-a", "Island Timer", "Timer",
      "Your " + durationText(duration) + " timer is up"]
    notifier.startDetached()
  }

  // "08:30", "48:54", or "1:30:00", whole seconds rounded up, as iOS
  // counts down.
  function timeText(ms) {
    var total = Math.ceil(ms / 1000)
    var h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, s = total % 60
    var two = function(n) { return (n < 10 ? "0" : "") + n }
    return h > 0 ? h + ":" + two(m) + ":" + two(s) : two(m) + ":" + two(s)
  }

  // A length as said: "15 min", "1 h 30 min", "1 min 30 sec", "45 sec".
  function parts(ms) {
    var total = Math.round(ms / 1000)
    return { h: Math.floor(total / 3600), m: Math.floor(total / 60) % 60, s: total % 60 }
  }
  function durationText(ms) {
    var p = parts(ms), said = []
    if (p.h) said.push(p.h + " h")
    if (p.m) said.push(p.m + " min")
    if (p.s) said.push(p.s + " sec")
    return said.join(" ")
  }
}
