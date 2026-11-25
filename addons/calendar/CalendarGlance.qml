import QtQuick

// The calendar zone in the control center's XSmall and Small sizes (a visual
// of its own, not the Normal view cut): XSmall is one line, today's next
// event (else its date); Small the date as a calendar page on the left and
// all the events left of today on the right (the zone
// scrolls them if there are many). A click anywhere opens the
// calendar view. `view` is the CalendarView; the days shown are today's, the
// zone has no day to pick.
Item {
  id: glance
  required property var view
  readonly property var calendar: view.calendar
  readonly property var theme: view.theme
  readonly property bool small: view.zoneSize === "small"
  readonly property real nowMs: calendar.host.clockDate.getTime()
  // What is left of today: all-day events, then the timed ones not over.
  readonly property var remaining: calendar.eventsOn(calendar.today).filter(function(e) { return e.allDay || e.end > glance.nowMs })
  readonly property var next: calendar.nextToday

  // "Mon, Nov 23"
  readonly property string dateText: view.weekdays[calendar.today.getDay()].slice(0, 3) + ", "
    + view.months[calendar.today.getMonth()].slice(0, 3) + " " + calendar.today.getDate()
  // What stands in for the events when there are none.
  readonly property string emptyText: calendar.status === "missing" ? "Add a calendar in Settings"
    : calendar.status === "offline" ? "Couldn't reach your calendars"
    : calendar.status === "loading" ? "Loading…" : "No events"
  // The same in a few words, for XSmall's one line.
  readonly property string emptyShort: calendar.status === "missing" ? "No calendar"
    : calendar.status === "offline" ? "Offline" : emptyText
  // XSmall's one event: the next timed one ("14:00 · Standup", "Now · Standup"
  // while it's on), else an all-day one.
  readonly property var one: next || remaining[0] || null
  readonly property string oneText: !one ? dateText + " · " + emptyShort
    : (one.allDay ? "All day" : one.start <= nowMs ? "Now" : calendar.timeText(one.start)) + " · " + one.title

  // XSmall's line is 34 of the 42 px its card leaves (fixed); Small is what it
  // holds.
  implicitHeight: small ? page.implicitHeight : 34

  component Label: Text {
    property int size: 13
    font.pixelSize: size
    elide: Text.ElideRight
    textFormat: Text.PlainText
    color: glance.view.ink
    font.family: glance.theme.textFontFamily
    font.features: { "tnum": 1 }
    font.letterSpacing: glance.theme.tracking(glance.theme.textFontFamily, size)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: glance.calendar.host.view = "calendar"
  }

  // ---------- XSmall ----------

  Item {
    visible: !glance.small
    anchors.fill: parent
    Rectangle {
      id: dot
      visible: !!glance.one
      anchors.verticalCenter: parent.verticalCenter
      width: 10
      height: 10
      radius: 5
      color: glance.one ? glance.one.color : "transparent"
    }
    Label {
      anchors.left: glance.one ? dot.right : parent.left
      anchors.leftMargin: glance.one ? 10 : 0
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: glance.oneText
      color: glance.one ? glance.view.ink : glance.view.inkMuted
      size: glance.theme.size.title3
      font.weight: Font.Medium
    }
  }

  // ---------- Small ----------

  Item {
    id: page
    visible: glance.small
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: Math.max(day.implicitHeight, events.implicitHeight)

    // The weekday over the date, as the tile's badge.
    Column {
      id: day
      width: 56
      anchors.verticalCenter: parent.verticalCenter
      Label {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: glance.view.weekdays[glance.calendar.today.getDay()].slice(0, 3).toUpperCase()
        color: glance.view.accent
        size: glance.theme.size.callout
        font.weight: Font.Bold
      }
      Label {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: glance.calendar.today.getDate()
        size: glance.theme.px(32)
        font.weight: Font.Light
      }
    }
    Column {
      id: events
      anchors.left: day.right
      anchors.leftMargin: 8
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      Repeater {
        model: glance.remaining
        delegate: Item {
          required property var modelData
          width: events.width
          height: title.implicitHeight
          Rectangle {
            id: bar
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height - 2
            radius: 1.5
            color: modelData.color
          }
          Label {
            id: time
            anchors.left: bar.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.allDay ? "All day" : glance.calendar.timeText(modelData.start)
            color: glance.view.inkMuted
            size: glance.theme.size.callout
          }
          Label {
            id: title
            anchors.left: time.right
            anchors.leftMargin: 6
            anchors.right: parent.right
            text: modelData.title
            size: glance.theme.size.body
            font.weight: Font.Medium
          }
        }
      }
      Label {
        visible: glance.remaining.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        maximumLineCount: 2
        text: glance.emptyText
        color: glance.view.inkMuted
        size: glance.theme.size.body
        font.weight: Font.Medium
      }
    }
  }
}
