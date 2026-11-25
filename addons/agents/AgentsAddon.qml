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
// when none's found. Hovered, it grows into the turn's live steps and detail
// card; when a turn ends or waits on you, it morphs into a notice (AgentNotice).
Addon {
  id: agentsAddon
  pill: Component { AgentsPill { agents: agentsAddon } }
  // In the control center, Normal is the Settings pane as a card (AgentsZone
  // mounts it), XSmall and Small are visuals of their own.
  zone: Component { AgentsZone {} }
  ongoing: working
  // Expanded on hover, it hides the clock and takes the island to itself.
  pillFills: expanded && !noticeShown
  readonly property real inset: 24
  readonly property int rows: 3
  readonly property real rowHeight: 27
  // Grown into steps (see AgentsPill), its height follows its steps.
  property real grownHeight: 173
  // Grown into a notice (see AgentNotice): room for the mascot's tile, the
  // name over what happened, and the badge, with corners concentric with
  // the tile's (its radius plus the inset around it).
  readonly property real noticeHeight: 62
  pillWidth: noticeShown ? 328 : expanded ? 460 : 236
  pillHeight: noticeShown ? noticeHeight : expanded ? grownHeight : restHeight
  pillRadius: noticeShown ? 13 + (noticeHeight - 39) / 2 : expanded ? 32 : 0
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
    search: "agents ai claude code codex gemini antigravity agy usage limits rate session 5-hour five hour weekly week tokens day plan subscription"
  }]

  // Claude's mark reads smaller than Codex's at the same size, so it's drawn larger.
  readonly property var providers: ({
    claude: { id: "claude", name: "Claude Code", glyph: "", glyphSize: 0.7, color: "#d97757", login: "claude auth login" },
    codex: { id: "codex", name: "Codex", glyph: "", glyphSize: 0.6, color: host.theme.system.blue, login: "codex login" },
    agy: { id: "agy", name: "Gemini", glyph: "✦", glyphSize: 0.65, color: "#1a73e8", login: "agy" },
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

  // What the control center's small zones show: the session and weekly
  // limits (null when the agent has none, as All Models), and the tokens a
  // day over the recent days, as the Settings pane's average.
  function limit(pattern) {
    return (record && record.limits || []).filter(function(l) { return pattern.test(l.label) })[0] || null
  }
  readonly property var sessionLimit: limit(/5.?h|session/i)
  readonly property var weeklyLimit: limit(/week|7.?d/i)
  readonly property real averageTokens: {
    var days = record && record.recentDays || []
    return days.length ? days.reduce(function(sum, d) { return sum + (d.messageCount || 0) }, 0) / days.length : 0
  }
  function tokens(n) {
    n = n || 0
    if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
    return String(Math.round(n))
  }
  // Used: green under half, yellow, red from 80% (as AgentsPage's meters).
  function usedColor(p) {
    return p >= 0.8 ? host.theme.system.red : p >= 0.5 ? host.theme.system.yellow : host.theme.system.green
  }

  // Shared clock for usage countdowns across Settings and Control Center zones.
  property real usageNow: Date.now()
  Timer {
    interval: 30000
    repeat: true
    running: agentsAddon.watching
    triggeredOnStart: true
    onTriggered: agentsAddon.usageNow = Date.now()
  }
  function countdown(iso) {
    if (!iso) return ""
    var ms = new Date(iso).getTime() - usageNow
    if (!isFinite(ms)) return ""
    if (ms <= 0) return "now"
    var minutes = Math.floor(ms / 60000), hours = Math.floor(minutes / 60), days = Math.floor(hours / 24)
    if (days > 0) return days + (days === 1 ? " day" : " days") + (hours % 24 ? " " + hours % 24 + " hr" : "")
    if (hours > 0) return hours + " hr " + (minutes % 60) + " min"
    return Math.max(1, minutes) + " min"
  }
  function shortCountdown(iso) {
    if (!iso) return ""
    var ms = new Date(iso).getTime() - usageNow
    if (!isFinite(ms)) return ""
    if (ms <= 0) return "now"
    var minutes = Math.floor(ms / 60000), hours = Math.floor(minutes / 60), days = Math.floor(hours / 24)
    if (days > 0) return days + "d" + (hours % 24 ? " " + hours % 24 + "h" : "")
    if (hours > 0) return hours + "h" + (minutes % 60 ? " " + minutes % 60 + "m" : "")
    return Math.max(1, minutes) + "m"
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
    // fills them in after it (see there). Antigravity's collector only scans
    // ~/.gemini/antigravity-cli, so agy-usage.py merges ~/.gemini/antigravity
    // and ~/.gemini/antigravity-ide transcripts into agy.json.
    // All Models regenerates the subscription agents' records, then merges
    // them with the other models' sessions (all-usage.py).
    update.command = provider.id === "all"
      ? ["bash", "-c", "omarchy-agent-usage-update claude codex agy; python3 \"$1\"; python3 \"$2\"; python3 \"$3\"", "bash",
         agentsAddon.localPath("codex-limits.py"), agentsAddon.localPath("agy-usage.py"), agentsAddon.localPath("all-usage.py")]
      : provider.id === "codex"
      ? ["bash", "-c", "omarchy-agent-usage-update codex; python3 \"$1\"", "bash", agentsAddon.localPath("codex-limits.py")]
      : provider.id === "agy"
      ? ["bash", "-c", "omarchy-agent-usage-update agy; python3 \"$1\"", "bash", agentsAddon.localPath("agy-usage.py")]
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
    var steps = live && live.steps ? live.steps : []
    for (var i = 0; i < steps.length; i++) if (steps[i].status === "running") return steps[i]
    return null
  }
  // Waiting on your answer to a question or its plan.
  readonly property bool asking: !!live && live.state === "asking"
  onAskingChanged: if (asking) presentSteps()

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

  // Each session's last state, to see what changed: a turn that ends, or
  // one that starts waiting on you, is announced by the pill growing into a
  // notice of it (see AgentNotice), which comes up even while the island is
  // hidden (in fullscreen, say). A turn's end shows for a moment; a question
  // stays until it's answered, giving way a moment to any other notice. The
  // first look only learns the states.
  property var lastStates: null
  // What's waiting to be announced, and the one on screen.
  property var pending: []
  property var notice: null
  function announce(next) {
    var before = lastStates
    var states = {}
    next.forEach(function(s) { states[s.id] = s.state })
    lastStates = states
    if (!before) return
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
    // The last one: its content leaves first, then the pill shrinks back.
    if (noticeShown) { noticeLeaving = true; noticeLeave.restart(); return }
    endNotice()
  }
  function endNotice() {
    noticeLeaving = false
    notice = null
    if (host.view === "feedback" && host.feedbackKind === noticeFeedback) host.dismissFeedback()
    // One that came in meanwhile.
    if (pending.length) advanceNotice()
  }
  property bool noticeLeaving: false
  Timer {
    id: noticeLeave
    // As long as AgentNotice's parts take to leave (see PillReveal).
    interval: Math.round(agentsAddon.host.theme.motionDuration("exit") * 4 / 3) + 20
    onTriggered: agentsAddon.endNotice()
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
  readonly property bool noticeWaits: !!notice && notice.noticeKind === "asking"
  onNoticeHeldChanged: {
    if (!notice || noticeLeaving) return
    if (noticeHeld) noticeTimer.stop()
    else if (stale(notice)) advanceNotice()
    else present()
  }
  Timer {
    id: noticeTimer
    interval: 3000
    // It stays while the pointer's on it. A question stays till it's
    // answered (see takeSessions), giving way to the others waiting, then
    // coming back after them.
    onTriggered: {
      if (agentsAddon.hovered) { restart(); return }
      if (agentsAddon.noticeWaits && !agentsAddon.stale(agentsAddon.notice)) {
        if (!agentsAddon.pending.length) { restart(); return }
        agentsAddon.pending = agentsAddon.pending.concat([agentsAddon.notice])
      }
      agentsAddon.advanceNotice()
    }
  }
  // A click on the notice goes to the session's window.
  function focusNotice() {
    if (!notice || focusProc.running) return
    focusProc.command = ["python3", localPath("focus-session.py"), notice.id, notice.provider || "claude", notice.transcript || ""]
    focusProc.running = true
    // A question stays until it's answered.
    if (!noticeWaits) advanceNotice()
  }

  function takeSessions(next) {
    sessions = next
    announce(next)
    // A question answered: its notice goes.
    if (notice && !noticeLeaving && stale(notice)) advanceNotice()
  }
  // Waiting on you, a click goes to the session's window (see
  // focus-session.py) instead of the control center.
  function pillClicked() {
    if (noticeShown) { focusNotice(); return }
    if (!asking) { host.view = "controls"; return }
    if (focusProc.running) return
    focusProc.command = ["python3", localPath("focus-session.py"), live.id, live.provider || "claude", live.transcript || ""]
    focusProc.running = true
  }
  Process {
    id: focusProc
    onExited: function(code) { if (code !== 0) agentsAddon.host.view = "controls" }
  }

  // As Apple's live activities alert: grown by itself for a few seconds
  // when it starts waiting on you, unless the pointer's holding it open.
  // (Not present(), which shows the notice.)
  function presentSteps() {
    if (!expandable) return
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
  readonly property real turnStart: live ? live.startedAt || (live.steps && live.steps.length ? live.steps[0].startedAt : 0) : 0
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

  // Held by the pointer, a notice stays (see noticeTimer) and a working pill
  // expands into its steps once the pointer rests on it.
  property bool hovered: false
  property bool expanded: false
  // Growing into the steps is the "Expanded Live Activity" option, off
  // unless it's turned on.
  readonly property bool expandable: addon.option("expandedPill") === true
  onExpandableChanged: if (!expandable) { openTimer.stop(); presentTimer.stop(); expanded = false }
  onHoveredChanged: {
    if (hovered && expandable && ongoing && !noticeShown) { collapseTimer.stop(); if (!expanded) openTimer.restart() }
    else { openTimer.stop(); collapseTimer.restart() }
  }
  onNoticeShownChanged: if (noticeShown) { openTimer.stop(); presentTimer.stop(); expanded = false }
  onOngoingChanged: if (!ongoing) { presentTimer.stop(); expanded = false }
  onPillShownChanged: if (!pillShown) { openTimer.stop(); collapseTimer.stop(); presentTimer.stop(); expanded = false }
  Timer {
    id: openTimer
    interval: 120
    onTriggered: if (agentsAddon.hovered && agentsAddon.expandable && agentsAddon.ongoing) agentsAddon.expanded = true
  }
  Timer {
    id: collapseTimer
    interval: 450
    onTriggered: agentsAddon.expanded = false
  }
}
