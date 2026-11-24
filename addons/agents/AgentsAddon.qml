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
// While Claude Code or Codex works, it's a live activity too (see AgentsPill):
// its turn as it goes, read from its transcripts by live.py, with its mascot
// (AgentAvatar) acting it out: Clawd for Claude Code, and for Codex the pet
// picked in Codex or the ChatGPT desktop app (pet.py), Clawd standing in
// when none's found. It says when a turn's done.
Addon {
  id: agentsAddon
  pill: Component { AgentsPill { agents: agentsAddon } }
  ongoing: working || finished
  pillWidth: noticeShown ? 328 : 236
  // Grown into a notice (see AgentNotice): room for the mascot's tile, the
  // name over what happened, and the badge, with corners concentric with
  // the tile's (its radius plus the inset around it).
  pillHeight: noticeShown ? 62 : restHeight
  pillRadius: noticeShown ? 13 + (62 - 39) / 2 : 0
  // The agent's color (Claude's orange, Codex's lavender), or the theme's
  // accent when live activities aren't colorful; amber while it waits on you.
  readonly property color ink: asking ? host.theme.system.orange
    : host.settings.colorfulLiveActivities ? (live && live.provider === "codex" ? "#aca1c8" : "#d97757")
    : host.theme.accent
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
  readonly property var selectedAgents: {
    var saved = addon.option("agent")
    var ids = typeof saved === "string" ? [saved] : Array.from(saved || [])
    var valid = ids.filter(function(id, index) { return !!providers[id] && ids.indexOf(id) === index })
    return valid.length ? valid : ["claude"]
  }
  property string activeAgent: ""
  readonly property string providerId: selectedAgents.indexOf(activeAgent) >= 0 ? activeAgent : selectedAgents[0]
  readonly property var provider: providers[providerId]

  // Or a zone of the control center is on screen (see zoneViews in Addon.qml).
  readonly property bool watching: host.view === "settings" || zoneViews > 0
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
  // Waiting on your answer to a question or its plan.
  readonly property bool asking: !!live && live.state === "asking"

  // Codex's pet, looked for once there's a Codex session to show (and at
  // the start, so it's loaded by then); Clawd is drawn until it's found.
  property url petSheet: ""
  property int petCols: 8
  property int petRows: 9
  readonly property bool hasCodexSession: sessions.some(function(s) { return s.provider === "codex" })
  onHasCodexSessionChanged: if (hasCodexSession && !String(petSheet)) petFinder.running = true
  // Clawd's sheet, painted out of the Claude desktop app's sprites (see
  // clawd.py): null until it is, or without the app, and the built-in one's
  // drawn.
  property var clawd: null
  Process {
    id: clawdFinder
    running: agentsAddon.addon.option("live") !== false
    command: ["python3", agentsAddon.localPath("clawd.py")]
    stdout: StdioCollector {
      onStreamFinished: {
        try { agentsAddon.clawd = JSON.parse(text) } catch (e) {}
      }
    }
  }
  Process {
    id: petFinder
    running: agentsAddon.addon.option("live") !== false
    command: ["python3", agentsAddon.localPath("pet.py")]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var pet = JSON.parse(text)
          agentsAddon.petCols = pet.cols
          agentsAddon.petRows = pet.rows
          agentsAddon.petSheet = pet.source
        } catch (e) {}
      }
    }
  }

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

  // Each session's last state, to see what changed: a turn that ends, or
  // one that starts waiting on you, is announced by the pill growing into a
  // notice of it (see AgentNotice), which comes up even while the island is
  // hidden (in fullscreen, say). The first look only learns the states.
  property var lastStates: null
  // What's waiting to be announced, and the one on screen.
  property var pending: []
  property var notice: null
  function announce(next) {
    var before = lastStates
    var states = {}
    next.forEach(function(s) { states[s.id] = s.state })
    lastStates = states
    if (!before || addon.option("banners") === false) return
    var events = []
    next.forEach(function(s) {
      var was = before[s.id]
      if (was === s.state) return
      var ended = s.state === "done" && !s.interrupted && was && was !== "done"
      if (ended || (s.state === "asking" && was !== "asking"))
        events.push(Object.assign({}, s, { noticeKind: s.state, noticeAt: Date.now() }))
    })
    if (!events.length) return
    pending = pending.concat(events).slice(-6)
    if (!notice) advanceNotice()
  }
  // A question already answered isn't announced any more.
  function stale(event) {
    if (!event || event.noticeKind !== "asking") return false
    var now = sessions.find(function(s) { return s.id === event.id })
    return !now || now.state !== "asking"
  }
  // The next one, unless its window is the one you're in (see
  // focus-session.py --focused): the one on screen stays while that's
  // looked up, so the pill goes straight from one to the next.
  function advanceNotice() {
    noticeTimer.stop()
    if (noticeCheck.running) return
    while (pending.length) {
      var next = pending[0]
      pending = pending.slice(1)
      if (stale(next)) continue
      noticeCheck.event = next
      noticeCheck.command = ["python3", localPath("focus-session.py"), "--focused", next.id, next.provider || "claude", next.transcript || ""]
      noticeCheck.running = true
      return
    }
    notice = null
    if (host.view === "feedback" && host.feedbackKind === noticeFeedback) host.dismissFeedback()
  }
  Process {
    id: noticeCheck
    property var event: null
    onExited: function(code) {
      var next = event
      event = null
      if (code === 0 || agentsAddon.stale(next)) { agentsAddon.advanceNotice(); return }
      agentsAddon.notice = next
      agentsAddon.present()
    }
  }
  // The notice is the pill grown, shown through the island's feedback (so it
  // comes up while the island's hidden too); the island's own momentary
  // pills, an open surface, or the screensaver hold it back, and the one
  // waiting keeps its turn.
  readonly property string noticeFeedback: "addon:" + addon.id
  readonly property bool noticeShown: !!notice && host.view === "feedback" && host.feedbackKind === noticeFeedback
  readonly property bool noticeHeld: host.surfaceOpen || host.screensaverActive
    || (host.view === "feedback" && host.feedbackKind !== noticeFeedback)
  function present() {
    if (!notice || noticeHeld) return
    host.showFeedback("", 600000, noticeFeedback)
    noticeTimer.restart()
  }
  onNoticeHeldChanged: {
    if (!notice) return
    if (noticeHeld) noticeTimer.stop()
    else if (stale(notice)) advanceNotice()
    else present()
  }
  Timer {
    id: noticeTimer
    interval: 3000
    // It stays while the pointer's on it.
    onTriggered: if (agentsAddon.hovered) restart(); else agentsAddon.advanceNotice()
  }
  // A click on the notice goes to the session's window.
  function focusNotice() {
    if (!notice || focusProc.running) return
    focusProc.wasDone = false
    focusProc.command = ["python3", localPath("focus-session.py"), notice.id, notice.provider || "claude", notice.transcript || ""]
    focusProc.running = true
    advanceNotice()
  }

  function takeSessions(next) {
    var wasWorking = working
    sessions = next
    announce(next)
    // A turn you stopped isn't a finished one: the pill just goes.
    if (wasWorking && !working && next.length && next[0].state === "done" && !next[0].interrupted) {
      finished = true
      finishedTimer.restart()
    } else if (working) {
      finished = false
      finishedTimer.stop()
    }
  }
  // Waiting on you or just done, a click goes to the session's window
  // (see focus-session.py) instead of the control center; done, the pill
  // then goes too.
  function pillClicked() {
    if (noticeShown) { focusNotice(); return }
    var target = asking || finished ? live : null
    if (!target) { host.view = "controls"; return }
    if (focusProc.running) return
    focusProc.wasDone = !asking
    focusProc.command = ["python3", localPath("focus-session.py"), target.id, target.provider || "claude", target.transcript || ""]
    focusProc.running = true
  }
  Process {
    id: focusProc
    property bool wasDone: false
    onExited: function(code) {
      if (code !== 0) agentsAddon.host.view = "controls"
      else if (wasDone && !agentsAddon.working) {
        agentsAddon.finished = false
        finishedTimer.stop()
      }
    }
  }
  Timer {
    id: finishedTimer
    interval: 4000
    onTriggered: if (agentsAddon.hovered) restart(); else agentsAddon.finished = false
  }

  // The turn's time, by the second while it's on screen; done, it stops
  // where it ended.
  property real now: Date.now()
  Timer {
    interval: 1000
    repeat: true
    running: agentsAddon.pillShown && agentsAddon.working
    triggeredOnStart: true
    onTriggered: agentsAddon.now = Date.now()
  }
  readonly property real turnTime: !live || !live.startedAt ? 0
    : Math.max(0, (live.state === "done" ? live.doneAt : now) - live.startedAt)
  // 0:04, 12:31, 1:02:10
  function timeText(ms) {
    var s = Math.max(0, Math.floor(ms / 1000))
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
    var ss = ("0" + s % 60).slice(-2)
    return h > 0 ? h + ":" + ("0" + m).slice(-2) + ":" + ss : m + ":" + ss
  }

  // Held by the pointer, a finished turn's "Done" stays (see finishedTimer).
  property bool hovered: false
}
