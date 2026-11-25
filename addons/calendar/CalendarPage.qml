pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../views/settings/controls"

// Settings pane for Calendar: sync interval & manual refresh; the calendars,
// one row each (its name from the feed, upcoming events or why it failed, a
// switch, and Remove); adding one, with shortcuts to where Google Calendar
// and Outlook give out the link; and what the island shows.
ColumnLayout {
  id: page
  required property var view
  required property var calendar
  property bool shown: false
  spacing: page.view.groupSpacing

  readonly property string icsError: {
    var errs = calendar.fetchErrors || ({})
    var msgs = []
    Object.keys(errs).forEach(function(k) {
      if (k.indexOf("ics:") === 0 && errs[k] && calendar.urls.indexOf(k.slice(4)) >= 0) msgs.push(errs[k])
    })
    return msgs.join(" · ")
  }
  // Green once a sync worked, orange while syncing, red when it failed.
  readonly property color syncDot: calendar.syncing ? view.host.theme.system.orange
    : calendar.status === "offline" || icsError !== "" ? view.host.theme.system.red
    : calendar.status === "ready" ? view.host.theme.system.green
    : "transparent"

  function syncDetailText() {
    if (calendar.syncing) return "Syncing calendars…"
    if (calendar.status === "missing") return "No calendar configured"
    if (calendar.status === "offline") return "Offline — couldn't reach calendars"
    var count = calendar.events ? calendar.events.length : 0
    var countText = count + " event" + (count === 1 ? "" : "s")
    if (!calendar.fetchedAt) return "Ready · " + countText
    var nowMs = calendar.host.clockDate.getTime()
    var mins = Math.floor((nowMs - calendar.fetchedAt) / 60000)
    var when = mins < 1 ? "Updated just now"
      : mins < 60 ? "Updated " + mins + " min ago"
      : "Updated at " + calendar.timeText(calendar.fetchedAt)
    return when + " · " + countText
  }

  // A calendar's host ("calendar.google.com"), and its name: the feed's own,
  // else its provider's, else that host.
  function hostOf(url) { var m = String(url).match(/^[a-z]+:\/\/([^\/?#]+)/i); return m ? m[1] : url }
  function nameOf(url) {
    var info = (calendar.calendarInfo || {})["ics:" + url] || {}
    // Outlook names every published feed just "Calendar".
    if (info.name && info.name !== "Calendar") return info.name
    var host = hostOf(url)
    if (/google\.com$/i.test(host)) return "Google Calendar"
    if (/outlook\.|office365\.|live\.com$/i.test(host)) return "Outlook"
    return host
  }
  // Its events not over yet.
  function upcomingCount(url) {
    var key = "ics:" + url
    var now = calendar.host.clockDate.getTime()
    return (calendar.rawEvents || []).filter(function(e) { return e.calendar === key && e.end > now }).length
  }
  // Why it failed, without urllib's wording ("HTTP 404", "Couldn't connect").
  function errorOf(url) {
    var err = String((calendar.fetchErrors || {})["ics:" + url] || "")
    return err.replace(/^Network error:\s*/i, "Couldn't connect: ")
  }

  // ---------- Adding a calendar ----------
  property bool adding: false
  property string newUrl: ""
  property string addError: ""
  function addLink(text) {
    var url = calendar.normalizeUrl(text)
    if (url === "") return
    if (!/^https?:\/\/\S+$/i.test(url)) { addError = "That isn't a calendar link"; return }
    if (calendar.allUrls.indexOf(url) >= 0) { addError = "That calendar is already added"; return }
    calendar.addUrl(url)
    newUrl = ""
    addError = ""
    linkField.clear()
    adding = false
  }

  // ---------- Sync ----------
  SettingsGroup {
    view: page.view
    title: "Sync"
    SettingsRow {
      view: page.view
      label: "Refresh interval"
      detail: "How often your calendars sync"
      SettingsSegmented {
        view: page.view
        minWidth: 0
        options: [
          { label: "5m", value: 5 },
          { label: "15m", value: 15 },
          { label: "30m", value: 30 },
          { label: "1h", value: 60 }
        ]
        value: page.calendar.refreshMinutes
        onPicked: function(v) { page.calendar.addon.setOption("refreshMinutes", v) }
      }
    }
    SettingsRow {
      view: page.view
      label: "Status"
      detail: page.syncDetailText()
      detailDot: page.syncDot
      last: true
      SettingsButton {
        view: page.view
        label: page.calendar.syncing ? "Syncing…" : "Refresh Now"
        opacity: page.calendar.syncing ? 0.5 : 1
        onClicked: {
          page.view.forceActiveFocus()
          if (!page.calendar.syncing) page.calendar.refreshNow()
        }
      }
    }
  }

  // ---------- Calendars ----------
  SettingsGroup {
    view: page.view
    title: "Calendars"
    count: page.calendar.allUrls.length > 0 ? String(page.calendar.allUrls.length) : ""
    Repeater {
      model: page.calendar.allUrls
      delegate: SettingsRow {
        id: calRow
        required property string modelData
        readonly property bool isOn: page.calendar.urls.indexOf(modelData) >= 0
        readonly property string error: isOn ? page.errorOf(modelData) : ""
        readonly property int upcoming: page.upcomingCount(modelData)
        property bool confirming: false
        view: page.view
        icon: "󰃭"
        iconTint: isOn ? page.view.host.theme.system.red : page.view.host.theme.system.gray
        label: page.nameOf(modelData)
        keywords: page.hostOf(modelData)
        detail: confirming ? "Its link is forgotten; you'd paste it again to get it back."
          : !isOn ? "Off · " + page.hostOf(modelData)
          : error !== "" ? error
          : page.calendar.syncing && upcoming === 0 ? "Syncing…"
          : upcoming + " upcoming event" + (upcoming === 1 ? "" : "s") + " · " + page.hostOf(modelData)
        detailDot: confirming || !isOn ? "transparent"
          : error !== "" ? page.view.host.theme.system.red
          : page.view.host.theme.system.green
        Row {
          spacing: 8
          SettingsButton {
            visible: calRow.confirming
            view: page.view
            label: "Cancel"
            onClicked: calRow.confirming = false
          }
          SettingsButton {
            view: page.view
            primary: calRow.confirming
            label: calRow.confirming ? "Remove" : "Remove…"
            onClicked: calRow.confirming ? page.calendar.removeUrl(calRow.modelData) : calRow.confirming = true
          }
          SettingsSwitch {
            visible: !calRow.confirming
            anchors.verticalCenter: parent.verticalCenter
            view: page.view
            checked: calRow.isOn
            onToggled: function(c) { page.calendar.setUrlOn(calRow.modelData, c) }
          }
        }
      }
    }
    SettingsRow {
      view: page.view
      label: page.calendar.allUrls.length === 0 ? "No calendars yet" : "Add a calendar"
      detail: "From Google Calendar, Outlook, or any ICS link"
      last: true
      SettingsButton {
        view: page.view
        label: page.adding ? "Cancel" : "Add Calendar…"
        onClicked: {
          page.addError = ""
          page.adding = !page.adding
        }
      }
    }
  }

  SettingsGroup {
    visible: page.adding
    searchable: page.adding
    view: page.view
    title: "New calendar"
    SettingsRow {
      view: page.view
      icon: "󰊭"
      iconTint: page.view.host.theme.system.blue
      label: "Google Calendar"
      detail: "Your calendar → Integrate calendar → Secret address in iCal format"
      SettingsButton {
        view: page.view
        label: "Open Settings"
        onClicked: page.calendar.openMeeting("https://calendar.google.com/calendar/u/0/r/settings/calendar/")
      }
    }
    SettingsRow {
      view: page.view
      icon: "󰴢"
      iconTint: page.view.host.theme.system.indigo
      label: "Outlook"
      detail: "A calendar → Publish → ICS link"
      SettingsButton {
        view: page.view
        label: "Open Settings"
        onClicked: page.calendar.openMeeting("https://outlook.live.com/calendar/0/options/calendar/SharedCalendars")
      }
    }
    SettingsRow {
      view: page.view
      label: "Calendar link"
      detail: page.addError !== "" ? page.addError : "Paste the link you copied"
      detailDot: page.addError !== "" ? page.view.host.theme.system.red : "transparent"
      last: true
      Row {
        spacing: 8
        SettingsTextField {
          id: linkField
          view: page.view
          implicitWidth: 230
          placeholder: "https://…/basic.ics"
          onEdited: function(v) { page.newUrl = v; page.addError = "" }
          onCommitted: function(v) { if (page.adding) page.addLink(v) }
        }
        SettingsButton {
          view: page.view
          primary: page.newUrl !== ""
          label: "Add"
          onClicked: {
            page.view.forceActiveFocus()
            if (page.adding) page.addLink(page.newUrl)
          }
        }
      }
    }
  }

  // ---------- Show ----------
  SettingsGroup {
    view: page.view
    title: "Show"
    SettingsRow {
      view: page.view
      label: "All-day events"
      detail: "Birthdays, holidays and other day-long events"
      SettingsSwitch {
        view: page.view
        checked: page.calendar.showAllDay
        onToggled: function(c) { page.calendar.addon.setOption("showAllDay", c) }
      }
    }
    SettingsRow {
      view: page.view
      label: "Declined events"
      detail: "Ones you said no to in Google Calendar"
      SettingsSwitch {
        view: page.view
        checked: page.calendar.showDeclined
        onToggled: function(c) { page.calendar.addon.setOption("showDeclined", c) }
      }
    }
    SettingsRow {
      view: page.view
      label: "Event alert"
      detail: "When the pill shows before an event starts"
      last: true
      SettingsSegmented {
        view: page.view
        minWidth: 0
        options: [
          { label: "Off", value: 0 },
          { label: "5m", value: 5 },
          { label: "10m", value: 10 },
          { label: "15m", value: 15 }
        ]
        value: page.calendar.reminderMinutes
        onPicked: function(v) { page.calendar.addon.setOption("reminderMinutes", v) }
      }
    }
  }
}
