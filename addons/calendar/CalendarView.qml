import QtQuick
import "../../components"

// The calendar view, as Apple's widget: on the left the selected day's
// weekday, date, and events; on the right its month, Monday first, its weeks
// spread over the same height. As in Apple's Calendar, today is a filled
// accent circle while it's the day shown, and accent numbers once another
// day is picked, that one in a grey circle. A day clicked shows its events,
// as do ←/→ (a day) and ↑/↓ (a week); scrolling or the chevrons (shown on
// hover) change the month, which slides in from that side. Esc closes; it
// opens on today.
Item {
  id: view
  required property var calendar
  property bool active: false
  readonly property var host: view.calendar.host
  readonly property var theme: host.theme
  readonly property color accent: theme.accent

  // White text, Apple style, whatever the theme's text colour.
  readonly property color ink: "#ffffff"
  readonly property color inkMuted: Qt.rgba(1, 1, 1, 0.45)

  readonly property int cell: 34
  // Six weeks' room always, so the island keeps its height from month to
  // month; a month of fewer weeks spreads them over it, as Apple's widget.
  readonly property int gridHeight: 6 * 30
  readonly property int gridWidth: 7 * cell
  // Three events fit beside the month; past that, two and a count of the
  // rest, as Apple's widget.
  readonly property int eventsShown: dayEvents.length > 3 ? 2 : 3
  readonly property var dayEvents: view.calendar.eventsOn(view.calendar.selected)

  readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
  readonly property var months: ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December"]

  implicitHeight: Math.max(month.y + month.height, left.implicitHeight)

  onActiveChanged: {
    if (!active) return
    view.calendar.viewOpened()
    Qt.callLater(function() { view.forceActiveFocus() })
  }
  Keys.onEscapePressed: host.view = "rest"
  Keys.onLeftPressed: view.calendar.shiftDay(-1)
  Keys.onRightPressed: view.calendar.shiftDay(1)
  Keys.onUpPressed: view.calendar.shiftDay(-7)
  Keys.onDownPressed: view.calendar.shiftDay(7)

  // ---------- The day ----------

  Column {
    id: left
    anchors.left: parent.left
    anchors.right: month.left
    anchors.rightMargin: 24
    spacing: 0

    Text {
      text: view.weekdays[view.calendar.selected.getDay()].toUpperCase()
      color: view.accent
      font.family: view.theme.textFontFamily
      font.pixelSize: 14
      font.weight: Font.Bold
      font.letterSpacing: 0.4
    }
    Text {
      text: view.calendar.selected.getDate()
      color: view.ink
      font.family: view.theme.textFontFamily
      font.pixelSize: 52
      font.weight: Font.Light
      font.letterSpacing: -1.5
      font.features: { "tnum": 1 }
    }
    Item { width: 1; height: 8 }

    Column {
      width: parent.width
      spacing: 6
      Repeater {
        model: view.dayEvents.slice(0, view.eventsShown)
        delegate: Rectangle {
          required property var modelData
          width: parent.width
          height: eventText.implicitHeight + 12
          radius: 8
          color: view.theme.withAlpha(modelData.color, 0.18)
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
            width: parent.width - 21
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
              width: parent.width
              text: modelData.title
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: Qt.lighter(modelData.color, 1.2)
              font.family: view.theme.textFontFamily
              font.pixelSize: 13
              font.weight: Font.DemiBold
              font.letterSpacing: -0.1
            }
            Text {
              width: parent.width
              text: view.calendar.spanText(modelData)
              color: view.theme.withAlpha(Qt.lighter(modelData.color, 1.2), 0.7)
              font.family: view.theme.textFontFamily
              font.pixelSize: 12
              font.weight: Font.Normal
              font.features: { "tnum": 1 }
            }
          }
        }
      }
      Text {
        visible: view.dayEvents.length > view.eventsShown
        readonly property int rest: view.dayEvents.length - view.eventsShown
        text: rest + " more event" + (rest === 1 ? "" : "s")
        color: view.inkMuted
        font.family: view.theme.textFontFamily
        font.pixelSize: 12
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
        font.pixelSize: 13
        font.weight: Font.Medium
        font.underline: actionable
        MouseArea {
          id: noticeMouse
          anchors.fill: parent
          enabled: notice.actionable
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: notice.status === "missing"
            ? view.host.openSettings("Addons", view.calendar.addon.id)
            : view.calendar.retry()
        }
      }
    }
  }

  // ---------- The month ----------

  Item {
    id: month
    anchors.right: parent.right
    width: view.gridWidth
    height: grid.y + view.gridHeight

    readonly property var first: new Date(view.calendar.shownYear, view.calendar.shownMonth, 1)
    // Blank cells before the 1st, Monday first.
    readonly property int lead: (first.getDay() + 6) % 7
    readonly property int length: new Date(view.calendar.shownYear, view.calendar.shownMonth + 1, 0).getDate()
    readonly property int weeks: Math.ceil((lead + length) / 7)
    readonly property real rowHeight: view.gridHeight / weeks

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
      NumberAnimation { id: slideIn; target: grid; property: "x"; to: 0; duration: view.theme.motionDuration("expressive"); easing.type: Easing.OutCubic }
      NumberAnimation { target: grid; property: "opacity"; from: 0.2; to: 1; duration: view.theme.motionDuration("standard"); easing.type: Easing.OutCubic }
    }
    HoverHandler { id: monthHover }

    Text {
      id: monthName
      x: (view.cell - 14) / 2
      text: view.months[view.calendar.shownMonth].toUpperCase()
        + (view.calendar.shownYear !== view.calendar.today.getFullYear() ? " " + view.calendar.shownYear : "")
      color: view.accent
      font.family: view.theme.textFontFamily
      font.pixelSize: 14
      font.weight: Font.Bold
      font.letterSpacing: 0.4
    }
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: monthName.verticalCenter
      opacity: monthHover.hovered ? 1 : 0
      Behavior on opacity { MotionAnimation { theme: view.theme; pace: "fade"; curve: "fade" } }
      Repeater {
        model: [{ glyph: "󰅁", by: -1 }, { glyph: "󰅂", by: 1 }]
        delegate: Text {
          required property var modelData
          width: view.cell
          horizontalAlignment: Text.AlignHCenter
          text: modelData.glyph
          color: chevronMouse.containsMouse ? view.ink : view.inkMuted
          font.family: view.theme.fontFamily
          font.pixelSize: 16
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

    Row {
      id: weekdayRow
      y: monthName.height + 12
      Repeater {
        model: ["M", "T", "W", "T", "F", "S", "S"]
        delegate: Text {
          required property string modelData
          required property int index
          width: view.cell
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: index >= 5 ? view.inkMuted : view.ink
          font.family: view.theme.textFontFamily
          font.pixelSize: 14
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
            width: 28
            height: 28
            radius: 14
            color: day.isSelected ? (day.isToday ? view.accent : Qt.rgba(1, 1, 1, 0.2))
              : dayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            scale: day.isSelected ? 1 : 0.9
            Behavior on color { MotionColorAnimation { theme: view.theme } }
            Behavior on scale { MotionAnimation { theme: view.theme; pace: "expressive" } }
          }
          Text {
            anchors.centerIn: parent
            text: day.index + 1
            color: day.isToday ? (day.isSelected ? view.theme.accentText : view.accent)
              : day.slot % 7 >= 5 ? view.inkMuted : view.ink
            font.family: view.theme.textFontFamily
            font.pixelSize: 14
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
