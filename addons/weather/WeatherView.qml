import QtQuick
import QtQuick.Layouts
import "../../components"

// The weather view: the place, condition, and temperature, then
// the next hours (see below). Without a reading, one row says why, with a
// button to try again or, without a city Open-Meteo knows, to Settings.
// Esc closes.
Item {
  id: view
  required property var weather
  property bool active: false
  // In a control center zone: it doesn't take the keyboard, which stays with
  // the control center (Esc closes that).
  property bool inZone: false
  readonly property var host: weather.host
  readonly property var theme: host.theme
  readonly property var now: weather.current
  readonly property bool showing: !!now
  readonly property color textMuted: theme.secondary

  // The icon glyph's side bearing and the text's line spacing leave room
  // the padding doesn't see; pulling them in keeps the card's visible
  // margins even on every side.
  readonly property int opticalLeft: 9
  readonly property int opticalTop: 7
  readonly property int opticalBottom: 2
  // Extra room above and below, on top of the even margins.
  readonly property int roomY: 5
  implicitHeight: showing ? reading.implicitHeight - opticalTop - opticalBottom + 2 * roomY
    : notice.shown ? notice.implicitHeight : loadingText.implicitHeight
  // The island's padding: the usual 22 around the reading, 16 around the
  // row that says why there's none.
  readonly property int surfacePadding: notice.shown ? 16 : 22

  onActiveChanged: {
    if (!active) return
    weather.viewOpened()
    if (!inZone) Qt.callLater(function() { view.forceActiveFocus() })
  }
  Keys.onEscapePressed: host.view = "rest"

  function degrees(value) { return Math.round(value) + "°" }
  // 17 → "17:00", or "5PM" without the 24-hour clock; a bare "17" read like
  // the temperature under it.
  function hourText(hour) {
    if (host.settings.clock24h) return (hour < 10 ? "0" : "") + hour + ":00"
    return ((hour + 11) % 12 + 1) + (hour < 12 ? "AM" : "PM")
  }
  // A chance of rain under this (%) isn't shown.
  readonly property int rainShown: 20

  // White text, Apple style, whatever the theme's text colour.
  readonly property color ink: "#ffffff"
  readonly property color inkMuted: Qt.rgba(1, 1, 1, 0.6)

  // The condition's icon close beside the place and condition, and the
  // temperature on their baseline; then now and the next hours, each with
  // its temperature and, when rain is likely, its chance in blue.
  Column {
    id: reading
    visible: view.showing
    y: view.roomY - view.opticalTop
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 16

    Item {
      id: header
      width: parent.width
      height: Math.max(headerIcon.height, place.height)

      WeatherIcon {
        id: headerIcon
        x: -view.opticalLeft
        anchors.verticalCenter: parent.verticalCenter
        size: 54
        fontFamily: view.theme.fontFamily
        code: view.now ? view.now.code : 0
        day: view.now ? view.now.day : true
      }
      Column {
        id: place
        anchors.left: headerIcon.right
        anchors.leftMargin: 14
        anchors.right: temperature.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          width: parent.width
          text: view.weather.place
          elide: Text.ElideRight
          color: view.ink
          font.family: view.theme.textFontFamily
          font.features: { "tnum": 1 }
          font.pixelSize: view.theme.size.title1
          font.weight: Font.Medium
          font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.title1)
        }
        Text {
          id: condition
          width: parent.width
          text: view.now ? view.weather.describe(view.now.code) : ""
          elide: Text.ElideRight
          color: view.inkMuted
          font.family: view.theme.textFontFamily
          font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.title3)
          font.features: { "tnum": 1 }
          font.pixelSize: view.theme.size.title3
          font.weight: Font.Normal
        }
      }
      Text {
        id: temperature
        anchors.right: parent.right
        // On the condition's baseline, the bottom of the place block.
        y: place.y + condition.y + condition.baselineOffset - baselineOffset
        text: view.now ? view.degrees(view.now.temperature) : ""
        color: view.ink
        font.family: view.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: view.theme.px(46)
        font.weight: Font.Light
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(46))
      }
    }

    // Equal columns, each centred on its own number (the ° hangs off it).
    Row {
      id: hourRow
      readonly property var columns: view.now
        ? [{ now: true, code: view.now.code, day: view.now.day, rain: 0, temperature: view.now.temperature }].concat(view.weather.hours)
        : []
      width: parent.width
      Repeater {
        model: hourRow.columns
        delegate: Column {
          required property var modelData
          width: hourRow.width / hourRow.columns.length
          spacing: 4
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.now ? "Now" : view.hourText(modelData.hour)
            color: view.inkMuted
            font.family: view.theme.textFontFamily
            font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.body)
            font.features: { "tnum": 1 }
            font.pixelSize: view.theme.size.body
            font.weight: Font.Medium
          }
          // The icon, and the chance of rain under it, share one height so
          // the temperatures line up.
          Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 26
            height: 38
            WeatherIcon {
              anchors.horizontalCenter: parent.horizontalCenter
              y: modelData.rain >= view.rainShown ? 0 : 6
              size: 26
              fontFamily: view.theme.fontFamily
              code: modelData.code
              day: modelData.day
            }
            Text {
              visible: modelData.rain >= view.rainShown
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              text: modelData.rain + "%"
              color: "#5ac8fa"
              font.family: view.theme.textFontFamily
              font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.footnote)
              font.features: { "tnum": 1 }
              font.pixelSize: view.theme.size.footnote
              font.weight: Font.Bold
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(modelData.temperature)
            color: view.ink
            font.family: view.theme.textFontFamily
            font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.title3)
            font.features: { "tnum": 1 }
            font.pixelSize: view.theme.size.title3
            font.weight: Font.Medium
            Text {
              anchors.left: parent.right
              text: "°"
              color: parent.color
              font: parent.font
            }
          }
        }
      }
    }
  }

  // Loading: a quiet line. Anything else that leaves nothing to show is one
  // row: a grey symbol in a round card, what's wrong and why, and a grey
  // button that fixes it (Try Again, or Open Settings for the city).
  Text {
    id: loadingText
    visible: !view.showing && notice.status === "loading"
    anchors.left: parent.left
    anchors.right: parent.right
    horizontalAlignment: Text.AlignHCenter
    text: "Loading weather…"
    color: view.textMuted
    font.family: view.theme.textFontFamily
    font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.size.title3)
    font.pixelSize: view.theme.size.title3
  }
  Item {
    id: notice
    readonly property string status: view.weather.status
    readonly property bool needsCity: status === "missing" || status === "unknown"
    readonly property bool shown: !view.showing && status !== "loading"
    // The island's 16 padding, plus 2 at the sides here, makes the row's
    // 16 px above and below and 18 px at the sides (a zone has its own).
    readonly property int sideInset: view.inZone ? 0 : 2
    visible: shown
    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: 44

    Rectangle {
      id: noticeIcon
      anchors.left: parent.left
      anchors.leftMargin: notice.sideInset
      anchors.verticalCenter: parent.verticalCenter
      width: 44
      height: 44
      radius: 22
      color: view.theme.card
      Text {
        anchors.centerIn: parent
        text: "󰅤"
        color: view.theme.tertiary
        font.family: view.theme.fontFamily
        font.pixelSize: view.theme.px(22)
      }
    }
    Column {
      anchors.left: noticeIcon.right
      anchors.leftMargin: 14
      anchors.right: noticeButton.left
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text {
        width: parent.width
        text: notice.status === "missing" ? "No city set" : notice.status === "unknown" ? "City not found" : "Weather unavailable"
        elide: Text.ElideRight
        color: view.theme.text
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(14))
        font.pixelSize: view.theme.px(14)
        font.weight: Font.DemiBold
      }
      Text {
        width: parent.width
        readonly property string where: view.weather.city || view.weather.place
        text: notice.status === "missing" ? "Set a city, or turn on Detect my location, in Settings → Addons."
          : notice.status === "unknown" ? "Couldn't find “" + view.weather.city + "”."
          : !view.weather.located && view.weather.detecting ? "Couldn't detect your location."
          : where ? "Couldn't reach Open-Meteo for " + where + "."
          : "Couldn't reach Open-Meteo."
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: view.textMuted
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(12))
        font.pixelSize: view.theme.px(12)
      }
    }
    Rectangle {
      id: noticeButton
      anchors.right: parent.right
      anchors.rightMargin: notice.sideInset
      anchors.verticalCenter: parent.verticalCenter
      width: buttonText.implicitWidth + 24
      height: 26
      radius: 7
      color: buttonMouse.pressed || buttonMouse.containsMouse ? view.theme.wellHover : view.theme.well
      Behavior on color { MotionColorAnimation { theme: view.theme } }
      scale: buttonMouse.pressed ? 0.96 : 1
      Behavior on scale { id: scaleMotion; MotionAnimation { theme: view.theme; pace: towards(scaleMotion.targetValue, buttonMouse.pressed ? "press" : "standard") } }
      Text {
        id: buttonText
        anchors.centerIn: parent
        text: notice.needsCity ? "Open Settings" : "Try Again"
        color: view.theme.text
        font.family: view.theme.textFontFamily
        font.letterSpacing: view.theme.tracking(view.theme.textFontFamily, view.theme.px(12))
        font.pixelSize: view.theme.px(12)
        font.weight: Font.Medium
      }
      MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: notice.needsCity ? view.host.openSettings("Addons", view.weather.addon.id) : view.weather.retry()
      }
    }
  }
}
