import QtQuick
import Quickshell.Io
import ".."

// Agents: Claude Code's or Codex's usage as a pane in Settings (see
// AgentsPage), the agent picked in the addon's options. The figures are
// Omarchy's own: its omarchy-agent-usage-<agent> collectors write one record
// per agent into ~/.local/state/omarchy/agents/usage/, the same ones the stock
// Agents bar panel reads. The record is read as soon as Settings opens, and
// regenerated then and every few minutes while it stays open; the collectors
// reuse their recent transcript scans, so only the limits go over the wire.
//
// While Claude Code works, it's a live activity too (see AgentsPill): its
// turn as it goes, read from its transcripts by live.py, with Clawd
// (AgentsMascot) acting it out. It says when a turn's done, and grows by
// itself when it's waiting on you.
Addon {
  id: agentsAddon
  pill: Component { AgentsPill { agents: agentsAddon } }
  ongoing: working || finished
  // Grown, it hides the clock and takes the island to itself.
  pillAsks: expanded
  readonly property real restHeight: host.settings.notch ? 40 : 44
  readonly property real inset: 24
  readonly property int rows: 3
  readonly property real rowHeight: 27
  // Grown, its height follows its steps, which can take two lines each
  // (see AgentsPill).
  property real grownHeight: 173
  pillWidth: expanded ? 460 : 236
  pillHeight: expanded ? grownHeight : restHeight
  pillRadius: expanded ? 32 : 0
  // Claude's orange, or the theme's accent when live activities aren't
  // colorful; amber while it waits on you.
  readonly property color ink: asking ? host.theme.system.orange
    : host.settings.colorfulLiveActivities ? "#d97757" : host.theme.accent
  // Drawn with the picked agent's logo, not the addon's, at its size; the
  // pane leads with the agent as its own header (see AgentsPage).
  settingsPages: [{
    title: "Agents", icon: provider.glyph, color: provider.color, header: false,
    iconLayers: [{ glyph: provider.glyph, color: "#ffffff", x: 0.5, y: 0.5, size: provider.glyphSize }],
    source: Qt.resolvedUrl("AgentsPage.qml"), properties: { agents: agentsAddon },
    about: "Usage limits and tokens by day for your coding agent.",
    search: "agents ai claude code codex usage limits rate session 5-hour five hour weekly week tokens day plan subscription"
  }]

  // Claude's mark reads smaller than Codex's at the same size, so it's drawn larger.
  readonly property var providers: ({
    claude: { id: "claude", name: "Claude Code", glyph: "", glyphSize: 0.7, color: "#d97757", login: "claude auth login" },
    codex: { id: "codex", name: "Codex", glyph: "", glyphSize: 0.6, color: host.theme.system.blue, login: "codex login" },
    // Every model on this machine, from all-usage.py: no limits, just tokens.
    all: { id: "all", name: "All Models", glyph: "󰚩", glyphSize: 0.6, color: host.theme.system.indigo, login: "" }
  })
  readonly property var provider: providers[addon.option("agent")] || providers.claude

  readonly property bool watching: host.view === "settings"
  readonly property string usageDir: host.home + "/.local/state/omarchy/agents/usage"
  readonly property string recordPath: provider.id === "all"
    ? host.home + "/.cache/guilhermerisu.island/agents/all.json"
    : usageDir + "/" + provider.id + ".json"

  // The latest record for the picked agent, or null before one is read.
  property var record: null
  property bool updating: false
  onProviderChanged: { record = null; recordFile.reload(); refresh() }
  onWatchingChanged: if (watching) { recordFile.reload(); refresh() }

  FileView {
    id: recordFile
    path: agentsAddon.recordPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { agentsAddon.take(JSON.parse(text())) } catch (e) {}
    }
    onFileChanged: reload()
  }

  // Mid-refresh, Codex's record lands without limits before codex-limits.py
  // fills them in; the ones already shown are kept until then.
  function take(next) {
    var old = record
    if (updating && old && old.id === next.id && !(next.limits || []).length && (old.limits || []).length)
      next = Object.assign({}, next, { limits: old.limits, usageStatusText: "", tierLabel: next.tierLabel || old.tierLabel })
    record = next
  }

  // A run collapses into one queued rerun if asked again meanwhile.
  property bool rerun: false
  Process {
    id: update
    onExited: {
      agentsAddon.updating = false
      recordFile.reload()
      if (agentsAddon.rerun) { agentsAddon.rerun = false; agentsAddon.refresh() }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("agents addon:", text.trim())
    }
  }
  function refresh() {
    if (update.running) { rerun = true; return }
    updating = true
    // Codex's collector gives up on its limits here, so codex-limits.py
    // fills them in after it (see there).
    // All Models regenerates both agents' records, then merges them with
    // the other models' sessions (all-usage.py).
    update.command = provider.id === "all"
      ? ["bash", "-c", "omarchy-agent-usage-update claude codex; python3 \"$1\"; python3 \"$2\"", "bash",
         agentsAddon.localPath("codex-limits.py"), agentsAddon.localPath("all-usage.py")]
      : provider.id === "codex"
      ? ["bash", "-c", "omarchy-agent-usage-update codex; python3 \"$1\"", "bash", agentsAddon.localPath("codex-limits.py")]
      : ["omarchy-agent-usage-update", provider.id]
    update.running = true
  }
  function localPath(file) { return decodeURIComponent(String(Qt.resolvedUrl(file)).replace("file://", "")) }
  Timer {
    interval: 5 * 60 * 1000
    repeat: true
    running: agentsAddon.watching
    onTriggered: agentsAddon.refresh()
  }

  // ---------- Live activity ----------

  // Claude Code's sessions at work, newest first (see live.py); the pill
  // shows the newest.
  property var sessions: []
  readonly property var session: sessions.length ? sessions[0] : null
  readonly property bool working: sessions.some(function(s) { return s.state !== "done" })
  readonly property var live: working ? sessions.filter(function(s) { return s.state !== "done" })[0] : session
  // The step it's taking: with several asked at once, the first, as the
  // others wait for it.
  readonly property var current: {
    var steps = live ? live.steps : []
    for (var i = 0; i < steps.length; i++) if (steps[i].status === "running") return steps[i]
    return null
  }
  // Waiting on your answer to a question or its plan.
  readonly property bool asking: !!live && live.state === "asking"
  onAskingChanged: if (asking) present()

  Process {
    id: liveWatch
    running: agentsAddon.addon.option("live") !== false
    command: ["python3", agentsAddon.localPath("live.py")]
    stdout: SplitParser {
      onRead: function(line) {
        try { agentsAddon.takeSessions(JSON.parse(line).sessions || []) } catch (e) {}
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("agents addon:", text.trim())
    }
    onRunningChanged: if (!running) agentsAddon.sessions = []
  }

  // A turn that ends while it's shown says so on the pill a moment, as a
  // call that ends does (see AgentsPill); it stays while the pointer's on
  // it.
  property bool finished: false
  function takeSessions(next) {
    var wasWorking = working
    sessions = next
    if (wasWorking && !working && next.length && next[0].state === "done") {
      finished = true
      finishedTimer.restart()
    } else if (working) {
      finished = false
      finishedTimer.stop()
    }
  }
  Timer {
    id: finishedTimer
    interval: 4000
    onTriggered: if (agentsAddon.hovered) restart(); else agentsAddon.finished = false
  }

  // As Apple's live activities alert: grown by itself for a few seconds
  // when it starts waiting on you, unless the pointer's holding it open.
  function present() {
    openTimer.stop()
    collapseTimer.stop()
    expanded = true
    presentTimer.restart()
  }
  Timer {
    id: presentTimer
    interval: 4500
    onTriggered: if (!agentsAddon.hovered) agentsAddon.expanded = false
  }

  // The turn's time and the running step's, by the second while they're on
  // screen; done, the turn's stops where it ended.
  property real now: Date.now()
  Timer {
    interval: 1000
    repeat: true
    running: agentsAddon.pillShown && agentsAddon.working
    triggeredOnStart: true
    onTriggered: agentsAddon.now = Date.now()
  }
  readonly property real turnStart: live ? live.startedAt || (live.steps.length ? live.steps[0].startedAt : 0) : 0
  readonly property real turnTime: !turnStart ? 0 : Math.max(0, (live.state === "done" ? live.doneAt : now) - turnStart)
  // A step's length, shorter: <1s, 4s, 1:12.
  function durationText(ms) {
    var s = Math.floor(Math.max(0, ms) / 1000)
    return s < 1 ? "<1s" : s < 60 ? s + "s" : timeText(ms)
  }
  // 0:04, 12:31, 1:02:10
  function timeText(ms) {
    var s = Math.max(0, Math.floor(ms / 1000))
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
    var ss = ("0" + s % 60).slice(-2)
    return h > 0 ? h + ":" + ("0" + m).slice(-2) + ":" + ss : m + ":" + ss
  }

  // As the call's: it opens once the pointer rests on it, and closes a
  // moment after it leaves.
  property bool hovered: false
  property bool expanded: false
  onHoveredChanged: {
    if (hovered && ongoing) { collapseTimer.stop(); if (!expanded) openTimer.restart() }
    else { openTimer.stop(); collapseTimer.restart() }
  }
  onOngoingChanged: if (!ongoing) expanded = false
  onPillShownChanged: if (!pillShown) { openTimer.stop(); collapseTimer.stop(); expanded = false }
  Timer {
    id: openTimer
    interval: 120
    onTriggered: if (agentsAddon.hovered && agentsAddon.ongoing) agentsAddon.expanded = true
  }
  Timer {
    id: collapseTimer
    interval: 450
    onTriggered: agentsAddon.expanded = false
  }
}
