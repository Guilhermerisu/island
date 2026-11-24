import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../components"

// An agent's turn ending or waiting on you, as the agents pill grown for a
// moment (see AgentsAddon's notice, and AgentsPill): a tile for the agent's
// mascot (the pill's own, which walks over onto it), its name and what
// happened, and a badge, coming in from a blur in turn once the pill has
// mostly grown, as the Dynamic Island's live activities do. A click on the
// pill takes you to the agent's window. `agents` is the AgentsAddon, `grow`
// how far the pill has grown (0 to 1).
Item {
  id: notice
  required property var agents
  readonly property var theme: agents.host.theme
  readonly property var session: agents.noticeShown && !agents.noticeLeaving ? agents.notice : null
  readonly property bool shown: !!session
  // Kept while it fades away.
  property var displayed: null
  // Off for a moment when one notice follows another straight away, so the
  // mascot and the badge act the new one out from the start.
  property bool fresh: true
  onSessionChanged: {
    if (!session) return
    if (displayed && displayed !== session) {
      fresh = false
      Qt.callLater(function() { notice.fresh = true })
    }
    displayed = session
  }
  property real grow: 0
  // The tile, the words, then the badge, once the pill's mostly grown; going,
  // the other way round, quicker.
  // It starts out of sight (a PillReveal otherwise starts in, for a pill
  // made already on screen).
  PillReveal {
    id: reveal
    theme: notice.theme
    shown: notice.shown && notice.grow > 0.5
    leadingIn: 0
    middleIn: 0
    trailingIn: 0
  }
  // The badge acts once it's in, so its pop isn't missed.
  readonly property bool acting: shown && fresh && reveal.trailingIn >= 0.86
  visible: reveal.leadingIn > 0 || reveal.middleIn > 0 || reveal.trailingIn > 0
  // Where the mascot stands on it, in the notice's (and the pill's) terms.
  readonly property real tileCenter: row.x + tile.x + tile.width / 2

  readonly property bool asking: displayed ? displayed.noticeKind === "asking" : false
  readonly property bool codex: displayed ? displayed.provider === "codex" : false
  readonly property color tint: asking ? theme.system.orange : theme.system.green
  readonly property color mascotTint: codex ? "#aca1c8" : "#d97757"

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 15
    spacing: 10

    // Growing in under the mascot as he arrives.
    Rectangle {
      id: tile
      Layout.preferredWidth: 39
      Layout.preferredHeight: 39
      radius: 13
      color: notice.theme.withAlpha(notice.mascotTint, 0.24)
      opacity: reveal.leadingIn
      PillPart { progress: reveal.leadingIn; scaleFrom: 0.6 }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 3
      opacity: reveal.middleIn
      PillPart { progress: reveal.middleIn; scaleFrom: 0.94 }
      Text {
        Layout.fillWidth: true
        // Claude's simply "Claude"; Codex's says where it runs (Codex CLI…).
        text: !notice.displayed ? "" : notice.codex ? notice.displayed.name || "Codex" : "Claude"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: notice.theme.text
        font.family: notice.theme.textFontFamily
        font.pixelSize: notice.theme.size.body
        font.weight: Font.DemiBold
      }
      Text {
        Layout.fillWidth: true
        text: notice.asking ? "Waiting for your answer" : "Task completed"
        color: notice.theme.secondary
        font.family: notice.theme.textFontFamily
        font.pixelSize: notice.theme.size.subheadline
      }
    }
    Item {
      Layout.preferredWidth: 23
      Layout.preferredHeight: 23
      opacity: reveal.trailingIn
      PillPart { progress: reveal.trailingIn }
      Rectangle {
        id: badge
        anchors.fill: parent
        radius: 12
        color: notice.asking ? notice.theme.withAlpha(notice.tint, 0.16) : notice.tint
        // Asking, the badge beats and a ring spreads from it. Done, a green
        // circle grows in and its tick draws its two strokes in turn, as SF
        // Symbols' checkmark.circle.fill.
        property real beat: 0
        // The circle popping in (with a little overshoot), then the tick
        // drawing, then a ring bursting off the finished badge.
        property real pop: 0
        property real draw: 0
        property real burst: 0
        scale: notice.asking ? 1 + 0.14 * beat : 0.3 + 0.7 * pop
        opacity: notice.asking ? 1 : Math.min(1, pop * 4)
        SequentialAnimation {
          running: notice.acting && !notice.asking
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
          border.color: notice.tint
          visible: !notice.asking
          scale: 1 + 1.1 * badge.burst
          opacity: badge.burst > 0 ? 0.8 * (1 - badge.burst) : 0
        }
        Shape {
          anchors.fill: parent
          visible: !notice.asking
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
          running: notice.acting && notice.asking
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
          border.color: notice.tint
          opacity: 0
          SequentialAnimation {
            running: notice.acting && notice.asking
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
          visible: notice.asking
          text: "󰋗"
          color: notice.tint
          font.family: notice.theme.fontFamily
          font.pixelSize: notice.theme.px(15)
        }
      }
    }
  }
}
