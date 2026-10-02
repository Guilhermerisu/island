import QtQuick
import QtQuick.Layouts
import "../../components"

// The weather view: the place, condition, and temperature, then
// the next hours (see below). Without a city (or one Open-Meteo doesn't
// know), a hint and a button to Settings → Addons. Esc closes.
Item {
  id: view
  required property var weather
  property bool active: false
  readonly property var host: weather.host
  readonly property var theme: host.theme
  readonly property var now: weather.current
  readonly property bool showing: !!now
  readonly property color textMuted: theme.withAlpha(theme.text, 0.6)

  // The icon glyph's side bearing and the text's line spacing leave room
  // the padding doesn't see; pulling them in keeps the card's visible
  // margins even on every side.
  readonly property int opticalLeft: 9
  readonly property int opticalTop: 7
  readonly property int opticalBottom: 2
  // Extra room above and below, on top of the even margins.
  readonly property int roomY: 5
  implicitHeight: showing ? reading.implicitHeight - opticalTop - opticalBottom + 2 * roomY : notice.implicitHeight

  onActiveChanged: {
    if (!active) return
    weather.viewOpened()
    Qt.callLater(function() { view.forceActiveFocus() })
  }
  Keys.onEscapePressed: host.view = "rest"

  function degrees(value) { return Math.round(value) + "°" }
  // 17 → "17", or "5PM" without the 24-hour clock, as Apple writes them.
  function hourText(hour) {
    if (host.settings.clock24h) return (hour < 10 ? "0" : "") + hour
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
        anchors.leftMargin: 8
        anchors.right: temperature.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          width: parent.width
          text: view.weather.place
          elide: Text.ElideRight
          color: view.ink
          font.family: "Adwaita Sans"
          font.pixelSize: 20
          font.weight: Font.Medium
          font.letterSpacing: -0.3
        }
        Text {
          id: condition
          width: parent.width
          text: view.now ? view.weather.describe(view.now.code) : ""
          elide: Text.ElideRight
          color: view.inkMuted
          font.family: "Adwaita Sans"
          font.pixelSize: 15
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
        font.family: "Adwaita Sans"
        font.pixelSize: 46
        font.weight: Font.Light
        font.letterSpacing: -1
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
            font.family: "Adwaita Sans"
            font.pixelSize: 13
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
              font.family: "Adwaita Sans"
              font.pixelSize: 10
              font.weight: Font.Bold
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(modelData.temperature)
            color: view.ink
            font.family: "Adwaita Sans"
            font.pixelSize: 15
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

  // Loading, or why there's nothing to show.
  ColumnLayout {
    id: notice
    visible: !view.showing
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 12
    readonly property string status: view.weather.status
    readonly property bool needsCity: status === "missing" || status === "unknown"

    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      text: notice.status === "loading" ? "Loading weather…"
        : notice.status === "missing" ? "Set a city in Settings → Addons"
        : notice.status === "unknown" ? "Couldn't find “" + view.weather.city + "”"
        : "Couldn't reach Open-Meteo"
      color: notice.status === "loading" ? view.textMuted : view.theme.text
      font.family: "Adwaita Sans"
      font.pixelSize: 15
    }
    Rectangle {
      visible: notice.status !== "loading"
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: buttonText.implicitWidth + 32
      implicitHeight: 32
      radius: height / 2
      color: buttonMouse.containsMouse ? Qt.lighter(view.theme.accent, 1.1) : view.theme.accent
      Behavior on color { MotionColorAnimation { theme: view.theme } }
      scale: buttonMouse.pressed ? 0.97 : 1
      Behavior on scale { MotionAnimation { theme: view.theme; pace: buttonMouse.pressed ? "press" : "standard" } }
      Text {
        id: buttonText
        anchors.centerIn: parent
        text: notice.needsCity ? "Open Settings" : "Try Again"
        color: view.theme.accentText
        font.family: "Adwaita Sans"
        font.pixelSize: 14
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
