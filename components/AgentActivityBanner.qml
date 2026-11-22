import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../addons/agents"

// An agent's turn ending or waiting on you, as a banner dropping from the top
// edge over the island, which fades behind it: the agent's mascot acting it
// out, its name and what happened, and a badge. It's its own surface, so it
// comes up while the island is hidden too. A click takes you to the agent's
// window. `agents` is the AgentsAddon, whose `notice` it shows.
Rectangle {
  id: banner
  required property var host
  property var agents: null
  readonly property var theme: host.theme
  readonly property var session: agents ? agents.notice : null
  readonly property bool shown: !!session
  // Kept while it slides away.
  property var displayed: null
  onSessionChanged: if (session) displayed = session

  readonly property bool asking: displayed ? displayed.noticeKind === "asking" : false
  readonly property bool codex: displayed ? displayed.provider === "codex" : false
  readonly property color tint: asking ? theme.system.orange : theme.system.green
  readonly property color mascotTint: codex ? "#aca1c8" : "#d97757"
  readonly property real progress: shown ? 1 : 0
  property real reveal: progress
  Behavior on reveal { MotionAnimation { theme: banner.theme; pace: banner.shown ? "morph" : "exit" } }
  opacity: Math.min(1, reveal * 1.7)
  visible: opacity > 0.01
  y: -height + (height + (host.settings.notch ? 3 : 9)) * reveal
  anchors.horizontalCenter: parent.horizontalCenter
  width: Math.min(328, parent.width - 22)
  height: 62
  radius: 24
  z: 25
  color: theme.background
  border.width: 1
  border.color: theme.hairline
  scale: (0.96 + 0.04 * reveal) * (tap.pressed ? 0.975 : 1)
  Behavior on scale { MotionAnimation { theme: banner.theme; pace: "quick" } }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 15
    spacing: 10

    Rectangle {
      Layout.preferredWidth: 39
      Layout.preferredHeight: 39
      radius: 13
      color: banner.theme.withAlpha(banner.mascotTint, 0.24)
      AgentAvatar {
        anchors.centerIn: parent
        provider: banner.codex ? "codex" : "claude"
        clawd: banner.agents ? banner.agents.clawd : null
        sheet: banner.agents ? banner.agents.petSheet : ""
        cols: banner.agents ? banner.agents.petCols : 8
        rows: banner.agents ? banner.agents.petRows : 9
        color: banner.mascotTint
        mood: banner.asking ? "wave" : "done"
        // Starts once the banner has dropped in, so the hop isn't missed.
        running: banner.shown && banner.reveal >= 0.86
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 3
      Text {
        Layout.fillWidth: true
        text: banner.displayed ? banner.displayed.name || (banner.codex ? "Codex" : "Claude Code") : ""
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: banner.theme.text
        font.family: banner.theme.textFontFamily
        font.pixelSize: banner.theme.size.body
        font.weight: Font.DemiBold
      }
      Text {
        Layout.fillWidth: true
        text: banner.asking ? "Waiting for your answer" : "Task completed"
        color: banner.theme.secondary
        font.family: banner.theme.textFontFamily
        font.pixelSize: banner.theme.size.subheadline
      }
    }
    Rectangle {
      id: badge
      Layout.preferredWidth: 23
      Layout.preferredHeight: 23
      radius: 12
      color: banner.asking ? banner.theme.withAlpha(banner.tint, 0.16) : banner.tint
      // Asking, the badge beats and a ring spreads from it. Done, a green
      // circle grows in and its tick draws its two strokes in turn, as SF
      // Symbols' checkmark.circle.fill.
      property real beat: 0
      // The circle popping in (with a little overshoot), then the tick
      // drawing, then a ring bursting off the finished badge.
      property real pop: 0
      property real draw: 0
      property real burst: 0
      scale: banner.asking ? 1 + 0.14 * beat : 0.3 + 0.7 * pop
      opacity: banner.asking ? 1 : Math.min(1, pop * 4)
      SequentialAnimation {
        running: banner.shown && !banner.asking && banner.reveal >= 0.86
        onStarted: { badge.pop = 0; badge.draw = 0; badge.burst = 0 }
        PauseAnimation { duration: 250 }
        NumberAnimation { target: badge; property: "pop"; from: 0; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        PauseAnimation { duration: 80 }
        NumberAnimation { target: badge; property: "draw"; from: 0; to: 1; duration: 650; easing.type: Easing.InOutCubic }
        NumberAnimation { target: badge; property: "burst"; from: 0; to: 1; duration: 700; easing.type: Easing.OutQuad }
      }
      Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: banner.tint
        visible: !banner.asking
        scale: 1 + 1.1 * badge.burst
        opacity: badge.burst > 0 ? 0.8 * (1 - badge.burst) : 0
      }
      Shape {
        anchors.fill: parent
        visible: !banner.asking
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          id: tick
          fillColor: "transparent"
          strokeColor: badge.draw > 0.01 ? "#000000" : "transparent"
          strokeWidth: 2.4
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin
          // From the start down to the corner, then up to the end.
          readonly property real first: Math.min(1, badge.draw * 2)
          readonly property real second: Math.max(0, badge.draw * 2 - 1)
          startX: 6.5
          startY: 12
          PathLine { x: 6.5 + 3.7 * tick.first; y: 12 + 3.7 * tick.first }
          PathLine { x: 10.2 + 6.8 * tick.second; y: 15.7 - 8 * tick.second }
        }
      }
      SequentialAnimation on beat {
        running: banner.shown && banner.asking && banner.reveal >= 0.86
        loops: Animation.Infinite
        onStopped: badge.beat = 0
        NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { to: 0; duration: 260; easing.type: Easing.InQuad }
        PauseAnimation { duration: 480 }
      }
      Rectangle {
        id: ring
        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: banner.tint
        opacity: 0
        SequentialAnimation {
          running: banner.shown && banner.asking && banner.reveal >= 0.86
          loops: Animation.Infinite
          onStopped: { ring.opacity = 0; ring.scale = 1 }
          ParallelAnimation {
            NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.9; duration: 900; easing.type: Easing.OutQuad }
            NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 900 }
          }
          PauseAnimation { duration: 300 }
        }
      }
      Text {
        anchors.centerIn: parent
        visible: banner.asking
        text: "󰋗"
        color: banner.tint
        font.family: banner.theme.fontFamily
        font.pixelSize: banner.theme.px(15)
      }
    }
  }

  HoverHandler { enabled: banner.shown; cursorShape: Qt.PointingHandCursor }
  TapHandler {
    id: tap
    enabled: banner.shown
    onTapped: if (banner.agents) banner.agents.focusNotice()
  }
  Accessible.role: Accessible.Button
  Accessible.name: (displayed ? displayed.name || "" : "") + " · " + (asking ? "Waiting for your answer" : "Task completed")
  Accessible.description: "Open the agent's window"
  Accessible.onPressAction: if (agents) agents.focusNotice()
}
