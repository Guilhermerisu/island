import QtQuick
import "../../components"

// The calendar view, as Apple's widget: on the left the selected day's
// weekday, date, and events; on the right its month, Monday first, its weeks
// in rows of the same height. Today is always a filled accent circle; another
// day picked sits in a grey one. A day clicked shows its events,
// as do ←/→ (a day) and ↑/↓ (a week); scrolling or the chevrons (shown on
// hover) change the month, which slides in from that side. Esc closes; it
// opens on today.
Item {
  id: view
  required property var calendar
  property bool active: false
  // In a control center zone: it doesn't take the keyboard, which stays with
  // the control center (Esc closes that).
  property bool inZone: false
  // The zone's size ("xsmall", "small", "normal"): the first two draw
  // CalendarGlance, not the view below.
  property string zoneSize: "normal"
  readonly property bool glanced: zoneSize !== "normal"
  readonly property var host: view.calendar.host
  readonly property var theme: host.theme
  readonly property color accent: theme.accent

  // Theme-adaptive ink so the view stays legible on both dark and light islands.
  readonly property color ink: theme.text
  readonly property color inkMuted: theme.secondary

  readonly property int cell: 34
  // Six weeks' room always, so the island keeps its height from month to
  // month.
  readonly property int gridHeight: 6 * 30
  readonly property int gridWidth: 7 * cell
  // Three events fit beside the month; past that, two and a count of the
  // rest, as Apple's widget.
  readonly property int eventsShown: dayEvents.length > 3 ? 2 : 3
  readonly property var dayEvents: view.calendar.eventsOn(view.calendar.selected)

  readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
  readonly property var months: ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December"]

  implicitHeight: glanced ? glance.implicitHeight : Math.max(month.y + month.height, left.implicitHeight)

  onActiveChanged: {
    if (!active) return
    view.calendar.viewOpened()
    if (!inZone) Qt.callLater(function() { view.forceActiveFocus() })
  }
  Keys.onEscapePressed: host.view = "rest"
  Keys.onLeftPressed: view.calendar.shiftDay(-1)
  Keys.onRightPressed: view.calendar.shiftDay(1)
  Keys.onUpPressed: view.calendar.shiftDay(-7)
  Keys.onDownPressed: view.calendar.shiftDay(7)

  // ---------- The day ----------

  CalendarGlance {
    id: glance
    visible: view.glanced
    view: view
    anchors.left: parent.left
    anchors.right: parent.right
  }

  Column {
    id: left
    visible: !view.glanced
    anchors.left: parent.left
    anchors.right: month.left
    anchors.rightMargin: 20
    spacing: 0

    Text {
      text: view.weekdays[view.calendar.selected.getDay()]
      color: view.accent
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.size.body
      font.weight: Font.DemiBold
      font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.body)
    }
    Text {
      text: view.calendar.selected.getDate()
      color: view.ink
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.px(44)
      font.weight: Font.Light
      font.letterSpacing: -1
      font.features: { "tnum": 1 }
    }
    Item { width: 1; height: 8 }

    Column {
      width: parent.width
      spacing: 6
      Repeater {
        model: view.dayEvents.slice(0, view.eventsShown)
        delegate: Rectangle {
          id: eventCard
          required property var modelData
          readonly property bool hasMeeting: !!modelData.meetingUrl
          readonly property color eventInk: view.theme.isLight ? Qt.darker(modelData.color, 1.35) : Qt.lighter(modelData.color, 1.2)
          width: parent.width
          height: eventText.implicitHeight + 12
          radius: 8
          color: view.theme.withAlpha(modelData.color, hasMeeting && meetingTip.hovered ? 0.28 : 0.18)
          Rectangle {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height - 12
            radius: 1.5
            color: modelData.color
          }
          Column {
            id: eventText
            x: 15
            width: parent.width - (eventCard.hasMeeting ? 38 : 21)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
              width: parent.width
              text: modelData.title
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: eventCard.eventInk
              font.family: view.theme.textFontFamily
              font.pixelSize: view.theme.size.callout
              font.weight: Font.DemiBold
              font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.callout)
            }
            Text {
              width: parent.width
              text: view.calendar.spanText(modelData)
              color: view.theme.withAlpha(eventCard.eventInk, 0.72)
              font.family: view.theme.textFontFamily
              font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.callout)
              font.pixelSize: view.theme.size.callout
              font.weight: Font.Normal
              font.features: { "tnum": 1 }
            }
          }
          Text {
            visible: eventCard.hasMeeting
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍫"
            color: view.theme.withAlpha(eventCard.eventInk, meetingTip.hovered ? 1 : 0.78)
            font.family: view.theme.fontFamily
            font.pixelSize: view.theme.px(14)
          }
          Item {
            visible: eventCard.hasMeeting
            anchors.fill: parent
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: view.calendar.openMeeting(eventCard.modelData.meetingUrl)
            }
            Tooltip { id: meetingTip; theme: view.theme; text: "Join meeting" }
          }
        }
      }
      Text {
        visible: view.dayEvents.length > view.eventsShown
        readonly property int rest: view.dayEvents.length - view.eventsShown
        text: rest + " more event" + (rest === 1 ? "" : "s")
        color: view.inkMuted
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.callout)
        font.pixelSize: view.theme.size.callout
        font.weight: Font.Medium
      }
      // Nothing that day, or why there's nothing to show.
      Text {
        id: notice
        readonly property string status: view.calendar.status
        readonly property bool actionable: status === "missing" || status === "offline"
        visible: view.dayEvents.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: status === "missing" ? "Add a calendar in Settings"
          : status === "offline" ? "Couldn't reach your calendars"
          : status === "loading" ? "Loading…"
          : "No events"
        color: actionable && noticeMouse.containsMouse ? view.ink : view.inkMuted
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.body)
        font.pixelSize: view.theme.size.body
        font.weight: Font.Medium
        font.underline: actionable
        MouseArea {
          id: noticeMouse
          anchors.fill: parent
          enabled: notice.actionable
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: notice.status === "missing"
            ? view.host.openSettings("Calendar")
            : view.calendar.retry()
        }
      }
    }
  }

  // ---------- The month ----------

  Item {
    id: month
    visible: !view.glanced
    anchors.right: parent.right
    width: view.gridWidth
    height: grid.y + view.gridHeight

    readonly property var first: new Date(view.calendar.shownYear, view.calendar.shownMonth, 1)
    // Blank cells before the 1st, Monday first.
    readonly property int lead: (first.getDay() + 6) % 7
    readonly property int length: new Date(view.calendar.shownYear, view.calendar.shownMonth + 1, 0).getDate()
    // 26 px circles 4 px apart; the grid keeps six weeks' room.
    readonly property real rowHeight: 30

    // A month changed slides in from the side it's on, as the old fades.
    property int lastIndex: view.calendar.shownYear * 12 + view.calendar.shownMonth
    readonly property int index: view.calendar.shownYear * 12 + view.calendar.shownMonth
    onIndexChanged: {
      var by = index > lastIndex ? 1 : -1
      lastIndex = index
      slide.stop()
      slideIn.from = 14 * by
      slide.start()
    }
    ParallelAnimation {
      id: slide
      NumberAnimation { id: slideIn; target: grid; property: "x"; to: 0; duration: view.theme.motionDuration("expressive"); easing.type: Easing.BezierSpline; easing.bezierCurve: view.theme.motionCurve("settle") }
      NumberAnimation { target: grid; property: "opacity"; from: 0.2; to: 1; duration: view.theme.motionDuration("standard"); easing.type: Easing.BezierSpline; easing.bezierCurve: view.theme.motionCurve("settle") }
    }
    HoverHandler { id: monthHover }

    Text {
      id: monthName
      x: (view.cell - 14) / 2
      text: view.months[view.calendar.shownMonth]
        + (view.calendar.shownYear !== view.calendar.today.getFullYear() ? " " + view.calendar.shownYear : "")
      color: view.accent
      font.family: view.theme.textFontFamily
      font.pixelSize: view.theme.size.body
      font.weight: Font.DemiBold
      font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.body)
    }
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: monthName.verticalCenter
      Item {
        width: 24
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        opacity: view.calendar.syncing ? 0.5 : (refreshTip.hovered || monthHover.hovered ? 1 : 0.45)
        Behavior on opacity { MotionAnimation { theme: view.theme; pace: "fade"; curve: "fade" } }
        scale: refreshMouse.pressed ? 0.88 : 1
        Behavior on scale { id: scaleMotion1; MotionAnimation { theme: view.theme; pace: towards(scaleMotion1.targetValue, refreshMouse.pressed ? "press" : "standard") } }
        Text {
          anchors.centerIn: parent
          text: "󰑐"
          color: refreshTip.hovered ? view.ink : view.inkMuted
          font.family: view.theme.fontFamily
          font.pixelSize: view.theme.px(14)
        }
        MouseArea {
          id: refreshMouse
          anchors.fill: parent
          anchors.margins: -3
          enabled: !view.calendar.syncing
          cursorShape: Qt.PointingHandCursor
          onClicked: view.calendar.refreshNow()
        }
        Tooltip { id: refreshTip; theme: view.theme; text: "Refresh calendars" }
      }
      Row {
        opacity: monthHover.hovered ? 1 : 0
        Behavior on opacity { MotionAnimation { theme: view.theme; pace: "fade"; curve: "fade" } }
        Repeater {
          model: [{ glyph: "󰅁", by: -1 }, { glyph: "󰅂", by: 1 }]
          delegate: Text {
            scale: chevronMouse.pressed ? 0.88 : 1
            Behavior on scale { id: scaleMotion2; MotionAnimation { theme: view.theme; pace: towards(scaleMotion2.targetValue, chevronMouse.pressed ? "press" : "standard") } }
            required property var modelData
            width: view.cell
            horizontalAlignment: Text.AlignHCenter
            text: modelData.glyph
            color: chevronMouse.containsMouse ? view.ink : view.inkMuted
            font.family: view.theme.fontFamily
            font.pixelSize: view.theme.px(16)
            MouseArea {
              id: chevronMouse
              anchors.fill: parent
              anchors.margins: -4
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.calendar.shiftMonth(parent.modelData.by)
            }
          }
        }
      }
    }

    Row {
      id: weekdayRow
      y: monthName.height + 8
      Repeater {
        model: ["M", "T", "W", "T", "F", "S", "S"]
        delegate: Text {
          required property string modelData
          required property int index
          width: view.cell
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: view.theme.secondary
          font.family: view.theme.textFontFamily
          font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.subheadline)
          font.pixelSize: view.theme.size.subheadline
          font.weight: Font.Normal
        }
      }
    }

    Item {
      id: grid
      y: weekdayRow.y + weekdayRow.height + 6
      width: parent.width
      height: view.gridHeight

      Repeater {
        model: month.length
        delegate: Item {
          id: day
          required property int index
          readonly property int slot: month.lead + index
          readonly property date date: new Date(view.calendar.shownYear, view.calendar.shownMonth, index + 1)
          readonly property bool isToday: view.calendar.sameDay(date, view.calendar.today)
          readonly property bool isSelected: view.calendar.sameDay(date, view.calendar.selected)
          x: (slot % 7) * view.cell
          y: Math.floor(slot / 7) * month.rowHeight
          width: view.cell
          height: month.rowHeight

          Rectangle {
            anchors.centerIn: parent
            width: 26
            height: 26
            radius: 13
            color: day.isToday ? view.accent : day.isSelected ? view.theme.fill("stronger")
              : dayMouse.containsMouse ? view.theme.fill("subtle") : "transparent"
            scale: day.isSelected || day.isToday ? 1 : 0.9
            Behavior on color { MotionColorAnimation { theme: view.theme } }
            Behavior on scale { MotionAnimation { theme: view.theme; pace: "expressive" } }
          }
          Text {
            anchors.centerIn: parent
            text: day.index + 1
            color: day.isToday ? view.theme.accentText
              : day.slot % 7 >= 5 ? view.inkMuted : view.ink
            font.family: view.theme.textFontFamily
            font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.body)
            font.pixelSize: view.theme.size.body
            font.weight: day.isToday ? Font.DemiBold : Font.Normal
            font.features: { "tnum": 1 }
          }
          MouseArea {
            id: dayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.calendar.select(day.date)
          }
        }
      }
    }

    // A notch of the wheel is a month.
    WheelHandler {
      property real held: 0
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        held += event.angleDelta.y
        if (Math.abs(held) < 120) return
        view.calendar.shiftMonth(held > 0 ? -1 : 1)
        held = 0
      }
    }
  }
}
