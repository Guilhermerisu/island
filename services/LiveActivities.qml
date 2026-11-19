import QtQuick

Item {
  id: live
  required property var host
  readonly property var media: host.nowPlaying
  readonly property var timer: host.addons.root("timer")
  readonly property var pomodoro: host.barWidgets.widget("pomodoro-omarchy")
  readonly property var meetings: host.addons.root("meetings")
  readonly property var recorder: host.recorder
  readonly property var downloads: host.downloads
  readonly property var packages: host.packages

  readonly property string mediaKey: media.player && (media.playing || media.title)
    ? "media:" + JSON.stringify([media.player.dbusName || "", media.title, media.artist]) : ""
  readonly property var entries: {
    var result = host.agentSessions.map(function(s) {
      return {
        key: agentKey(s), kind: "agent", label: "Claude Code", session: s,
        glyph: s.state === "done" ? "󰄬" : s.state === "asking" ? "󰋗" : "",
        tint: s.state === "asking" ? host.theme.system.orange : "#d97757",
        detail: s.state === "done" ? "Done" : s.state === "asking" ? "Waiting for input"
          : s.state === "tool" ? "Running a command" : "Working",
        tail: function(now) { return elapsed((s.doneAt || now) - s.startedAt) }
      }
    })
    if (mediaKey) result.push({
      key: mediaKey, kind: "media", label: media.title || "Media",
      detail: (media.playing ? "Playing" : "Paused")
        + (media.artist ? " · " + media.artist : ""),
      art: media.art, glyph: "󰝚", tint: media.tint, open: function() { host.view = "player" }
    })
    if (timer && timer.phase !== "idle") result.push({
      key: "timer", kind: "timer", label: "Timer", glyph: "󰔛", tint: "#ff9f0a",
      detail: timer.phase === "paused" ? "Paused" : "Time remaining",
      tail: function() { return timer ? timer.timeText(timer.remaining) : "" },
      open: function() { host.view = "timer" }
    })
    if (pomodoro && pomodoro.isSessionActive) result.push({
      key: "pomodoro", kind: "pomodoro", label: "Pomodoro", glyph: "󰔟", tint: "#ff6961",
      detail: pomodoro.paused ? "Paused"
        : pomodoro.phase === "break" ? "Break" : "Focus",
      tail: function() { return pomodoro ? pomodoro.formattedTime : "" },
      open: function() { host.summonBarWidget("pomodoro-omarchy") }
    })
    if (meetings && meetings.inCall) result.push({
      key: "meetings", kind: "meetings", label: "Call", glyph: "󰏲", tint: "#30d158",
      tail: function() { return meetings ? elapsed(meetings.elapsed) : "" }
    })
    if (host.settings.screenRecordingActivity && recorder.active) result.push({
      key: "recording", kind: "recording", label: "Screen recording",
      glyph: "󰑊", tint: "#ff453a", tail: function() { return elapsed(recorder.elapsed) }
    })
    if (downloads.active || downloads.finishedName) result.push({
      key: "downloads", kind: "downloads", label: downloads.finishedName || "Downloads",
      detail: downloads.finishedName ? "Download complete" : "",
      glyph: "󰇚", tint: "#64d2ff",
      tail: function() { return downloads.sized ? Math.floor(downloads.progress * 100) + "%" : "" },
      open: function() { host.openDownloads() }
    })
    if (packages.active || packages.finishedTitle) result.push({
      key: "updates", kind: "updates", label: "Updates",
      detail: packages.finishedTitle ? packages.finishedTitle : "",
      glyph: "󰚰", tint: "#0a84ff",
      tail: function() { return packages.status }
    })
    return result
  }

  property var hiddenKeys: []
  readonly property var visibleEntries: entries.filter(function(entry) { return !isHidden(entry.key) })
  readonly property var hiddenEntries: entries.filter(function(entry) { return isHidden(entry.key) })
  readonly property var byKey: {
    var map = {}
    for (var i = 0; i < entries.length; i++) map[entries[i].key] = entries[i]
    return map
  }
  function isHidden(key) { return hiddenKeys.indexOf(key) !== -1 }
  function setHidden(key, hidden) {
    if (hidden === isHidden(key)) return
    hiddenKeys = hidden ? hiddenKeys.concat([key]) : hiddenKeys.filter(function(id) { return id !== key })

  }
  // A new activity comes back by itself. Defer pruning until transient
  // changes in player metadata and the other activity sources have settled.
  onEntriesChanged: Qt.callLater(pruneHidden)
  function pruneHidden() {
    var next = hiddenKeys.filter(function(key) {
      return entries.some(function(entry) { return entry.key === key })
    })
    if (next.length !== hiddenKeys.length) hiddenKeys = next
  }

  function agentKey(s) { return "agent:" + s.id + ":" + s.startedAt }
  function elapsed(ms) {
    var seconds = Math.floor(Math.max(0, ms) / 1000)
    var hours = Math.floor(seconds / 3600)
    var minutes = Math.floor(seconds % 3600 / 60)
    return (hours ? hours + ":" + ("0" + minutes).slice(-2) : minutes) + ":" + ("0" + seconds % 60).slice(-2)
  }

}
