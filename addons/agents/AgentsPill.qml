import QtQuick
import "../../components"

// Claude Code or Codex at work, as Apple's live activities: its mascot (see
// AgentAvatar) leading and the turn's time trailing, the clock between them.
// When a turn ends, or starts waiting on you, it grows into a notice of it
// (AgentNotice), which says so. `agents` is the AgentsAddon.
Item {
  id: pill
  required property var agents
  readonly property var host: agents.host
  readonly property var theme: host.theme
  readonly property color ink: agents.ink
  readonly property string phase: agents.live ? agents.live.state : ""
  readonly property bool codex: !!agents.live && agents.live.provider === "codex"

  // Whether it's on the island, steadied: going from a moment's pill back
  // to the ongoing one, the island's bindings can drop it for an instant,
  // which would replay its parts' reveal from nothing.
  property bool onIsland: agents.pillShown
  Connections {
    target: pill.agents
    function onPillShownChanged() {
      if (pill.agents.pillShown) pill.onIsland = true
      else Qt.callLater(function() { pill.onIsland = pill.agents.pillShown })
    }
  }

  opacity: onIsland ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }

  // How far the pill has grown into a notice (see AgentNotice), following the
  // island's own height as it springs, so what moves keeps in step with it.
  // Only from a notice, till the pill's back to its size: the island growing
  // into an open view (or shrinking back from one) isn't one.
  property bool fromNotice: false
  readonly property real heightGrow: Math.max(0, Math.min(1, (height - agents.restHeight) / (agents.noticeHeight - agents.restHeight)))
  onHeightGrowChanged: if (heightGrow === 0 && !agents.noticeShown) fromNotice = false
  Connections {
    target: pill.agents
    function onNoticeShownChanged() { if (pill.agents.noticeShown) pill.fromNotice = true }
  }
  Connections {
    target: pill.host
    function onSurfaceOpenChanged() { if (pill.host.surfaceOpen) pill.fromNotice = false }
  }
  readonly property real grow: fromNotice ? heightGrow : 0
  readonly property bool noticing: agents.noticeShown || grow > 0.5

  // Clawd and the time come in from a blur in turn, as the other pills; the
  // time gives way while the pill's grown into a notice, and comes back
  // once it's shrunk most of the way.
  PillReveal { id: reveal; theme: pill.theme; shown: pill.onIsland && !pill.noticing }
  // The mascot stays through the notice: it moves onto the notice's tile.
  PillReveal { id: mascotReveal; theme: pill.theme; shown: pill.onIsland }

  HoverHandler {
    enabled: pill.agents.pillShown
    onHoveredChanged: pill.agents.hovered = hovered
  }

  // Clawd, walking while it takes a step, thinking between them, and
  // hopping once it's done. Whole pixels, so it stays crisp. As the pill
  // grows into a notice he walks over onto its tile, and acts the notice out
  // there; he goes back as it shrinks.
  AgentAvatar {
    id: mascot
    z: 2
    // The notice's agent while one's on (or still shrinking away), else the
    // turn on the pill.
    readonly property var session: pill.noticing && noticeItem.displayed ? noticeItem.displayed : pill.agents.live
    // Codex's logo sits centered in the pill's rounded end.
    readonly property real restX: logo ? Math.round((pill.agents.restHeight - width) / 2) : provider === "codex" ? 8 : 14
    readonly property real tileX: noticeItem.tileCenter - width / 2
    x: Math.round(restX + (tileX - restX) * pill.grow)
    // Clawd (his body) and Codex's logo sit centered; the stand-in pixel
    // Clawd's box has a row of room under his feet.
    y: Math.round((parent.height - height) / 2) + (original || logo ? 0 : 1)
    provider: session ? session.provider || "claude" : "claude"
    clawd: pill.agents.clawd
    sheet: pill.agents.petSheet
    cols: pill.agents.petCols
    rows: pill.agents.petRows
    color: pill.agents.noticeShown ? noticeItem.mascotTint : pill.ink
    Behavior on color { MotionColorAnimation { theme: pill.theme } }
    fontFamily: pill.theme.fontFamily
    mood: pill.agents.noticeShown ? (noticeItem.asking ? "wave" : "done")
      : ({ done: "done", asking: "wave", tool: "walk" })[pill.phase] || "think"
    // A notice following another straight away acts out from the start.
    running: pill.agents.pillShown && noticeItem.fresh
    opacity: mascotReveal.leadingIn
    PillPart { progress: mascotReveal.leadingIn }
  }

  // The turn's time, as the other pills give theirs.
  RollingText {
    id: restTime
    theme: pill.theme
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    text: pill.agents.timeText(pill.agents.turnTime)
    color: pill.ink
    font.family: pill.theme.textFontFamily
    font.pixelSize: pill.theme.size.body
    font.weight: Font.DemiBold
    font.features: { "tnum": 1, "case": 1 }
    font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.body)
  }

  // Waiting on you: an amber dot left of the time, with a soft halo, coming
  // and going with it.
  Rectangle {
    visible: pill.agents.asking
    anchors.right: restTime.left
    anchors.rightMargin: 6 - 3
    anchors.verticalCenter: restTime.verticalCenter
    width: 12
    height: 12
    radius: 6
    color: pill.theme.withAlpha(pill.ink, 0.22)
    opacity: reveal.trailingIn
    PillPart { progress: reveal.trailingIn }
    Rectangle {
      anchors.centerIn: parent
      width: 6
      height: 6
      radius: 3
      color: pill.ink
    }
  }

  AgentNotice {
    id: noticeItem
    anchors.fill: parent
    agents: pill.agents
    grow: pill.grow
  }
}
