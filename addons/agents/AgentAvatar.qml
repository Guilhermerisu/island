import QtQuick

// The mascot of the agent at work: Clawd for Claude Code, as Anthropic
// animates him (see clawd.py and ClawdSprite), and for Codex the pet picked in
// Codex or the ChatGPT desktop app (see pet.py), acted out from its
// spritesheet. Until a sheet is found or loaded, the built-in pixel Clawd
// (AgentsMascot) stands in for Claude Code, and Codex's logo for Codex. `mood` is the same as AgentsMascot's: "walk" (taking a
// step), "think", "wave" (waiting on you), "done" or "rest".
Item {
  id: avatar
  property string provider: "claude"
  // The pet's spritesheet and its grid of 192 × 208 pixel cells.
  property url sheet: ""
  property int cols: 8
  property int rows: 9
  property color color: "#d97757"
  property string mood: "rest"
  property bool running: true
  // Clawd's sheet, clawd.py's line (see ClawdSprite).
  property var clawd: null
  // The size of Clawd's pixels, when the built-in one is drawn.
  property real unit: 1
  // The icon font Codex's logo is drawn in, without a pet.
  property string fontFamily: ""
  // Frames each row of the sheet holds (they differ by row), then what the
  // pet does in each mood: rows idle, running-right/left, waving, jumping,
  // failed, waiting (a hand to its chin, then a wave: asking), running,
  // review.
  readonly property var frameCounts: [7, 8, 8, 4, 5, 8, 6, 6, 6]
  readonly property bool pet: provider === "codex" && sheet.toString() !== "" && atlas.status === Image.Ready
  readonly property bool original: provider === "claude" && clawdSprite.ready
  // Codex's logo drawn, for want of a pet.
  readonly property bool logo: provider === "codex" && !pet

  // Clawd's size is his body's, not his sheet's cell, which has room around
  // him for bubbles and props, so he sits centered where the avatar's put.
  readonly property var body: clawd && clawd.body ? clawd.body : [0, 0, 0, 0]
  implicitWidth: original ? (body[2] - body[0]) * clawdSprite.unit : 34
  implicitHeight: original ? (body[3] - body[1]) * clawdSprite.unit : 35

  // Asking, it bobs on the spot; done, it hops three times: the sheet's own
  // frames move little, so the whole figure moves too.
  property real hop: 0
  SequentialAnimation {
    running: avatar.running && avatar.mood === "wave"
    loops: Animation.Infinite
    onStopped: avatar.hop = 0
    NumberAnimation { target: avatar; property: "hop"; to: -3; duration: 200; easing.type: Easing.OutQuad }
    NumberAnimation { target: avatar; property: "hop"; to: 0; duration: 200; easing.type: Easing.InQuad }
    PauseAnimation { duration: 280 }
  }
  SequentialAnimation {
    running: avatar.running && avatar.mood === "done"
    loops: 3
    onStopped: avatar.hop = 0
    NumberAnimation { target: avatar; property: "hop"; to: -7; duration: 190; easing.type: Easing.OutQuad }
    NumberAnimation { target: avatar; property: "hop"; to: 0; duration: 190; easing.type: Easing.InQuad }
    PauseAnimation { duration: 60 }
  }

  Item {
    id: sprite
    anchors.fill: parent
    transform: Translate { y: avatar.hop }
    visible: avatar.pet
    clip: true

    // Thinking, the pet stands quietly, and every few seconds ponders once
    // (a hand to its chin) or peeks at its work, then stands again.
    property int loops: 0
    property bool gesture: false
    property bool peek: false
    property int idleLoops: 2
    readonly property int row: avatar.mood === "done" ? 4 : avatar.mood === "wave" ? 6
      : avatar.mood === "walk" ? 7
      : avatar.mood === "think" && gesture ? (peek ? 8 : 6) : 0
    readonly property int count: row < avatar.frameCounts.length ? avatar.frameCounts[row] : avatar.cols
    readonly property real cellScale: Math.min(width / 192, height / 208)
    property int frame: 0
    onRowChanged: frame = 0

    function restart() { loops = 0; gesture = false; idleLoops = 2; frame = 0 }
    Connections {
      target: avatar
      function onMoodChanged() { sprite.restart() }
      function onRunningChanged() { if (avatar.running) sprite.restart() }
    }
    // A frame every 125 ms (resting, slower), the island not repainting
    // between them; hopping when done a couple of times, then settling.
    Timer {
      interval: sprite.row === 0 ? 220 : 125
      repeat: true
      running: sprite.visible && avatar.running && (avatar.mood !== "done" || sprite.loops < 2)
      onTriggered: {
        if (sprite.frame + 1 >= sprite.count) {
          sprite.loops++
          if (avatar.mood === "think") {
            // Two to four quiet loops (about 3 to 6 seconds) between gestures.
            if (sprite.gesture) {
              sprite.gesture = false
              sprite.peek = !sprite.peek
              sprite.loops = 0
              sprite.idleLoops = 2 + Math.floor(Math.random() * 3)
            } else if (sprite.loops >= sprite.idleLoops) {
              sprite.gesture = true
              sprite.loops = 0
            }
          }
        }
        sprite.frame = (sprite.frame + 1) % sprite.count
      }
    }

    Image {
      id: atlas
      source: avatar.provider === "codex" ? avatar.sheet : ""
      asynchronous: true
      mipmap: true
      x: (sprite.width - 192 * sprite.cellScale) / 2 - sprite.frame * 192 * sprite.cellScale
      y: (sprite.height - 208 * sprite.cellScale) / 2 - sprite.row * 208 * sprite.cellScale
      width: avatar.cols * 192 * sprite.cellScale
      height: avatar.rows * 208 * sprite.cellScale
    }
  }

  ClawdSprite {
    id: clawdSprite
    x: -avatar.body[0] * unit
    y: -avatar.body[1] * unit
    visible: avatar.provider === "claude"
    sheet: avatar.clawd
    mood: avatar.mood
    running: avatar.running
  }

  AgentsMascot {
    anchors.centerIn: parent
    transform: Translate { y: avatar.hop }
    visible: avatar.provider !== "codex" && !avatar.original
    color: avatar.color
    unit: avatar.unit
    mood: avatar.mood
    running: avatar.running && visible
  }

  // Codex's logo, bobbing and hopping like a pet would. Its ink sits a pixel
  // right of the glyph's box (measured on screen), so it's drawn that much left.
  Text {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: -1
    transform: Translate { y: avatar.hop }
    visible: avatar.logo
    text: "\uec81"
    color: avatar.color
    font.family: avatar.fontFamily
    font.pixelSize: Math.round(Math.min(avatar.width, avatar.height) * 0.62)
  }
}
