import QtQuick
import Quickshell.Io
import ".."

// The month and the day's events from the ICS calendars set in the addon's
// options, as an island view (see CalendarView), a control center tile (see
// CalendarTile), and a pill 10 minutes before each timed event (see
// CalendarPill). Sync runs in sync.py on a configurable interval (default 15
// minutes), when the calendars change, and when the view opens on a stale cache.
Addon {
  id: calendarAddon
  views: [{ name: "calendar", width: 480, padding: 20, component: calendarView }]
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
    about: "Sync your ICS calendars and how often they refresh.",
    search: "calendar google outlook microsoft ics events sync refresh"
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

  // The calendars' ICS URLs, any whitespace or commas between them; webcal://
  // is fetched over https.
  readonly property var urls: String(addon.option("urls") || "").split(/[\s,]+/)
    .filter(function(url) { return url !== "" })
    .map(function(url) { return url.replace(/^webcal:\/\//i, "https://") })

  readonly property int refreshMinutes: {
    var v = Number(addon.option("refreshMinutes"))
    return v === 5 || v === 15 || v === 30 || v === 60 ? v : 15
  }
  readonly property int refreshMs: refreshMinutes * 60 * 1000
  readonly property int reminderMs: 10 * 60 * 1000

  property bool ready: false

  // "missing" (no source), "loading", "ready", or "offline" (all failed
  // with nothing cached).
  property string status: "loading"
  property var rawEvents: []
  property real fetchedAt: 0
  property var fetchErrors: ({})
  property bool syncing: false
  property bool fetchQueued: false

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

  // ---------- Sync ----------

  onUrlsChanged: if (ready) fetch()
  Component.onCompleted: {
    ready = true
    cacheProc.running = true
    fetch()
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
  function refreshNow() { fetch() }

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
    property var urlsSnapshot: []
    property bool parsedOk: false
    onExited: function(code) {
      calendarAddon.syncing = false
      if (!parsedOk && code !== 0) {
        calendarAddon.status = calendarAddon.rawEvents.length > 0 ? "ready" : "offline"
      }
      if (calendarAddon.fetchQueued || fetcher.urlsSnapshot.join(" ") !== calendarAddon.urls.join(" ")) {
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

  function fetch() {
    if (urls.length === 0) {
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
    fetcher.urlsSnapshot = urls.slice()
    fetcher.command = ["python3", localPath("sync.py"), "fetch", "--ics"].concat(urls)
    fetcher.running = true
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
