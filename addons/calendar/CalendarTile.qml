import QtQuick
import "../../views/control-center"

// The control center tile, a CcTile like the others: its badge holds
// today's weekday over the date, as Apple's calendar icon, and a dot in the
// next event's colour; beside it that event and when, relative
// while it's near ("In 25 min · 16:36", "Now · until 17:36"), or the date
// ("October 2") and that there's none left. The badge is lit, as a tile
// switched on, while the event is on or within the reminder's lead time.
// Opens the calendar view. `calendar` is the CalendarAddon.
CcTile {
  id: tile
  required property var calendar
  readonly property var next: calendar.nextToday
  readonly property real now: calendar.host.clockDate.getTime()
  readonly property bool ongoing: !!next && next.start <= now
  readonly property int minutesLeft: next ? Math.max(1, Math.round((next.start - now) / 60000)) : 0
  readonly property bool soon: !!next && (ongoing || next.start - now <= calendar.reminderMs)
  readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
  readonly property string weekday: weekdays[calendar.today.getDay()]
  readonly property var months: ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December"]
  // "October 2"
  readonly property string dateText: months[calendar.today.getMonth()] + " " + calendar.today.getDate()

  anchors.fill: parent
  checked: soon
  title: next ? next.title : dateText
  subtitle: !next ? (calendar.urls.length === 0 ? "No calendar added" : "No more events today")
    : ongoing ? "Now · until " + calendar.timeText(next.end)
    : minutesLeft <= 60 ? "In " + minutesLeft + " min · " + calendar.timeText(next.start)
    : calendar.spanText(next)
  onClicked: calendar.host.view = "calendar"

  // Over the badge (left 12, 42 wide), which is left without an icon.
  Column {
    x: 12 + (42 - width) / 2
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 1
    spacing: -5
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: tile.weekday.slice(0, 3).toUpperCase()
      color: tile.checked ? tile.center.accentInk : tile.center.accent
      font.family: tile.center.host.theme.textFontFamily
      font.pixelSize: tile.center.host.theme.px(9)
      font.weight: Font.Bold
      font.letterSpacing: 0.3
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: tile.calendar.today.getDate()
      color: tile.checked ? tile.center.accentInk : tile.center.text
      font.family: tile.center.host.theme.textFontFamily
      font.pixelSize: tile.center.host.theme.px(19)
      font.weight: Font.Normal
      font.features: { "tnum": 1 }
    }
  }
  // The next event's calendar, on the badge's edge.
  Rectangle {
    visible: !!tile.next
    x: 12 + 42 - width + 1
    y: (tile.height + 42) / 2 - height + 1
    width: 13
    height: 13
    radius: width / 2
    color: tile.color
    Rectangle {
      anchors.centerIn: parent
      width: 9
      height: 9
      radius: width / 2
      color: tile.next ? tile.next.color : "transparent"
    }
  }
}
