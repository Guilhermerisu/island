import QtQuick
import QtQuick.Layouts
import "../../components"

Rectangle {
  id: banner
  required property var theme
  property var agents: null
  property bool allowed: false
  property bool notch: false
  readonly property var notice: allowed && agents ? agents.notice : null
  property var displayed: null
  onNoticeChanged: if (notice) displayed = notice

  readonly property bool question: displayed?.question === true
  readonly property string subtitle: question ? "Waiting for your answer" : "Turn completed"
  property real reveal: notice ? 1 : 0
  Behavior on reveal { MotionAnimation { theme: banner.theme; pace: banner.notice ? "morph" : "exit" } }
  opacity: Math.min(1, reveal * 1.7)
  visible: opacity > 0.01
  y: -height + (height + (notch ? 3 : 8)) * reveal
  anchors.horizontalCenter: parent.horizontalCenter
  width: Math.min(318, parent.width - 16)
  height: 61
  radius: 24
  z: 25
  color: theme.background
  border.width: 1
  border.color: theme.fill("strong")

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 15
    spacing: 10
    Rectangle {
      Layout.preferredWidth: 40
      Layout.preferredHeight: 40
      radius: 13
      color: banner.theme.withAlpha(mascot.color, 0.22)
      AgentsMascot {
        id: mascot
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        eyeColor: banner.theme.background
        color: banner.question ? banner.theme.system.orange : "#d97757"
        mood: banner.question ? "wave" : "done"
        running: !!banner.notice
        Connections {
          target: banner
          function onDisplayedChanged() { mascot.tick = 0 }
        }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 3
      Text {
        text: "Claude Code"
        color: banner.theme.text
        font.family: banner.theme.textFontFamily
        font.pixelSize: banner.theme.size.body
        font.weight: Font.DemiBold
      }
      Text {
        text: banner.subtitle
        color: banner.theme.secondary
        font.family: banner.theme.textFontFamily
        font.pixelSize: banner.theme.size.subheadline
      }
    }
    Text {
      text: banner.question ? "?" : "✓"
      color: banner.question ? banner.theme.system.orange : banner.theme.system.green
      font.pixelSize: banner.theme.px(16)
      font.weight: Font.DemiBold
    }
  }

  HoverHandler { enabled: !!banner.notice; cursorShape: Qt.PointingHandCursor }
  TapHandler { enabled: !!banner.notice; onTapped: banner.agents.focusSession(banner.notice) }
  Accessible.role: Accessible.Button
  Accessible.name: "Claude Code · " + subtitle
  Accessible.description: "Focus the session window"
  Accessible.onPressAction: if (notice) agents.focusSession(notice)
}
