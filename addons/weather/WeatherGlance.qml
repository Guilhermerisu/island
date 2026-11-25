import QtQuick
import "../../components"

// The weather zone in the control center's XSmall and Small sizes (a visual
// of its own, not the Normal view cut): XSmall is one line, the icon, the
// temperature, the city and today's range; Small the temperature, condition
// and range on the left, all the hours the addon has as small columns on the
// right. A click anywhere opens the weather view, which is where everything
// the Normal zone does is too (its "Open Settings" and "Try Again" buttons,
// shown in place of the data). `view` is the WeatherView.
Item {
  id: glance
  required property var view
  readonly property var theme: view.theme
  readonly property var now: view.now
  readonly property bool small: view.zoneSize === "small"
  readonly property bool hasRange: !!now && now.high !== null && now.high !== undefined
  // The XSmall line is 34 of the 42 px its card leaves (fixed, so it can be
  // read here); Small is as tall as what it holds, never from its room.
  implicitHeight: !view.showing || !small ? 34 : Math.max(left.implicitHeight, hourRow.implicitHeight)

  function range() { return "↑" + view.degrees(now.high) + " ↓" + view.degrees(now.low) }
  // "5PM" is too wide for a column here: the hour alone, or 5P.
  function hourShort(hour) { return view.host.settings.clock24h ? String(hour) : ((hour + 11) % 12 + 1) + (hour < 12 ? "A" : "P") }

  component Label: Text {
    property int size: 13
    font.pixelSize: size
    elide: Text.ElideRight
    color: view.ink
    font.family: glance.theme.textFontFamily
    font.features: { "tnum": 1 }
    font.letterSpacing: glance.theme.tracking(glance.theme.textFontFamily, size)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: glance.view.host.view = "weather"
  }

  // Loading, or why there's nothing to show.
  Label {
    visible: !view.showing
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    // The Normal view's long hint is a line too many here.
    text: view.weather.status === "missing" ? "Set a city in Settings → Addons" : view.statusText
    color: view.textMuted
    size: glance.theme.size.body
  }

  // ---------- XSmall ----------

  Item {
    visible: view.showing && !glance.small
    anchors.fill: parent

    WeatherIcon {
      id: icon
      anchors.verticalCenter: parent.verticalCenter
      size: 30
      fontFamily: glance.theme.fontFamily
      code: glance.now ? glance.now.code : 0
      day: glance.now ? glance.now.day : true
    }
    Label {
      id: degrees
      anchors.left: icon.right
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: glance.now ? view.degrees(glance.now.temperature) : ""
      size: glance.theme.size.title1
      font.weight: Font.Medium
    }
    Label {
      id: span
      visible: glance.hasRange
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: glance.hasRange ? glance.range() : ""
      color: view.inkMuted
      size: glance.theme.size.body
    }
    Label {
      anchors.left: degrees.right
      anchors.leftMargin: 10
      anchors.right: span.visible ? span.left : parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      // "Paris, FR": the country is the Normal view's.
      text: view.weather.place.split(",")[0]
      size: glance.theme.size.title3
    }
  }

  // ---------- Small ----------

  Column {
    id: left
    visible: view.showing && glance.small
    anchors.left: parent.left
    anchors.right: hourRow.left
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    Label {
      width: parent.width
      text: glance.now ? view.degrees(glance.now.temperature) : ""
      size: glance.theme.px(30)
      font.weight: Font.Light
    }
    Label {
      width: parent.width
      text: glance.now ? view.weather.describe(glance.now.code) : ""
      color: view.inkMuted
      size: glance.theme.size.callout
    }
    Label {
      visible: glance.hasRange
      width: parent.width
      text: glance.hasRange ? glance.range() : ""
      color: view.inkMuted
      size: glance.theme.size.callout
    }
  }
  Row {
    id: hourRow
    visible: view.showing && glance.small
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    Repeater {
      model: view.weather.hours
      delegate: Column {
        required property var modelData
        width: 31
        spacing: 2
        Label {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: glance.hourShort(modelData.hour)
          color: view.inkMuted
          size: glance.theme.size.footnote
          font.weight: Font.Medium
        }
        WeatherIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          size: 22
          fontFamily: glance.theme.fontFamily
          code: modelData.code
          day: modelData.day
        }
        Label {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: view.degrees(modelData.temperature)
          size: glance.theme.size.body
          font.weight: Font.Medium
        }
      }
    }
  }
}
