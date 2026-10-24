import QtQuick
import QtQuick.Shapes
import "../../components"

// Claude Code at work, as Apple's live activities: Clawd leading and the
// turn's time trailing, the clock between them; once the turn's done, a
// green check and "Done" in the time's place. `agents` is the AgentsAddon.
Item {
  id: pill
  required property var agents
  readonly property var host: agents.host
  readonly property var theme: host.theme
  readonly property color ink: agents.ink
  readonly property color doneInk: pill.theme.system.green
  readonly property string phase: agents.live ? agents.live.state : ""
  readonly property bool done: phase === "done"

  opacity: agents.pillShown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }

  // Clawd and the time come in from a blur in turn, as the other pills.
  PillReveal { id: reveal; theme: pill.theme; shown: pill.agents.pillShown }

  HoverHandler {
    enabled: pill.agents.pillShown
    onHoveredChanged: pill.agents.hovered = hovered
  }

  // Clawd, walking while it takes a step, thinking between them, and
  // hopping once it's done. Whole pixels, so it stays crisp.
  AgentsMascot {
    anchors.left: parent.left
    anchors.leftMargin: 14
    y: Math.round((parent.height - height) / 2) + 1
    color: pill.ink
    mood: ({ done: "done", asking: "wave", tool: "walk" })[pill.phase] || "think"
    running: pill.agents.pillShown
    opacity: reveal.leadingIn
    PillPart { progress: reveal.leadingIn }
  }

  // The turn's time, as the other pills give theirs. Done, it gives way
  // to a green check filling in, then "Done" sliding in after it.
  Row {
    id: restRow
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    // Folding away as the turn ends.
    Item {
      anchors.verticalCenter: parent.verticalCenter
      property real shown: pill.done ? 0 : 1
      Behavior on shown { MotionAnimation { theme: pill.theme; pace: "morph" } }
      width: restTime.implicitWidth * shown
      height: restTime.implicitHeight
      clip: true
      opacity: shown
      Text {
        id: restTime
        anchors.right: parent.right
        text: pill.agents.timeText(pill.agents.turnTime)
        color: pill.ink
        font.family: pill.theme.textFontFamily
        font.pixelSize: pill.theme.px(13)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1, "case": 1 }
        font.letterSpacing: -0.2
      }
    }
    // Opening in the time's place.
    Item {
      id: doneLabel
      anchors.verticalCenter: parent.verticalCenter
      property real shown: pill.done ? 1 : 0
      Behavior on shown { MotionAnimation { theme: pill.theme; pace: "morph" } }
      width: doneContent.implicitWidth * shown
      height: doneContent.implicitHeight
      clip: true
      Row {
        id: doneContent
        anchors.right: parent.right
        spacing: 5
        // A filled green circle growing in, its tick drawing its two
        // strokes in turn, as SF Symbols' checkmark.circle.fill.
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 14
          height: 14
          radius: 7
          color: pill.doneInk
          scale: 0.4 + 0.6 * Math.min(1, doneTick.draw * 2)
          opacity: Math.min(1, doneTick.draw * 3)
          Shape {
            id: doneTick
            anchors.fill: parent
            property real draw: pill.done ? 1 : 0
            Behavior on draw {
              SequentialAnimation {
                PauseAnimation { duration: doneTick.draw > 0 ? 0 : pill.theme.contentRevealDelay + pill.theme.scaled(40) }
                MotionAnimation { theme: pill.theme; pace: "morph" }
              }
            }
            preferredRendererType: Shape.CurveRenderer
            Tick {
              strokeColor: doneTick.draw > 0.01 ? "#000000" : "transparent"
              strokeWidth: 1.8
              startX: 4
              startY: 7.3
              corner: Qt.point(6.2, 9.5)
              end: Qt.point(10.2, 4.7)
              draw: doneTick.draw
            }
          }
        }
        // "Done", sliding in from the right after the tick.
        Text {
          id: doneWord
          anchors.verticalCenter: parent.verticalCenter
          text: "Done"
          color: pill.doneInk
          property real shown: pill.done ? 1 : 0
          Behavior on shown {
            SequentialAnimation {
              PauseAnimation { duration: doneWord.shown > 0 ? 0 : pill.theme.contentRevealDelay + pill.theme.scaled(93) }
              MotionAnimation { theme: pill.theme; pace: "morph" }
            }
          }
          opacity: shown
          transform: Translate { x: 10 * (1 - doneWord.shown) }
          font.family: pill.theme.textFontFamily
          font.pixelSize: pill.theme.px(13)
          font.weight: Font.DemiBold
          font.letterSpacing: -0.2
        }
      }
    }
  }

  // A tick drawing itself in as `draw` runs 0 → 1: from the start down to
  // `corner`, then up to `end`, one stroke after the other.
  component Tick: ShapePath {
    id: tick
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    property real draw: 1
    property point corner
    property point end
    readonly property real first: Math.min(1, draw * 2)
    readonly property real second: Math.max(0, draw * 2 - 1)
    PathLine { x: tick.startX + (tick.corner.x - tick.startX) * tick.first; y: tick.startY + (tick.corner.y - tick.startY) * tick.first }
    PathLine { x: tick.corner.x + (tick.end.x - tick.corner.x) * tick.second; y: tick.corner.y + (tick.end.y - tick.corner.y) * tick.second }
  }
}
