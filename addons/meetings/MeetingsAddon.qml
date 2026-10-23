import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import ".."
import "apps.js" as Apps
import "../../components/IconSource.js" as IconSource

// A call on the island while a meeting app has the mic (see apps.js): the
// call's length and a mic level meter on the resting pill (see CallPill),
// growing on hover into mute, camera, share, and hang-up buttons. They send
// the app's own shortcut to its window (see call.sh), so muting mutes you
// in the meeting; a button whose app has no shortcut for it brings the
// window forward instead. A click beside the buttons opens the control
// center, as on any pill.
Addon {
  id: meetingsAddon
  pill: Component { CallPill { meetings: meetingsAddon } }
  ongoing: inCall
  // Grown, as it starts, and as it ends, it hides the clock and takes the
  // island to itself.
  pillAsks: expanded || intro || ended
  // As the timer's at rest, a little wider once the call passes an hour
  // (1:02:10); grown, room for the app's name over the buttons, inset as
  // far from the bottom as from the sides, with corners concentric with
  // the buttons' (their radius plus that inset).
  readonly property real buttonSize: 48
  readonly property real inset: 18
  // Ended, it draws in a little.
  pillWidth: expanded ? 304 : ended ? (elapsed >= 3600000 ? 240 : 224) : elapsed >= 3600000 ? 262 : 240
  pillHeight: expanded ? restHeight + 4 + buttonSize + inset : restHeight
  pillRadius: expanded ? buttonSize / 2 + inset : 0

  // ---------- Finding the call ----------

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var inStreams: nodes.filter(function(n) {
    return n.isStream && n.type === PwNodeType.AudioInStream
  })
  PwObjectTracker {
    objects: meetingsAddon.source ? meetingsAddon.inStreams.concat([meetingsAddon.source]) : meetingsAddon.inStreams
  }

  // Each app has its own switch, which its site in a browser shares (Teams
  // off is the Teams app and teams.microsoft.com both); the browser counts
  // through its sites.
  function appOn(app) { return !!app.sites || addon.option(app.id) !== false }
  function siteOn(site) { return addon.option(site.id) !== false }
  // The site (of those switched on) a browser's window has open, by its
  // title, or null.
  function siteOpen(app) {
    var windows = ToplevelManager.toplevels.values
    var cls = new RegExp(app.windowClass, "i")
    for (var i = 0; i < windows.length; i++) {
      if (!cls.test(windows[i].appId || "")) continue
      for (var j = 0; j < app.sites.length; j++)
        if (siteOn(app.sites[j]) && new RegExp(app.sites[j].title).test(windows[i].title || "")) return app.sites[j]
    }
    return null
  }

  // The mic streams of the meeting apps that are on. A browser's count while
  // one of its windows shows a meeting site, and then for the rest of the
  // call, so switching tabs doesn't end it.
  readonly property var callStreams: {
    var out = []
    for (var i = 0; i < inStreams.length; i++) {
      // Not until it's bound: its properties come with that.
      if (!inStreams[i].ready) continue
      var props = inStreams[i].properties || {}
      var app = Apps.appFor(props, windowClasses[props["application.process.id"]])
      if (!app || !appOn(app)) continue
      var site = app.sites ? siteOpen(app) : null
      if (app.sites && !site && !(inCall && callApp && callApp.id === app.id)) continue
      out.push({ node: inStreams[i], app: app, site: site })
    }
    return out
  }

  // A stream no app's binary names is looked up once by its process: the
  // class of the window that process or its parent owns (Electron's audio
  // runs in a child of the one with the window), "" when there's none.
  property var windowClasses: ({})
  readonly property var unknownPids: inStreams.filter(function(n) {
    var props = n.ready ? n.properties || {} : {}
    var pid = props["application.process.id"]
    return pid && windowClasses[pid] === undefined && !Apps.appFor(props)
  }).map(function(n) { return n.properties["application.process.id"] })
  onUnknownPidsChanged: lookNext()
  function lookNext() {
    if (!windowLookup.running && unknownPids.length) {
      windowLookup.pid = unknownPids[0]
      windowLookup.running = true
    }
  }
  Process {
    id: windowLookup
    property var pid: 0
    command: ["bash", "-c", "ppid=$(ps -o ppid= -p \"$1\" | tr -d ' '); "
      + "hyprctl clients -j | jq -r --argjson a \"$1\" --argjson b \"${ppid:-0}\" "
      + "'[.[] | select(.pid == $a or .pid == $b) | .class][0] // \"\"'", "_", String(pid)]
    stdout: StdioCollector {
      onStreamFinished: {
        var next = Object.assign({}, meetingsAddon.windowClasses)
        next[windowLookup.pid] = text.trim()
        meetingsAddon.windowClasses = next
      }
    }
    onExited: Qt.callLater(meetingsAddon.lookNext)
  }

  property bool inCall: false
  property var callApp: null
  property var callSite: null
  property real startedAt: 0
  property real now: Date.now()
  readonly property real elapsed: Math.max(0, now - startedAt)

  onCallStreamsChanged: {
    if (callStreams.length === 0) {
      if (inCall && !dropped) {
        now = Date.now()
        dropped = true
        voice = 0
        levels = []
        // Hung up from here: no need to wait.
        if (Date.now() - hungUpAt < 5000) showEnded()
        else endTimer.restart()
      }
      return
    }
    endTimer.stop()
    dropped = false
    // Back while its end is still showing: the mic only changed device, and
    // the call goes on.
    if (ended) {
      endedTimer.stop()
      leaveTimer.stop()
      leaving = false
      ended = false
      hungUpAt = 0
    }
    if (!inCall) {
      callApp = callStreams[0].app
      callSite = null
      startedAt = Date.now()
      now = startedAt
      appMuted = false
      leaving = false
      inCall = true
      intro = true
      introTimer.restart()
    }
    for (var i = 0; i < callStreams.length; i++)
      if (callStreams[i].site && callStreams[i].app.id === callApp.id) callSite = callStreams[i].site
  }
  // As a call starts, the app's icon and name take the clock's place a
  // moment.
  property bool intro: false
  Timer {
    id: introTimer
    interval: 1800
    onTriggered: meetingsAddon.intro = false
  }
  // Apps drop the mic and open it again when its device changes, mostly
  // within a moment: the call ends once it's been gone that long (at once
  // when it was hung up here), its time stopped meanwhile. Then, as
  // Apple's, the phone turns red and hangs up beside the call's length a
  // moment before the pill goes, the call taken up again if the mic's back
  // by then.
  property bool dropped: false
  property bool ended: false
  property real hungUpAt: 0
  Timer {
    id: endTimer
    interval: 700
    onTriggered: if (meetingsAddon.callStreams.length === 0) meetingsAddon.showEnded()
  }
  function showEnded() {
    endTimer.stop()
    ended = true
    expanded = false
    endedTimer.restart()
  }
  Timer {
    id: endedTimer
    interval: 1900
    onTriggered: { meetingsAddon.leaving = true; leaveTimer.restart() }
  }
  // Then its content shrinks away into the island before the pill goes, and
  // stays gone until the next call, so it doesn't come back as it fades.
  property bool leaving: false
  Timer {
    id: leaveTimer
    interval: meetingsAddon.host.theme.motionDuration("collapse")
    onTriggered: meetingsAddon.endCall()
  }
  function endCall() {
    endedTimer.stop()
    leaveTimer.stop()
    introTimer.stop()
    hungUpAt = 0
    intro = false
    dropped = false
    ended = false
    inCall = false
    callApp = null
    callSite = null
    cameraOn = false
  }
  Timer {
    interval: 1000
    repeat: true
    running: meetingsAddon.inCall && !meetingsAddon.dropped
    onTriggered: meetingsAddon.now = Date.now()
  }
  // 0:04, 12:31, 1:02:10
  function timeText(ms) {
    var s = Math.floor(ms / 1000)
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
    var ss = ("0" + s % 60).slice(-2)
    return h > 0 ? h + ":" + ("0" + m).slice(-2) + ":" + ss : m + ":" + ss
  }

  // ---------- Mic, camera, and sharing ----------

  // Muted in the meeting with the app's own shortcut, so the others see it.
  // The app's state isn't readable from outside, so the island keeps its
  // own: each call starts unmuted, and muting in the app's window isn't
  // seen here. The system mic muted (in the control center) counts too.
  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool sourceMuted: !!(source && source.audio && source.audio.muted)
  property bool appMuted: false
  readonly property bool micMuted: appMuted || sourceMuted
  function toggleMic() {
    if (!micMuted) {
      act("mic")
      appMuted = true
      return
    }
    if (appMuted) {
      act("mic")
      appMuted = false
    }
    if (sourceMuted) source.audio.muted = false
  }

  // The camera is on while anything has it open: Chromium-based apps read it
  // themselves, others through PipeWire, which then opens it too. fuser
  // reads every process's open files, so it's only asked while the buttons
  // that show it are on screen.
  property bool cameraOn: false
  Timer {
    interval: 2000
    repeat: true
    triggeredOnStart: true
    running: meetingsAddon.inCall && meetingsAddon.expanded
    onTriggered: if (!cameraProbe.running) cameraProbe.running = true
  }
  Process {
    id: cameraProbe
    command: ["sh", "-c", "fuser -s /dev/video* 2>/dev/null"]
    onExited: function(code) { if (meetingsAddon.inCall) meetingsAddon.cameraOn = code === 0 }
  }

  // Sharing: the Hyprland portal's screencast node exists while it's read.
  readonly property bool sharing: inCall && nodes.some(function(n) {
    return String(n.name || "").indexOf("xdph-streaming-") === 0
  })

  // The meter reads the mic the call's first stream is linked to.
  PwNodeLinkTracker {
    id: callLinks
    node: meetingsAddon.callStreams.length ? meetingsAddon.callStreams[0].node : null
  }
  readonly property var meterNode: {
    var groups = callLinks.linkGroups || []
    return groups.length && groups[0].source ? groups[0].source : source
  }
  readonly property int meterBars: 6
  // Apple's call waveform: every bar follows the voice at once, the middle
  // ones tallest, each wobbling a little on its own. `voice` is the mic's
  // level eased (up quickly, down gently), `levels` each bar's, 0 to 1.
  readonly property var meterEnvelope: [0.55, 0.85, 1, 0.95, 0.75, 0.5]
  property real voice: 0
  property var levels: []
  property var levelTargets: []
  property int meterTick: 0
  PwNodePeakMonitor {
    id: peaks
    node: meetingsAddon.meterNode
    enabled: meetingsAddon.inCall && !meetingsAddon.dropped && meetingsAddon.pillShown
  }
  // The bars ease toward their targets in steps, 25 a second, with no
  // animation of their own (see SoundWave: an animation repaints the island
  // at the display's full refresh rate); each picks a new target every
  // third step. Once they've settled (silence, or muted) nothing changes,
  // so nothing is drawn.
  Timer {
    interval: 40
    repeat: true
    running: peaks.enabled
    onTriggered: {
      var self = meetingsAddon
      var target = self.micMuted ? 0 : Math.min(1, Math.sqrt(peaks.peak) * 1.4)
      self.voice += (target - self.voice) * (target > self.voice ? 0.45 : 0.18)
      if (self.voice < 0.01) self.voice = 0
      if (self.meterTick++ % 3 === 0 || self.levelTargets.length !== self.meterBars) {
        var targets = []
        for (var i = 0; i < self.meterBars; i++)
          targets.push(self.voice * self.meterEnvelope[i] * (0.6 + 0.4 * Math.random()))
        self.levelTargets = targets
      }
      var next = [], moved = self.levels.length !== self.meterBars
      for (var j = 0; j < self.meterBars; j++) {
        var from = self.levels[j] || 0, to = self.levelTargets[j]
        var level = Math.abs(to - from) < 0.01 ? to : from + (to - from) * 0.4
        if (level !== from) moved = true
        next.push(level)
      }
      if (moved) self.levels = next
    }
  }

  // ---------- Hover and actions ----------

  property bool hovered: false
  property bool expanded: false
  // It opens once the pointer rests on it, so passing over doesn't, and
  // closes a moment after it leaves.
  onHoveredChanged: {
    if (hovered && inCall && !ended) { collapseTimer.stop(); if (!expanded) openTimer.restart() }
    else { openTimer.stop(); collapseTimer.restart() }
  }
  Timer {
    id: openTimer
    interval: 120
    onTriggered: if (meetingsAddon.hovered && meetingsAddon.inCall && !meetingsAddon.ended) meetingsAddon.expanded = true
  }
  onPillShownChanged: if (!pillShown) { openTimer.stop(); collapseTimer.stop(); expanded = false }
  Timer {
    id: collapseTimer
    interval: 450
    onTriggered: meetingsAddon.expanded = false
  }

  readonly property string callName: callSite ? callSite.name : callApp ? callApp.name : ""
  // The app's icon: a browser site's own, if one's installed, else that of
  // the app's window (the browser's, for a site), else of its binaries, by
  // desktop entry or icon theme name; "" when there's none.
  readonly property string callIcon: {
    if (!callApp) return ""
    var classes = [], windows = ToplevelManager.toplevels.values
    var cls = new RegExp(callApp.windowClass, "i")
    for (var w = 0; w < windows.length; w++)
      if (cls.test(windows[w].appId || "")) { classes.push(windows[w].appId); break }
    var names = (callSite && callSite.icons || []).concat(classes, callApp.binaries)
    for (var i = 0; i < names.length; i++) {
      var entry = DesktopEntries.heuristicLookup(names[i])
      var path = IconSource.source(entry && entry.icon ? entry.icon : names[i])
      if (path) return path
    }
    return ""
  }
  readonly property var keys: callSite ? callSite.keys : callApp ? callApp.keys : {}
  function hasKey(kind) { return !!keys[kind] }
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("call.sh")).replace("file://", ""))
  function run(args) {
    if (!callApp) return
    Quickshell.execDetached(["bash", helper, callApp.windowClass, callSite ? callSite.title : ""].concat(args))
  }
  // mic, camera, share, or hangup: the app's shortcut, or its window. Share's
  // opens the app's share menu, so its window comes forward with it.
  function act(kind) {
    if (kind === "hangup") hungUpAt = Date.now()
    var key = keys[kind]
    run(key ? [kind === "share" ? "focus-key" : "key", key[0], key[1]] : ["focus"])
  }
}
