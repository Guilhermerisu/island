import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../components"

// Shown for a moment 10 minutes before an event, as a live activity: a
// small calendar page with its month and day leading, its title over its
// times, and trailing how long before it's shown ("10 min"). Each comes
// in from a blur in turn, as the Dynamic Island's. `calendar` is the
// CalendarAddon.
Item {
  id: pill
  required property var calendar
  readonly property var host: calendar.host
  readonly property bool shown: calendar.pillShown
  readonly property var event: calendar.reminder

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  PillReveal { id: reveal; theme: pill.host.theme; shown: pill.shown }

  // Leading: a calendar page with the event's month and day, as Apple's
  // icon, in its continuous-cornered shape.
  readonly property date day: event ? new Date(event.start) : new Date()
  Item {
    id: leading
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 32
    height: 32
    opacity: reveal.leadingIn
    PillPart { progress: reveal.leadingIn }

    Shape {
      id: pageShape
      anchors.fill: parent
      visible: false
      layer.enabled: pill.visible
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: -1
        fillColor: "#ffffff"
        PathPolyline {
          // A superellipse, as Apple's icons.
          path: {
            var points = [], w = leading.width, h = leading.height
            for (var i = 0; i <= 64; i++) {
              var t = i / 64 * 2 * Math.PI, c = Math.cos(t), s = Math.sin(t)
              points.push(Qt.point(w / 2 + w / 2 * Math.sign(c) * Math.pow(Math.abs(c), 0.4),
                                   h / 2 + h / 2 * Math.sign(s) * Math.pow(Math.abs(s), 0.4)))
            }
            return points
          }
        }
      }
    }
    Item {
      anchors.fill: parent
      // Only while the pill is up, so a hidden one holds no buffers.
      // No multisampling: the mask's soft threshold already smooths the
      // page's edge, and it saves a second offscreen pass.
      layer.enabled: visible
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: pageShape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
      }
      Rectangle { anchors.fill: parent; color: "#f7f7f7" }
      Rectangle {
        id: band
        width: parent.width
        height: 11
        color: "#f2564f"
        Text {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: 0.5
          text: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][pill.day.getMonth()]
          color: "#ffffff"
          font.family: pill.host.theme.textFontFamily
          font.features: { "tnum": 1 }
          font.pixelSize: pill.host.theme.px(8)
          font.weight: Font.Bold
          font.letterSpacing: 0.2
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: band.bottom
        anchors.bottom: parent.bottom
        verticalAlignment: Text.AlignVCenter
        text: pill.day.getDate()
        color: "#2c2c2e"
        font.family: pill.host.theme.textFontFamily
        font.letterSpacing: pill.host.theme.tracking(pill.host.theme.textFontFamily, pill.host.theme.px(17))
        font.pixelSize: pill.host.theme.px(17)
        font.weight: Font.Normal
        font.features: { "tnum": 1 }
      }
    }
  }

  // Middle: the title over its times.
  Column {
    opacity: reveal.middleIn
    transformOrigin: Item.Left
    PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
    anchors.left: leading.right
    anchors.leftMargin: 10
    anchors.right: trailing.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    Text {
      width: parent.width
      text: pill.event ? pill.event.title : ""
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: "#ffffff"
      font.family: pill.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.pixelSize: pill.host.theme.px(13)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.3
    }
    Text {
      width: parent.width
      text: pill.event ? pill.calendar.spanText(pill.event) : ""
      elide: Text.ElideRight
      // Apple's secondary label.
      color: Qt.rgba(235 / 255, 235 / 255, 245 / 255, 0.6)
      font.family: pill.host.theme.textFontFamily
      font.letterSpacing: pill.host.theme.tracking(pill.host.theme.textFontFamily, pill.host.theme.px(12))
      font.pixelSize: pill.host.theme.px(12)
      font.features: { "tnum": 1 }
    }
  }

  // Trailing: the reminder's lead time.
  Text {
    id: trailing
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: pill.calendar.reminderMs / 60000 + " min"
    color: "#ffffff"
    font.family: pill.host.theme.textFontFamily
    font.letterSpacing: pill.host.theme.tracking(pill.host.theme.textFontFamily, pill.host.theme.px(15))
    font.pixelSize: pill.host.theme.px(15)
    font.weight: Font.DemiBold
    font.features: { "tnum": 1 }
  }
}
