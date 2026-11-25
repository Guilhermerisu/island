import QtQuick
import Quickshell.Io
import ".."

// The month and the day's events from Google Calendar, Outlook, or ICS
// feeds, as an island view (see CalendarView), a control center tile (see
// CalendarTile), and a pill 10 minutes before each timed event (see
// CalendarPill). Sync runs in sync.py on a configurable interval (default 2
// minutes), when sources change, and when the view opens on a stale cache.
Addon {
  id: calendarAddon
  views: [{ name: "calendar", width: 480, padding: 22, component: calendarView }]
  tiles: [{ key: "today", title: "Calendar", component: calendarTile }]
  pill: Component { CalendarPill { calendar: calendarAddon } }
  pillWidth: 340
  pillHeight: restHeight + 12
  function pillClicked() { selectToday(); host.view = "calendar" }

  settingsPages: [{
    title: "Calendar",
    icon: "󰃭",
    color: "#f2564f",
    iconLayers: [],
    source: Qt.resolvedUrl("CalendarPage.qml"),
    properties: { calendar: calendarAddon },
    about: "Connect Google Calendar, Outlook, or ICS feeds.",
    search: "calendar google outlook microsoft oauth ics events sync refresh"
  }]

  Component {
    id: calendarView
    CalendarView { calendar: calendarAddon; active: calendarAddon.host.view === "calendar" }
  }
  Component {
    id: calendarTile
    CalendarTile { calendar: calendarAddon; center: parent.center }
  }

  function localPath(file) { return decodeURIComponent(String(Qt.resolvedUrl(file)).replace("file://", "")) }

  // ICS fallback URLs, any whitespace or commas between them; webcal:// is
  // fetched over https.
  readonly property var icsUrls: String(addon.option("urls") || "").split(/[\s,]+/)
    .filter(function(url) { return url !== "" })
    .map(function(url) { return url.replace(/^webcal:\/\//i, "https://") })

  readonly property int refreshMinutes: {
    var v = Number(addon.option("refreshMinutes"))
    return v === 1 || v === 2 || v === 5 || v === 15 ? v : 2
  }
  readonly property int refreshMs: refreshMinutes * 60 * 1000
  readonly property int reminderMs: 10 * 60 * 1000

  property var providersStatus: ({
    google: { connected: false, email: "", clientId: "", hasSecret: false, calendars: [], error: "" },
    outlook: { connected: false, email: "", clientId: "", tenant: "common", calendars: [], error: "" },
    fetchedAt: 0
  })
  property bool statusLoaded: false
  property bool ready: false

  // Combined list of configured sources so CalendarTile's `urls.length === 0`
  // contract accurately reflects OAuth providers as well as ICS feeds.
  readonly property var urls: {
    var list = icsUrls.slice()
    if (providersStatus.google && providersStatus.google.connected) list.push("google")
    if (providersStatus.outlook && providersStatus.outlook.connected) list.push("outlook")
    return list
  }

  // "missing" (no source), "loading", "ready", or "offline" (all failed
  // with nothing cached).
  property string status: "loading"
  property var rawEvents: []
  property real fetchedAt: 0
  property var fetchErrors: ({})
  property bool syncing: false
  property bool fetchQueued: false
  readonly property bool authBusy: authProc.running
  property string authProvider: ""
  property string authError: ""

  // Every calendar's events: { title, start, end (ms, end exclusive),
  // allDay, color, location, meetingUrl, source }.
  readonly property var events: rawEvents.map(function(e) {
    return Object.assign({}, e, { color: colorFor(e) })
  })

  // Today, and the day the view shows (both at midnight) and its month.
  readonly property date today: {
    var now = host.clockDate
    return new Date(now.getFullYear(), now.getMonth(), now.getDate())
  }
  property date selected: today
  property int shownYear: today.getFullYear()
  property int shownMonth: today.getMonth()
  property date lastToday: today
  // Past midnight, a view left on the old today follows to the new one.
  onTodayChanged: {
    if (sameDay(selected, lastToday)) selectToday()
    lastToday = today
  }
  function selectToday() { select(today) }
  function select(day) {
    selected = day
    shownYear = day.getFullYear()
    shownMonth = day.getMonth()
  }
  function shiftDay(by) {
    select(new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + by))
  }
  function shiftMonth(by) {
    var first = new Date(shownYear, shownMonth + by, 1)
    shownYear = first.getFullYear()
    shownMonth = first.getMonth()
  }
  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  // The day's events: all-day ones first, then by start.
  function eventsOn(day) {
    var from = day.getTime()
    var to = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1).getTime()
    return events.filter(function(e) {
      return e.start < to && (e.end > from || (e.end === e.start && e.start >= from))
    }).sort(function(a, b) {
      if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
      return a.start - b.start || a.title.localeCompare(b.title)
    })
  }
  // Today's next timed event not yet over, or null.
  readonly property var nextToday: {
    var now = host.clockDate.getTime()
    var left = eventsOn(today).filter(function(e) { return !e.allDay && e.end > now })
    return left[0] || null
  }

  // "15:00", or "3:00 PM" without the 24-hour clock.
  function timeText(ms) {
    var d = new Date(ms)
    var h = d.getHours(), m = (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
    if (host.settings.clock24h) return (h < 10 ? "0" : "") + h + ":" + m
    return ((h + 11) % 12 + 1) + ":" + m + (h < 12 ? " AM" : " PM")
  }
  function spanText(event) {
    if (event.allDay) return "All day"
    if (event.end <= event.start) return timeText(event.start)
    return timeText(event.start) + " – " + timeText(event.end)
  }

  // Each event's colour: its calendar/event colour if valid, or else one of
  // the theme's colours picked deterministically from its title.
  property var themeColors: ({})
  function colorFor(event) {
    var c = event.color || event.hint || ""
    if (c) return Qt.lighter(c, 1)
    var names = ["accent", "red", "blue", "green", "yellow", "magenta", "orange"]
    var hash = 0
    for (var i = 0; i < event.title.length; i++) hash = (hash * 31 + event.title.charCodeAt(i)) | 0
    var hex = themeColors[names[Math.abs(hash) % names.length]]
    return hex ? Qt.lighter(hex, 1) : host.theme.accent
  }
  FileView {
    id: themeColorsFile
    path: calendarAddon.host.theme.home + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false
    onLoaded: {
      var found = {}
      text().split("\n").forEach(function(line) {
        var m = line.match(/^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/)
        if (m) found[m[1]] = m[2]
      })
      calendarAddon.themeColors = found
    }
  }
  Connections {
    target: calendarAddon.host.theme
    function onNameChanged() { themeColorsFile.reload() }
  }

  // ---------- Sync & OAuth2 ----------

  onIcsUrlsChanged: if (ready) fetch()
  Component.onCompleted: {
    ready = true
    cacheProc.running = true
    statusProc.running = true
  }
  Timer {
    interval: calendarAddon.refreshMs
    repeat: true
    running: calendarAddon.urls.length > 0
    onTriggered: calendarAddon.fetch()
  }
  function viewOpened() {
    selectToday()
    if (urls.length > 0 && Date.now() - fetchedAt > Math.max(30000, refreshMs)) fetch()
  }
  function retry() { refreshNow() }
  function refreshNow() {
    if (!statusLoaded && !statusProc.running) statusProc.running = true
    fetch(true)
  }

  Process {
    id: statusProc
    command: ["python3", calendarAddon.localPath("sync.py"), "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          calendarAddon.providersStatus = JSON.parse(text)
          calendarAddon.statusLoaded = true
        } catch (e) {}
      }
    }
    onExited: {
      if (calendarAddon.urls.length === 0) {
        calendarAddon.status = "missing"
        calendarAddon.rawEvents = []
        calendarAddon.fetchErrors = ({})
      } else {
        calendarAddon.fetch()
      }
    }
  }

  Process {
    id: cacheProc
    command: ["python3", calendarAddon.localPath("sync.py"), "cache"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (calendarAddon.fetchedAt > 0) return
        try {
          var data = JSON.parse(text)
          if (data.events && data.events.length > 0) {
            calendarAddon.rawEvents = data.events
            calendarAddon.fetchedAt = data.fetchedAt || 0
            calendarAddon.fetchErrors = data.errors || ({})
            calendarAddon.status = "ready"
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: fetcher
    property var icsSnapshot: []
    property bool parsedOk: false
    onExited: function(code) {
      calendarAddon.syncing = false
      if (!parsedOk && code !== 0) {
        calendarAddon.status = calendarAddon.rawEvents.length > 0 ? "ready" : "offline"
      }
      if (calendarAddon.fetchQueued || fetcher.icsSnapshot.join(" ") !== calendarAddon.icsUrls.join(" ")) {
        calendarAddon.fetchQueued = false
        calendarAddon.fetch()
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          fetcher.parsedOk = true
          calendarAddon.rawEvents = data.events || []
          if (data.fetchedAt) calendarAddon.fetchedAt = data.fetchedAt
          calendarAddon.fetchErrors = data.errors || ({})
          calendarAddon.status = data.status || (calendarAddon.rawEvents.length > 0 ? "ready" : "missing")
        } catch (e) {
          fetcher.parsedOk = false
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("calendar sync:", text.trim())
    }
  }

  function fetch(force) {
    if (statusLoaded && urls.length === 0 && !force) {
      status = "missing"
      rawEvents = []
      fetchErrors = ({})
      return
    }
    if (fetcher.running) {
      fetchQueued = true
      return
    }
    if (status !== "ready") status = "loading"
    syncing = true
    fetcher.parsedOk = false
    fetcher.icsSnapshot = icsUrls.slice()
    var cmd = ["python3", localPath("sync.py"), "fetch"]
    if (icsUrls.length > 0) cmd = cmd.concat(["--ics"]).concat(icsUrls)
    fetcher.command = cmd
    fetcher.running = true
  }

  Process {
    id: authProc
    property bool parsedOk: false
    property string errText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          calendarAddon.providersStatus = JSON.parse(text)
          authProc.parsedOk = true
        } catch (e) {
          authProc.parsedOk = false
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: authProc.errText = text.trim()
    }
    onExited: function(code) {
      var provider = calendarAddon.authProvider
      calendarAddon.authProvider = ""
      if (code === 0 && authProc.parsedOk) {
        calendarAddon.authError = ""
        calendarAddon.statusLoaded = true
        calendarAddon.fetch(true)
      } else {
        calendarAddon.authError = (provider ? provider + ": " : "") + (authProc.errText || "Authentication failed")
      }
    }
  }

  function connectGoogle(clientId, clientSecret) {
    if (authProc.running) return
    var id = String(clientId || "").trim()
    var secret = String(clientSecret || "").trim()
    if (!id) { authError = "google: Client ID is required"; return }
    authError = ""
    authProvider = "google"
    authProc.parsedOk = false
    authProc.errText = ""
    var cmd = ["python3", localPath("sync.py"), "auth", "google", "--client-id", id]
    if (secret !== "") cmd = cmd.concat(["--client-secret", secret])
    authProc.command = cmd
    authProc.running = true
  }

  function connectOutlook(clientId, tenant) {
    if (authProc.running) return
    var id = String(clientId || "").trim()
    var t = String(tenant || "").trim() || "common"
    if (!id) { authError = "outlook: Client ID is required"; return }
    authError = ""
    authProvider = "outlook"
    authProc.parsedOk = false
    authProc.errText = ""
    authProc.command = ["python3", localPath("sync.py"), "auth", "outlook", "--client-id", id, "--tenant", t]
    authProc.running = true
  }

  property var queuedAction: null
  Process {
    id: actionProc
    property bool parsedOk: false
    property string errText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          calendarAddon.providersStatus = JSON.parse(text)
          actionProc.parsedOk = true
        } catch (e) {
          actionProc.parsedOk = false
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: actionProc.errText = text.trim()
    }
    onExited: function(code) {
      if (code !== 0 && actionProc.errText) calendarAddon.authError = actionProc.errText
      else if (code === 0 && actionProc.parsedOk) {
        calendarAddon.authError = ""
        calendarAddon.fetch(true)
      }
      if (calendarAddon.queuedAction) {
        var next = calendarAddon.queuedAction
        calendarAddon.queuedAction = null
        actionProc.parsedOk = false
        actionProc.errText = ""
        actionProc.command = next
        actionProc.running = true
      }
    }
  }

  function runAction(cmd) {
    if (actionProc.running) {
      queuedAction = cmd
      return
    }
    actionProc.parsedOk = false
    actionProc.errText = ""
    actionProc.command = cmd
    actionProc.running = true
  }

  function disconnectProvider(provider) {
    if (provider !== "google" && provider !== "outlook") return
    runAction(["python3", localPath("sync.py"), "disconnect", provider])
  }

  function setCalendarSelected(provider, calendarId, selected) {
    var entry = (providersStatus || {})[provider]
    if (!entry || !entry.calendars) return
    var nextCalendars = entry.calendars.map(function(cal) {
      return cal.id === calendarId ? Object.assign({}, cal, { selected: !!selected }) : cal
    })
    var ids = nextCalendars.filter(function(cal) { return cal.selected }).map(function(cal) { return cal.id })
    // Optimistic update so rapid switches reflect immediately in the UI.
    var nextStatus = Object.assign({}, providersStatus)
    nextStatus[provider] = Object.assign({}, entry, { calendars: nextCalendars })
    providersStatus = nextStatus
    runAction(["python3", localPath("sync.py"), "select", provider, "--ids", ids.join(",")])
  }

  Process {
    id: meetingProc
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("calendar openMeeting:", text.trim())
    }
  }
  function openMeeting(url) {
    var clean = String(url || "").trim()
    if (!/^https?:\/\//i.test(clean)) return
    if (meetingProc.running) return
    meetingProc.command = ["xdg-open", clean]
    meetingProc.running = true
  }

  // ---------- Reminders ----------

  // The event the pill is about, and those already shown, by calendar
  // colour, title, and start. While another surface is open the pill can't
  // show, so it's tried again on the next tick, until the event starts.
  property var reminder: null
  property var reminded: ({})
  Timer {
    interval: 20 * 1000
    repeat: true
    running: calendarAddon.events.length > 0
    triggeredOnStart: true
    onTriggered: calendarAddon.checkReminders()
  }
  function checkReminders() {
    var now = Date.now()
    for (var i = 0; i < events.length; i++) {
      var e = events[i]
      if (e.allDay || e.start <= now || e.start - now > reminderMs) continue
      var key = e.color + "|" + e.title + "|" + e.start
      if (reminded[key] || host.surfaceOpen) continue
      var next = Object.assign({}, reminded)
      next[key] = true
      reminded = next
      reminder = e
      host.showFeedback("", 8000, "addon:" + addon.id)
      return
    }
  }
}
