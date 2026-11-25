import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../components"

// Claude Code or Codex at work, as Apple's live activities: its mascot (see
// AgentAvatar) leading and the turn's time trailing, the clock between them.
// Hovered while working, it expands into the turn's steps and a live detail
// card; when a turn ends or waits on you, it grows into a notice (AgentNotice).
// `agents` is the AgentsAddon.
Item {
  id: pill
  required property var agents
  readonly property var host: agents.host
  readonly property var theme: host.theme
  readonly property color ink: agents.ink
  readonly property color doneInk: pill.theme.system.green
  readonly property color errorInk: pill.theme.system.red
  readonly property color textInk: pill.theme.text
  readonly property color grayInk: pill.theme.secondary
  readonly property var live: agents.live
  readonly property var step: agents.current
  readonly property string phase: live ? live.state : ""
  readonly property bool codex: !!live && live.provider === "codex"
  readonly property bool done: phase === "done"
  // Done, and saying so at rest (grown, the card does).
  readonly property bool restDone: done && !expanded
  readonly property var summary: live ? live.summary : null
  readonly property bool expanded: agents.expanded && !noticing
  readonly property real inset: agents.inset

  // Grown, the header sits lower, clear of the top's curve; the steps and
  // the card start under it.
  readonly property real headerTop: 14
  readonly property real contentTop: headerTop + agents.restHeight + 2
  readonly property real cardWidth: 212
  readonly property real cardHeight: 97
  Binding {
    target: pill.agents
    property: "grownHeight"
    value: pill.contentTop + Math.max(steps.contentHeight, pill.cardHeight + 4) + 20
  }

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
  readonly property real grow: Math.max(0, Math.min(1, (height - agents.restHeight) / (agents.noticeHeight - agents.restHeight)))
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

  // The agent's mascot (Clawd or Codex pet/logo). At rest it sits on the left
  // end; when the pill grows into a notice it walks onto the notice's tile;
  // when hovered into the expanded steps view it settles into the header.
  AgentAvatar {
    id: mascot
    z: 2
    readonly property var session: pill.noticing && noticeItem.displayed ? noticeItem.displayed : pill.agents.live
    readonly property real restX: logo ? Math.round((pill.agents.restHeight - width) / 2) : provider === "codex" ? 8 : 10
    readonly property real tileX: noticeItem.tileCenter - width / 2
    x: pill.expanded ? pill.inset : Math.round(restX + (tileX - restX) * pill.grow)
    Behavior on x { enabled: !pill.noticing; MotionAnimation { theme: pill.theme; pace: "morph" } }
    y: pill.expanded
      ? pill.headerTop + Math.round((pill.agents.restHeight - height) / 2) + (original || logo ? 0 : 1)
      : Math.round((parent.height - height) / 2) + (original || logo ? 0 : 1)
    Behavior on y { enabled: !pill.noticing; MotionAnimation { theme: pill.theme; pace: "morph" } }
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
    running: pill.agents.pillShown && noticeItem.fresh
    opacity: mascotReveal.leadingIn
    PillPart { progress: mascotReveal.leadingIn }
  }

  // The resting row, which becomes the header as the pill expands into steps.
  Item {
    id: header
    width: parent.width
    height: pill.agents.restHeight
    y: pill.expanded ? pill.headerTop : 0
    Behavior on y { MotionAnimation { theme: pill.theme; pace: "morph" } }
    visible: !pill.noticing

    // Grown, agent name and session title beside the mascot, on one baseline.
    Item {
      anchors.fill: parent
      opacity: body.reveal
      visible: opacity > 0.01
      Text {
        id: name
        anchors.left: parent.left
        anchors.leftMargin: pill.inset + 36
        anchors.verticalCenter: parent.verticalCenter
        text: pill.codex ? "Codex" : "Claude"
        color: pill.textInk
        font.family: pill.theme.textFontFamily
        font.pixelSize: pill.theme.px(16)
        font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.px(16))
      }
      Text {
        anchors.left: name.right
        anchors.leftMargin: 10
        anchors.baseline: name.baseline
        width: Math.max(0, Math.min(implicitWidth, pill.width - 2 * pill.inset - 36 - name.width - 10 - grownTime.width - 16))
        elide: Text.ElideRight
        text: pill.live ? (pill.live.title || "") : ""
        color: pill.grayInk
        font.family: pill.theme.textFontFamily
        font.pixelSize: pill.theme.size.title3
        font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.title3)
      }
    }

    // The turn's time, as the other pills give theirs, a little larger
    // grown. Done, at rest the time gives way to a green check filling in,
    // then "Done" sliding in after it; grown, the time goes green.
    Item {
      id: timeBox
      anchors.right: parent.right
      anchors.rightMargin: pill.expanded ? pill.inset : 16
      Behavior on anchors.rightMargin { MotionAnimation { theme: pill.theme; pace: "morph" } }
      anchors.verticalCenter: parent.verticalCenter
      width: pill.expanded ? grownTime.implicitWidth : restRow.width
      height: Math.max(restRow.height, grownTime.implicitHeight)
      Row {
        id: restRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        property real restShown: pill.expanded ? 0 : 1
        Behavior on restShown { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }
        opacity: restShown * reveal.trailingIn
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
          RollingText {
            theme: pill.theme
            id: restTime
            anchors.right: parent.right
            text: pill.phase === "asking" ? "Waiting" : pill.agents.timeText(pill.agents.turnTime)
            color: pill.ink
            font.family: pill.theme.textFontFamily
            font.pixelSize: pill.theme.size.body
            font.weight: Font.DemiBold
            font.features: { "tnum": 1, "case": 1 }
            font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.body)
          }
        }
        // Opening in the time's place.
        Item {
          id: doneLabel
          anchors.verticalCenter: parent.verticalCenter
          property real shown: pill.restDone ? 1 : 0
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
                property real draw: pill.restDone ? 1 : 0
                Behavior on draw {
                  SequentialAnimation {
                    PauseAnimation { duration: doneTick.draw > 0 ? 0 : pill.theme.contentRevealDelay + pill.theme.scaled(40) }
                    MotionAnimation { theme: pill.theme; pace: "morph" }
                  }
                }
                preferredRendererType: Shape.CurveRenderer
                Tick {
                  strokeColor: doneTick.draw > 0.01 ? pill.theme.contrastOn(pill.doneInk) : "transparent"
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
              property real shown: pill.restDone ? 1 : 0
              Behavior on shown {
                SequentialAnimation {
                  PauseAnimation { duration: doneWord.shown > 0 ? 0 : pill.theme.contentRevealDelay + pill.theme.scaled(93) }
                  MotionAnimation { theme: pill.theme; pace: "morph" }
                }
              }
              opacity: shown
              transform: Translate { x: 10 * (1 - doneWord.shown) }
              font.family: pill.theme.textFontFamily
              font.pixelSize: pill.theme.size.body
              font.weight: Font.DemiBold
              font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.body)
            }
          }
        }
      }
      Text {
        id: grownTime
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        opacity: body.reveal
        text: pill.agents.timeText(pill.agents.turnTime)
        color: pill.done ? pill.doneInk : pill.ink
        Behavior on color { MotionColorAnimation { theme: pill.theme } }
        font.family: pill.theme.textFontFamily
        font.pixelSize: pill.theme.px(16)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1, "case": 1 }
        font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.px(16))
      }
    }
  }

  // Grown: the steps and the card, rising in as it grows and leaving as it
  // shrinks.
  Item {
    id: body
    anchors.fill: parent
    property real reveal: pill.expanded ? 1 : 0
    Behavior on reveal {
      SequentialAnimation {
        PauseAnimation { duration: pill.expanded ? pill.theme.contentRevealDelay : 0 }
        MotionAnimation { theme: pill.theme; pace: pill.expanded ? "morph" : "exit" }
      }
    }
    opacity: body.reveal
    visible: body.reveal > 0.01
    transform: Translate { y: (1 - body.reveal) * 7 }
    // Coming in (and going) out of a soft blur, as Apple's do; drawn
    // through a layer only while it moves.
    layer.enabled: body.reveal > 0.01 && body.reveal < 0.99
    layer.effect: MultiEffect {
      blurEnabled: true
      blurMax: 24
      blur: (1 - body.reveal) * 0.7
    }

    // The turn's last steps, the newest at the bottom; while it thinks
    // between them, "Thinking…" under them. They roll: a new one rises
    // into its place from a row below, the others moving up, and the oldest
    // fades out over the top. Kept by step in a ListModel, so a step that
    // finishes changes in place rather than coming in again.
    ListView {
      id: steps
      x: pill.inset
      y: pill.contentTop
      // Use the expanded target width so steps layout never collapses to a
      // negative width or oscillates grownHeight while the island morphs.
      width: 460 - 2 * pill.inset - pill.cardWidth - 14
      height: contentHeight
      interactive: false
      clip: true
      model: ListModel { id: stepModel }
      readonly property var shown: {
        var all = pill.live && pill.live.steps ? pill.live.steps.slice() : []
        if (pill.live && pill.live.state === "thinking") all.push({ id: "thinking", label: "Thinking…", status: "thinking" })
        return all.slice(-pill.agents.rows)
      }
      onShownChanged: sync()
      Component.onCompleted: sync()
      // Removes the steps gone from `shown`, updates the ones still in it,
      // and appends the new ones, in order. A new session starts afresh.
      // Of several asked at once, only the first is running; the others
      // are queued behind it.
      property string sessionId: ""
      function sync() {
        var id = pill.live ? pill.live.id : ""
        if (id !== sessionId) { stepModel.clear(); sessionId = id }
        var keep = {}
        for (var i = 0; i < shown.length; i++) keep[shown[i].id] = shown[i]
        for (var j = stepModel.count - 1; j >= 0; j--)
          if (!keep[stepModel.get(j).key]) stepModel.remove(j)
        var running = false
        for (var k = 0; k < shown.length; k++) {
          var step = shown[k], status = step.status
          if (status === "running") { if (running) status = "queued"; running = true }
          var row = { key: step.id, label: step.label || "", status: status,
            duration: step.endedAt ? pill.agents.durationText(step.endedAt - step.startedAt) : "" }
          if (k < stepModel.count && stepModel.get(k).key === step.id) stepModel.set(k, row)
          else stepModel.insert(k, row)
        }
      }

      add: Transition {
        ParallelAnimation {
          MotionAnimation { theme: pill.theme; property: "opacity"; from: 0; to: 1; pace: "fade"; curve: "fade" }
          MotionAnimation { theme: pill.theme; property: "y"; from: ViewTransition.destination.y + pill.agents.rowHeight; pace: "morph" }
        }
      }
      displaced: Transition {
        MotionAnimation { theme: pill.theme; property: "y"; pace: "morph" }
      }
      remove: Transition {
        ParallelAnimation {
          MotionAnimation { theme: pill.theme; property: "opacity"; to: 0; pace: "fade"; curve: "fade" }
          MotionAnimation { theme: pill.theme; property: "y"; to: -pill.agents.rowHeight; pace: "morph" }
        }
      }

      // A step: its mark in Clawd's column, its label (up to two lines)
      // in the title's. Running, a spinner and primary label; queued, an
      // empty circle; done, an outlined tick; the last two muted.
      delegate: Item {
        id: row
        required property string label
        required property string status
        required property string duration
        readonly property bool finished: status === "done" || status === "error"
        readonly property bool queued: status === "queued"
        width: steps.width
        height: Math.max(pill.agents.rowHeight, stepLabel.implicitHeight + 8)

        Item {
          x: 4
          y: Math.round((pill.agents.rowHeight - height) / 2)
          width: 16
          height: 16
          // All drawn with one stroke. Queued: an empty circle.
          Shape {
            anchors.fill: parent
            opacity: row.queued ? 1 : 0
            Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }
            visible: opacity > 0.01
            preferredRendererType: Shape.CurveRenderer
            Stroke {
              strokeColor: pill.grayInk
              PathAngleArc { centerX: 8; centerY: 8; radiusX: 6.6; radiusY: 6.6; startAngle: 0; sweepAngle: 360 }
            }
          }
          // Running (or thinking): an arc going round.
          Shape {
            anchors.fill: parent
            opacity: row.finished || row.queued ? 0 : 1
            Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }
            visible: opacity > 0.01
            preferredRendererType: Shape.CurveRenderer
            Stroke {
              strokeColor: pill.ink
              PathAngleArc { centerX: 8; centerY: 8; radiusX: 6.6; radiusY: 6.6; startAngle: -40; sweepAngle: 280 }
            }
            RotationAnimator on rotation {
              from: 0; to: 360
              duration: 1100
              loops: Animation.Infinite
              running: body.visible && !row.finished && !row.queued
            }
          }
          // Done: a circle with a tick drawing itself in, muted; failed, a
          // cross, red. A step that's already finished as it's first shown
          // starts drawn.
          Shape {
            id: doneMark
            anchors.fill: parent
            readonly property bool failed: row.status === "error"
            readonly property color tint: failed ? pill.errorInk : pill.grayInk
            property real draw: row.finished ? 1 : 0
            Behavior on draw { MotionAnimation { theme: pill.theme; pace: "morph" } }
            // The tick's two strokes in turn, the cross's together.
            readonly property real first: failed ? draw : Math.min(1, draw * 2)
            readonly property real second: failed ? draw : Math.max(0, draw * 2 - 1)
            opacity: Math.min(1, draw * 3)
            visible: draw > 0.01
            preferredRendererType: Shape.CurveRenderer
            Stroke {
              strokeColor: doneMark.tint
              PathAngleArc { centerX: 8; centerY: 8; radiusX: 6.6; radiusY: 6.6; startAngle: -90; sweepAngle: 360 * doneMark.draw }
            }
            Stroke {
              strokeColor: doneMark.tint
              startX: doneMark.failed ? 5.6 : 5
              startY: doneMark.failed ? 5.6 : 8.3
              PathLine {
                x: doneMark.failed ? 5.6 + 4.8 * doneMark.first : 5 + 2.1 * doneMark.first
                y: doneMark.failed ? 5.6 + 4.8 * doneMark.first : 8.3 + 2.2 * doneMark.first
              }
              PathLine {
                x: doneMark.failed ? 5.6 + 4.8 * doneMark.first : 7.1 + 4 * doneMark.second
                y: doneMark.failed ? 5.6 + 4.8 * doneMark.first : 10.5 - 4.9 * doneMark.second
              }
            }
            Stroke {
              strokeColor: doneMark.failed ? doneMark.tint : "transparent"
              startX: 10.4
              startY: 5.6
              PathLine { x: 10.4 - 4.8 * doneMark.second; y: 5.6 + 4.8 * doneMark.second }
            }
          }
        }
        Text {
          id: stepLabel
          x: 36
          y: 4
          width: Math.max(0, row.width - x - (took.visible ? took.implicitWidth + 8 : 0))
          text: row.label
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          lineHeight: 1.05
          color: row.finished || row.queued ? pill.grayInk : pill.textInk
          Behavior on color { MotionColorAnimation { theme: pill.theme } }
          font.family: pill.theme.textFontFamily
          font.pixelSize: pill.theme.size.title3
          font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.title3)
        }
        // How long it took, once it's finished, on its first line.
        Text {
          id: took
          visible: row.duration !== ""
          anchors.right: parent.right
          anchors.baseline: stepLabel.top
          anchors.baselineOffset: stepLabel.baselineOffset
          text: row.duration
          opacity: 0.8
          color: pill.grayInk
          font.family: pill.theme.textFontFamily
          font.pixelSize: pill.theme.size.callout
          font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.callout)
          font.features: { "tnum": 1 }
        }
      }
    }

    // The card for what it's doing now: what it's working on, how it's
    // going under that (a command's time, an edit's lines added and
    // removed), and a bar sweeping along the bottom while it runs.
    // Thinking, your prompt; done, its last words.
    Rectangle {
      id: card
      x: pill.width - pill.inset - width
      // Centred against the steps when they run taller than it.
      y: pill.contentTop + Math.max(4, Math.round((steps.contentHeight - height) / 2))
      Behavior on y { MotionAnimation { theme: pill.theme; pace: "morph" } }
      width: pill.cardWidth
      height: pill.cardHeight
      radius: 16
      // A subtle sheen over the island fill, lighter at the top, and a
      // theme-aware hairline rim.
      gradient: Gradient {
        GradientStop { position: 0; color: pill.theme.fill("subtle") }
        GradientStop { position: 1; color: pill.theme.fill("quiet") }
      }
      border.width: 1
      border.color: pill.theme.hairline
      readonly property var step: pill.step
      readonly property string kind: step ? step.kind : pill.agents.asking ? "ask" : pill.done ? "done" : "thinking"
      readonly property bool edit: kind === "edit"
      readonly property bool timed: kind === "run" || kind === "agent" || kind === "web"
      readonly property bool quote: kind === "thinking" || kind === "done" || kind === "ask"
      // A new step (or thinking, or done) fades its contents in, rising a
      // little, rather than swapping the text in place.
      readonly property string key: step ? step.id : kind
      property real swap: 1
      onKeyChanged: swapIn.restart()
      MotionAnimation {
        id: swapIn
        target: card
        property: "swap"
        from: 0
        to: 1
        theme: pill.theme
        pace: "morph"
      }

      // The same shape in every state, from the top: a title, then its
      // details.
      Column {
        id: cardText
        x: 15
        y: 14
        width: parent.width - 30
        spacing: 6
        opacity: card.swap
        transform: Translate { y: (1 - card.swap) * 4 }
        layer.enabled: card.swap < 0.99
        layer.effect: MultiEffect {
          blurEnabled: true
          blurMax: 16
          blur: (1 - card.swap) * 0.8
        }

        // Thinking, "Thinking", a light passing along it: each letter
        // shifting from muted grey toward primary text as the wave reaches
        // it, and fading back after.
        Row {
          id: thinkingWord
          visible: card.kind === "thinking"
          readonly property string word: "Thinking"
          property real wave: 0
          NumberAnimation on wave {
            from: -0.3; to: 1.3
            duration: 1600
            easing.type: Easing.InOutSine
            loops: Animation.Infinite
            running: body.visible && card.kind === "thinking"
          }
          Repeater {
            model: thinkingWord.word.length
            delegate: Text {
              required property int index
              readonly property real lit: Math.max(0, 1 - Math.abs(index / (thinkingWord.word.length - 1) - thinkingWord.wave) * 3)
              text: thinkingWord.word.charAt(index)
              // Shifted partway toward primary text at rest so it still
              // reads as the title above the prompt.
              color: Qt.tint(pill.grayInk, pill.theme.withAlpha(pill.textInk, 0.3 + 0.7 * lit))
              font.family: pill.theme.textFontFamily
              font.pixelSize: pill.theme.px(14)
              font.weight: Font.Medium
              font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.px(14))
            }
          }
        }
        // What it's working on: the command, the file, or what it's doing;
        // done, "Done".
        Item {
          width: parent.width
          height: cardTitle.implicitHeight
          visible: card.kind !== "thinking"
          Text {
            id: cardTitle
            width: Math.max(0, parent.width - (doneCounts.visible ? doneCounts.implicitWidth + 8 : 0))
            elide: card.kind === "run" ? Text.ElideRight : Text.ElideMiddle
            text: card.kind === "done" ? "Done"
              : card.kind === "ask" ? "Needs your input"
              : !card.step ? ""
              : card.kind === "run" ? (card.step.command || card.step.label || "")
              : (card.step.file || card.step.label || "")
            color: card.kind === "done" ? pill.grayInk : card.kind === "ask" ? pill.ink : pill.textInk
            font.family: card.quote ? pill.theme.textFontFamily : pill.theme.fontFamily
            font.pixelSize: pill.theme.px(14)
            font.letterSpacing: card.quote ? pill.theme.tracking(pill.theme.textFontFamily, pill.theme.px(14)) : 0
          }
          // Done, the turn's steps and the files it edited.
          Text {
            id: doneCounts
            readonly property var summary: pill.summary
            visible: card.kind === "done" && !!summary
            anchors.right: parent.right
            anchors.baseline: cardTitle.baseline
            text: !summary ? "" : summary.steps + (summary.steps === 1 ? " step" : " steps")
              + (summary.files ? " · " + summary.files + (summary.files === 1 ? " file" : " files") : "")
            color: pill.grayInk
            font.family: pill.theme.textFontFamily
            font.pixelSize: pill.theme.size.callout
            font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.callout)
          }
        }
        // How it's going.
        Item {
          width: parent.width
          height: 17
          visible: !card.quote
          Text {
            visible: !card.edit
            width: parent.width
            elide: Text.ElideRight
            text: card.timed && card.step ? pill.agents.timeText(pill.agents.now - card.step.startedAt)
              : ({ read: "Reading…", search: "Searching…" })[card.kind] || "Working…"
            color: pill.grayInk
            font.family: pill.theme.fontFamily
            font.pixelSize: pill.theme.px(14)
          }
          Diff {
            visible: card.edit
            added: card.edit && card.step ? card.step.added : 0
            removed: card.edit && card.step ? card.step.removed : 0
            size: 14
          }
        }
        // Done, the lines the turn's edits added and removed.
        Diff {
          visible: card.kind === "done" && !!pill.summary && pill.summary.added + pill.summary.removed > 0
          added: pill.summary ? pill.summary.added : 0
          removed: pill.summary ? pill.summary.removed : 0
          size: 13
        }
        // Thinking, the prompt it's working on; done, its last words.
        Text {
          width: parent.width
          readonly property string words: !pill.live ? ""
            : card.kind === "done" ? (pill.live.text || "")
            : card.kind === "ask" ? (card.step ? (card.step.question || card.step.label || "") : "Waiting on your response.")
            : (pill.live.prompt || "")
          visible: card.quote && words !== ""
          text: words
          wrapMode: Text.Wrap
          maximumLineCount: card.kind === "done" ? 2 : 3
          elide: Text.ElideRight
          color: pill.grayInk
          font.family: pill.theme.textFontFamily
          font.pixelSize: pill.theme.size.body
          font.letterSpacing: pill.theme.tracking(pill.theme.textFontFamily, pill.theme.size.body)
        }
      }

      // The bar, sweeping while a step runs.
      Item {
        x: 15
        width: parent.width - 30
        y: parent.height - 15 - height
        height: 5
        clip: true
        visible: !card.quote
        Rectangle { anchors.fill: parent; radius: 2.5; color: pill.theme.fill("raised") }
        Rectangle {
          id: sweep
          width: parent.width * 0.6
          height: parent.height
          radius: 2.5
          // A comet: a soft tail behind a solid head.
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: pill.theme.withAlpha(pill.ink, 0) }
            GradientStop { position: 0.65; color: pill.ink }
            GradientStop { position: 1; color: pill.ink }
          }
          NumberAnimation on x {
            from: -sweep.width; to: sweep.parent.width
            duration: 1800
            easing.type: Easing.InOutQuad
            loops: Animation.Infinite
            running: body.visible && !card.quote
          }
        }
      }
    }
  }

  AgentNotice {
    id: noticeItem
    anchors.fill: parent
    agents: pill.agents
    grow: pill.grow
  }

  // A line drawn in one stroke, as the step marks are.
  component Stroke: ShapePath {
    fillColor: "transparent"
    strokeWidth: 1.5
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
  }

  // Lines added and removed, then their DiffBar; the removed only when
  // there are some.
  component Diff: Row {
    property int added: 0
    property int removed: 0
    property real size: 14
    spacing: 8
    Text {
      visible: parent.added > 0 || parent.removed === 0
      text: "+" + parent.added
      color: pill.doneInk
      font.family: pill.theme.fontFamily
      font.pixelSize: pill.theme.px(parent.size)
    }
    Text {
      visible: parent.removed > 0
      text: "−" + parent.removed
      color: pill.errorInk
      font.family: pill.theme.fontFamily
      font.pixelSize: pill.theme.px(parent.size)
    }
    DiffBar {
      anchors.verticalCenter: parent.verticalCenter
      added: parent.added
      removed: parent.removed
    }
  }

  // An edit's size at a glance, as GitHub's: five blocks, green for the
  // share of lines added and red for those removed.
  component DiffBar: Row {
    property int added: 0
    property int removed: 0
    readonly property int green: added + removed > 0 ? Math.round(5 * added / (added + removed)) : 0
    spacing: 2
    Repeater {
      model: 5
      delegate: Rectangle {
        required property int index
        width: 7
        height: 7
        radius: 1.5
        color: index < parent.green ? pill.doneInk : pill.errorInk
      }
    }
  }
}
