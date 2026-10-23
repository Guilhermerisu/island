import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../components"

// "Keep these display settings?" on the island, as an iOS live activity, in
// the theme's colours: the Displays sun leading, the question over the countdown, a ring
// running out trailing, and Revert and Keep Changes under them.
// `displays` is the DisplaysAddon.
Item {
  id: pill
  required property var displays
  readonly property var host: displays.host
  readonly property var theme: host.theme

  opacity: displays.pillShown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.topMargin: 14
    anchors.bottomMargin: 14
    spacing: 12

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Rectangle {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 17
        color: pill.theme.accent
        Text {
          anchors.centerIn: parent
          text: "󰖨"
          color: pill.theme.accentText
          font.family: pill.theme.fontFamily
          font.pixelSize: 20
        }
      }
      Column {
        Layout.fillWidth: true
        spacing: 0
        Text {
          width: parent.width
          text: "Keep these display settings?"
          elide: Text.ElideRight
          color: pill.theme.text
          font.family: pill.theme.textFontFamily
          font.pixelSize: pill.theme.px(13)
          font.weight: Font.DemiBold
          font.letterSpacing: -0.3
        }
        Text {
          width: parent.width
          text: "Reverting in " + pill.displays.secondsLeft + (pill.displays.secondsLeft === 1 ? " second" : " seconds")
          elide: Text.ElideRight
          color: pill.theme.secondary
          font.family: pill.theme.textFontFamily
          font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.px(12))
          font.pixelSize: pill.theme.px(12)
          font.features: { "tnum": 1 }
        }
      }
      // The seconds left, in a ring that empties with them.
      Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: pill.theme.fill("strong")
            strokeWidth: 3
            PathAngleArc { centerX: 14; centerY: 14; radiusX: 12.5; radiusY: 12.5; startAngle: 0; sweepAngle: 360 }
          }
          ShapePath {
            fillColor: "transparent"
            strokeColor: pill.theme.accent
            strokeWidth: 3
            capStyle: ShapePath.RoundCap
            PathAngleArc {
              centerX: 14; centerY: 14; radiusX: 12.5; radiusY: 12.5
              startAngle: -90
              sweepAngle: 360 * pill.displays.secondsLeft / 10
              Behavior on sweepAngle { NumberAnimation { duration: 950; easing.type: Easing.Linear } }
            }
          }
        }
        Text {
          anchors.centerIn: parent
          text: pill.displays.secondsLeft
          color: pill.theme.text
          font.family: pill.theme.textFontFamily
          font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.px(11))
          font.pixelSize: pill.theme.px(11)
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: [{ label: "Revert", primary: false }, { label: "Keep Changes", primary: true }]
        delegate: Rectangle {
          id: button
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: height / 2
          color: modelData.primary ? pill.theme.accent : buttonMouse.containsMouse ? pill.theme.wellHover : pill.theme.well
          Behavior on color { MotionColorAnimation { theme: pill.host.theme } }
          scale: buttonMouse.pressed ? 0.97 : 1
          Behavior on scale { MotionAnimation { theme: pill.host.theme; pace: buttonMouse.pressed ? "press" : "standard" } }
          Text {
            anchors.centerIn: parent
            text: button.modelData.label
            color: button.modelData.primary ? pill.theme.accentText : pill.theme.text
            font.family: pill.theme.textFontFamily
            font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.px(13))
            font.pixelSize: pill.theme.px(13)
            font.weight: Font.DemiBold
          }
          MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.modelData.primary ? pill.displays.keep() : pill.displays.revert()
          }
        }
      }
    }
  }
}
