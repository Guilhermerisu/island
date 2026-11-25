pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../views/settings/controls"

// Settings pane for Calendar: sync interval & manual refresh, and ICS feeds
// with direct shortcuts to copy links from Google Calendar and Outlook.
ColumnLayout {
  id: page
  required property var view
  required property var calendar
  property bool shown: false
  spacing: 20

  readonly property string icsError: {
    var errs = calendar.fetchErrors || ({})
    var msgs = []
    Object.keys(errs).forEach(function(k) {
      if (k.indexOf("ics:") === 0 && errs[k]) msgs.push(errs[k])
    })
    return msgs.join(" · ")
  }

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
          { label: "1m", value: 1 },
          { label: "2m", value: 2 },
          { label: "5m", value: 5 },
          { label: "15m", value: 15 }
        ]
        value: page.calendar.refreshMinutes
        onPicked: function(v) { page.calendar.addon.setOption("refreshMinutes", v) }
      }
    }
    SettingsRow {
      view: page.view
      label: "Status"
      detail: page.syncDetailText()
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

  // ---------- ICS Links ----------
  SettingsGroup {
    view: page.view
    title: "Calendars"
    footer: "In Google Calendar, pick your calendar → Integrate calendar → copy Secret address in iCal format. In Outlook, pick a calendar → Publish → copy the ICS link."
    SettingsRow {
      view: page.view
      label: "Get ICS link"
      detail: "Open settings in your browser to copy your calendar link"
      Row {
        spacing: 8
        SettingsButton {
          view: page.view
          label: "Google Calendar"
          onClicked: page.calendar.openMeeting("https://calendar.google.com/calendar/u/0/r/settings/calendar/")
        }
        SettingsButton {
          view: page.view
          label: "Outlook"
          onClicked: page.calendar.openMeeting("https://outlook.live.com/calendar/0/options/calendar/SharedCalendars")
        }
      }
    }
    SettingsRow {
      view: page.view
      label: "ICS links"
      detail: "Paste one or more links, separated by spaces"
      last: page.icsError === ""
      SettingsTextField {
        view: page.view
        implicitWidth: 230
        value: String(page.calendar.addon.option("urls") || "")
        placeholder: "https://…/basic.ics"
        onCommitted: function(v) { page.calendar.addon.setOption("urls", v) }
      }
    }
    Item {
      visible: page.icsError !== ""
      Layout.fillWidth: true
      implicitHeight: icsErrText.implicitHeight + 20
      RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        PaneIcon {
          view: page.view
          Layout.preferredWidth: 22
          Layout.preferredHeight: 22
          flat: true
          glyph: "󰀦"
          tint: page.view.host.theme.system.orange
        }
        Text {
          id: icsErrText
          Layout.fillWidth: true
          text: page.icsError
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: page.view.host.theme.system.red
          font.family: page.view.host.theme.textFontFamily
          font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailCaptionFontSize)
          font.pixelSize: page.view.detailCaptionFontSize
        }
      }
    }
  }
}
