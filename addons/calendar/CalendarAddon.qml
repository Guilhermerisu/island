import QtQuick
import Quickshell.Io
import ".."

// The month and the day's events from the ICS calendars set in the addon's
// options, as an island view (see CalendarView), a control center tile (see
// CalendarTile), and a pill 10 minutes before each timed event (see
// CalendarPill). The calendars are fetched every 30 minutes, again when
// their list changes, and when the view opens on a reading older than that.
// Repeating events are expanded from their rules (see repeats).
Addon {
  id: calendarAddon
  views: [{ name: "calendar", width: 480, padding: 22, component: calendarView }]
  tiles: [{ key: "today", title: "Calendar", component: calendarTile }]
  pill: Component { CalendarPill { calendar: calendarAddon } }
  pillWidth: 340
  pillHeight: host.settings.notch ? 52 : 56
  function pillClicked() { selectToday(); host.view = "calendar" }

  Component {
    id: calendarView
    CalendarView { calendar: calendarAddon; active: calendarAddon.host.view === "calendar" }
  }
  Component {
    id: calendarTile
    CalendarTile { calendar: calendarAddon; center: parent.center }
  }

  // The calendars' URLs, any whitespace or commas between them; webcal://
  // is fetched over https.
  readonly property var urls: String(addon.option("urls") || "").split(/[\s,]+/)
    .filter(function(url) { return url !== "" })
    .map(function(url) { return url.replace(/^webcal:\/\//i, "https://") })
  readonly property int refreshMs: 30 * 60 * 1000
  readonly property int reminderMs: 10 * 60 * 1000

  // "missing" (no calendar), "loading", "ready", or "offline" (none of them
  // could be read, and nothing is kept from before).
  property string status: urls.length === 0 ? "missing" : "loading"
  // Each calendar's last good reading, by URL, kept when a fetch fails.
  property var read: ({})
  property real fetchedAt: 0
  // Every calendar's events: { title, start, end (ms, end exclusive),
  // allDay, color }.
  readonly property var events: {
    var all = []
    for (var i = 0; i < urls.length; i++) {
      var own = read[urls[i]] || []
      for (var j = 0; j < own.length; j++) all.push(Object.assign({ color: colorFor(own[j]) }, own[j]))
    }
    return all
  }

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

  // Each event's colour: its own (COLOR) if it has one, or else one of the
  // accent and the theme's own colours, picked by its title, so a repeating
  // event keeps its colour.
  property var themeColors: ({})
  function colorFor(event) {
    if (event.hint) return Qt.lighter(event.hint, 1)
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

  // ---------- Fetching ----------

  onUrlsChanged: fetch()
  Component.onCompleted: fetch()
  Timer {
    interval: calendarAddon.refreshMs
    repeat: true
    running: calendarAddon.urls.length > 0
    onTriggered: calendarAddon.fetch()
  }
  function viewOpened() {
    selectToday()
    if (urls.length > 0 && Date.now() - fetchedAt > refreshMs) fetch()
  }
  function retry() { fetch() }

  // Every calendar in one go, each one's text after a "\x1e<index>" line and
  // followed by "\x1f<curl's exit code>". An answer for a list since changed
  // is dropped, and the fetch made again once it exits.
  Process {
    id: fetcher
    property var urls: []
    onExited: if (fetcher.urls.join(" ") !== calendarAddon.urls.join(" ")) calendarAddon.fetch()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (fetcher.urls.join(" ") !== calendarAddon.urls.join(" ")) return
        var next = {}, good = 0
        text.split("\x1e").forEach(function(part) {
          var m = part.match(/^(\d+)\n([\s\S]*)\x1f(\d+)\n?$/)
          if (!m) return
          var url = fetcher.urls[Number(m[1])]
          if (m[3] === "0" && /BEGIN:VCALENDAR/.test(m[2])) {
            next[url] = calendarAddon.parse(m[2])
            good++
          } else if (calendarAddon.read[url]) {
            next[url] = calendarAddon.read[url]
          }
        })
        calendarAddon.read = next
        if (good > 0) calendarAddon.fetchedAt = Date.now()
        calendarAddon.status = good > 0 || Object.keys(next).length > 0 ? "ready" : "offline"
      }
    }
  }
  function fetch() {
    if (urls.length === 0) { status = "missing"; read = {}; return }
    if (fetcher.running) return
    if (status !== "ready") status = "loading"
    fetcher.urls = urls
    fetcher.command = ["bash", "-c",
      'i=0; for u in "$@"; do printf "\\036%d\\n" "$i"; curl -sfL --max-time 15 "$u"; printf "\\037%d\\n" "$?"; i=$((i+1)); done',
      "calendar"].concat(urls)
    fetcher.running = true
  }

  // ---------- ICS ----------

  // The calendar's events, a repeating one's occurrences from a year back to
  // two years ahead. Times in UTC ("…Z") are converted; any other is read as
  // local time, its TZID not looked at.
  readonly property int yearMs: 366 * 24 * 3600 * 1000
  function parse(ics) {
    var lines = ics.replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
    var found = [], event = null
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line === "BEGIN:VEVENT") { event = { EXDATE: [] }; continue }
      if (line === "END:VEVENT") { if (event) found.push(event); event = null; continue }
      if (!event) continue
      var colon = line.indexOf(":")
      if (colon < 0) continue
      var head = line.slice(0, colon).split(";")
      var name = head[0].toUpperCase()
      var prop = { value: line.slice(colon + 1), params: head.slice(1).join(";").toUpperCase() }
      // Each EXDATE line can list several dates.
      if (name === "EXDATE") prop.value.split(",").forEach(function(value) {
        event.EXDATE.push({ value: value, params: prop.params })
      })
      else if (event[name] === undefined) event[name] = prop
    }

    // A moved or cancelled occurrence comes as its own event, naming the
    // one it replaces by UID and RECURRENCE-ID.
    var replaced = {}
    found.forEach(function(e) {
      var id = e["RECURRENCE-ID"] && icsDate(e["RECURRENCE-ID"])
      if (id && e.UID) replaced[e.UID.value + "|" + id.ms] = true
    })
    var from = Date.now() - yearMs, to = Date.now() + 2 * yearMs
    var events = []
    found.forEach(function(e) {
      var one = finish(e)
      if (!one) return
      if (!e.RRULE) {
        if (one.end >= from) events.push(one)
        return
      }
      var skip = {}
      e.EXDATE.forEach(function(prop) { var d = icsDate(prop); if (d) skip[d.ms] = true })
      var uid = e.UID ? e.UID.value : ""
      var length = one.end - one.start
      repeats(e.RRULE.value, one.start, to).forEach(function(start) {
        if (skip[start] || replaced[uid + "|" + start] || start + length < from) return
        events.push({ title: one.title, start: start, end: start + length, allDay: one.allDay, hint: one.hint })
      })
    })
    return events
  }
  function finish(event) {
    if (!event.DTSTART) return null
    if (event.STATUS && event.STATUS.value.toUpperCase() === "CANCELLED") return null
    var start = icsDate(event.DTSTART)
    if (!start) return null
    var end = event.DTEND ? icsDate(event.DTEND) : null
    if (!end && event.DURATION) end = { ms: start.ms + durationMs(event.DURATION.value), allDay: start.allDay }
    if (!end) {
      var s = new Date(start.ms)
      end = { ms: start.allDay ? new Date(s.getFullYear(), s.getMonth(), s.getDate() + 1).getTime() : start.ms }
    }
    return {
      title: plainText((event.SUMMARY || { value: "" }).value) || "Untitled",
      start: start.ms,
      end: Math.max(end.ms, start.ms),
      allDay: start.allDay,
      hint: event.COLOR ? event.COLOR.value.trim() : ""
    }
  }

  // The starts (ms) of a rule's occurrences up to `to`, from the first at
  // `first`: FREQ, INTERVAL, COUNT, UNTIL, BYDAY ("MO", "2TU", "-1FR"),
  // BYMONTHDAY, BYMONTH, and BYSETPOS. Each is at the first's time of day,
  // weeks starting on Monday.
  function repeats(text, first, to) {
    var rule = {}
    text.split(";").forEach(function(part) {
      var kv = part.split("=")
      if (kv.length === 2) rule[kv[0].toUpperCase()] = kv[1].toUpperCase()
    })
    var freq = rule.FREQ
    if (["DAILY", "WEEKLY", "MONTHLY", "YEARLY"].indexOf(freq) < 0) return [first]
    var every = Math.max(1, Number(rule.INTERVAL) || 1)
    var count = Number(rule.COUNT) || 0
    var until = to
    if (rule.UNTIL) {
      var u = icsDate({ value: rule.UNTIL })
      // A day's UNTIL takes in the whole of it.
      if (u) until = Math.min(to, u.allDay ? u.ms + 24 * 3600 * 1000 - 1 : u.ms)
    }
    var codes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
    var byDay = rule.BYDAY ? rule.BYDAY.split(",").map(function(d) {
      var m = d.match(/^([+-]?\d+)?([A-Z]{2})$/)
      return m ? { n: Number(m[1] || 0), day: codes.indexOf(m[2]) } : null
    }).filter(function(d) { return d && d.day >= 0 }) : []
    var byMonthDay = rule.BYMONTHDAY ? rule.BYMONTHDAY.split(",").map(Number) : []
    var byMonth = rule.BYMONTH ? rule.BYMONTH.split(",").map(function(m) { return Number(m) - 1 }) : []
    var setPos = rule.BYSETPOS ? rule.BYSETPOS.split(",").map(Number) : []

    var s = new Date(first)
    var at = function(y, mo, d) { return new Date(y, mo, d, s.getHours(), s.getMinutes(), s.getSeconds()) }
    var daysIn = function(y, mo) { return new Date(y, mo + 1, 0).getDate() }
    // A month's days matching BYMONTHDAY and BYDAY ("2TU" the second
    // Tuesday, "-1FR" the last Friday), or `fallback` without either.
    var monthDays = function(y, mo, fallback) {
      var length = daysIn(y, mo), days = []
      if (byMonthDay.length) {
        byMonthDay.forEach(function(d) {
          var day = d < 0 ? length + d + 1 : d
          if (day >= 1 && day <= length) days.push(day)
        })
        if (byDay.length) days = days.filter(function(day) {
          var wd = new Date(y, mo, day).getDay()
          return byDay.some(function(b) { return b.day === wd })
        })
      } else if (byDay.length) {
        byDay.forEach(function(b) {
          var all = []
          for (var day = 1; day <= length; day++) if (new Date(y, mo, day).getDay() === b.day) all.push(day)
          if (b.n === 0) days = days.concat(all)
          else { var pick = all[b.n > 0 ? b.n - 1 : all.length + b.n]; if (pick) days.push(pick) }
        })
      } else if (fallback <= length) {
        days.push(fallback)
      }
      return days.map(function(day) { return at(y, mo, day) })
    }

    var starts = [], made = 0
    var monday = new Date(s.getFullYear(), s.getMonth(), s.getDate() - (s.getDay() + 6) % 7)
    for (var p = 0; p < 10000; p++) {
      var period = []
      if (freq === "DAILY") {
        period = [at(s.getFullYear(), s.getMonth(), s.getDate() + p * every)]
        if (byDay.length) period = period.filter(function(d) { return byDay.some(function(b) { return b.day === d.getDay() }) })
        if (byMonthDay.length) period = period.filter(function(d) {
          var length = daysIn(d.getFullYear(), d.getMonth())
          return byMonthDay.some(function(md) { return (md < 0 ? length + md + 1 : md) === d.getDate() })
        })
      } else if (freq === "WEEKLY") {
        var days = byDay.length ? byDay.map(function(b) { return b.day }) : [s.getDay()]
        for (var i = 0; i < 7; i++) {
          var d = at(monday.getFullYear(), monday.getMonth(), monday.getDate() + p * every * 7 + i)
          if (days.indexOf(d.getDay()) >= 0) period.push(d)
        }
      } else if (freq === "MONTHLY") {
        var month = new Date(s.getFullYear(), s.getMonth() + p * every, 1)
        period = monthDays(month.getFullYear(), month.getMonth(), s.getDate())
      } else {
        var year = s.getFullYear() + p * every
        var months = byMonth.length ? byMonth : [s.getMonth()]
        months.forEach(function(mo) { period = period.concat(monthDays(year, mo, s.getDate())) })
      }
      if (byMonth.length && freq !== "YEARLY")
        period = period.filter(function(d) { return byMonth.indexOf(d.getMonth()) >= 0 })
      period.sort(function(a, b) { return a - b })
      if (setPos.length) {
        var kept = period
        period = setPos.map(function(n) { return kept[n > 0 ? n - 1 : kept.length + n] }).filter(function(d) { return d })
        period.sort(function(a, b) { return a - b })
      }

      var periodStart = period.length ? period[0].getTime() : 0
      for (var j = 0; j < period.length; j++) {
        var ms = period[j].getTime()
        if (ms < first) continue
        if (ms > until || (count && made >= count)) return starts
        starts.push(ms)
        made++
      }
      // Past the end with nothing left to make: periods only move later.
      if (periodStart > until) break
      if (freq === "DAILY" && at(s.getFullYear(), s.getMonth(), s.getDate() + p * every).getTime() > until) break
      if (freq === "WEEKLY" && monday.getTime() + p * every * 7 * 24 * 3600 * 1000 > until) break
      if (freq === "MONTHLY" && new Date(s.getFullYear(), s.getMonth() + p * every, 1).getTime() > until) break
      if (freq === "YEARLY" && new Date(s.getFullYear() + p * every, 0, 1).getTime() > until) break
    }
    return starts
  }

  // "20261002" (a day), "20261002T150000" (local), "20261002T150000Z" (UTC).
  function icsDate(prop) {
    var m = prop.value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?$/)
    if (!m) return null
    var y = Number(m[1]), mo = Number(m[2]) - 1, d = Number(m[3])
    if (m[4] === undefined || m[4] === "") return { ms: new Date(y, mo, d).getTime(), allDay: true }
    var h = Number(m[4]), mi = Number(m[5]), s = Number(m[6])
    if (m[7] === "Z") return { ms: Date.UTC(y, mo, d, h, mi, s), allDay: false }
    return { ms: new Date(y, mo, d, h, mi, s).getTime(), allDay: false }
  }
  // "PT1H30M", "P1D", "P2W".
  function durationMs(text) {
    var m = String(text).match(/^[+]?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/)
    if (!m) return 0
    var n = function(i) { return Number(m[i] || 0) }
    return (((n(1) * 7 + n(2)) * 24 + n(3)) * 60 + n(4)) * 60000 + n(5) * 1000
  }
  function plainText(text) {
    return text.replace(/\\([\;,nN])/g, function(all, c) { return c === "n" || c === "N" ? " " : c }).trim()
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
