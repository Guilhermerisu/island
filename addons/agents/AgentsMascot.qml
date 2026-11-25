import QtQuick

// Clawd, Claude Code's mascot, in pixels: a body with two tall eyes, an arm
// each side, and four legs, on a 24 × 15 grid of `unit` pixels. It moves
// in steps, as pixel art does, a frame every 150 ms while `running` (no
// animation of its own, which would repaint the island at the display's
// full rate). `mood` is "walk" (feet shuffling, the body bobbing with
// them), "think" (one of `moves` after another, see there), "wave" (an arm
// up, waving, to call you over), "done" (a hop, eyes squinting happily), or
// "rest"; it blinks now and then in any of them.
Item {
  id: clawd
  property var theme: null
  property color color: "#d97757"
  property color eyeColor: theme ? theme.background : "#000000"
  property string mood: "rest"
  property bool running: true
  property real unit: 1
  implicitWidth: 24 * unit
  implicitHeight: 15 * unit

  property int tick: 0
  onMoodChanged: { tick = 0; move = 0 }
  Timer {
    interval: 150
    repeat: true
    // Done, it hops once and settles.
    running: clawd.running && (clawd.mood !== "done" || clawd.tick < 6)
    onTriggered: {
      clawd.tick++
      // Thinking, a move at a time, each a different one from the last.
      if (clawd.mood === "think" && clawd.tick % 16 === 0) {
        var next = Math.floor(Math.random() * (clawd.moves.length - 1))
        clawd.move = next >= clawd.move ? next + 1 : next
      }
    }
  }

  // Thinking's moves, 16 frames each (2.4 s), from and back to standing
  // still, so one runs into the next. Each frame is an offset in grid
  // units: the eyes' (eyeX, eyeY), squinting them (squint), each arm up
  // or down (armL, armR), the right foot tapped up (tap), and the body
  // leaning over its planted feet (lean).
  readonly property var moves: [
    // Glancing one way, then the other.
    { eyeX: [0, 0, -1, -1, -1, -1, -1, 0, 0, 1, 1, 1, 1, 1, 0, 0] },
    // Pondering: eyes drifting up and over.
    { eyeY: [0, 0, -1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -1, 0, 0],
      eyeX: [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0] },
    // Scratching its head, looking up at the arm doing it.
    { armR: [0, -1, -2, -3, -2, -3, -2, -3, -2, -3, -2, -3, -2, -1, 0, 0],
      eyeX: [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
      eyeY: [0, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 0] },
    // Tapping a foot, looking down at it.
    { tap: [0, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 0, 0, 0, 0],
      eyeX: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
      eyeY: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0] },
    // Swaying from side to side.
    { lean: [0, 0, 1, 1, 1, 1, 0, 0, -1, -1, -1, -1, 0, 0, 0, 0],
      eyeX: [0, 0, 1, 1, 1, 1, 0, 0, -1, -1, -1, -1, 0, 0, 0, 0] },
    // "Hmm": squinting, looking aside.
    { squint: [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
      eyeX: [0, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0] },
    // Fidgeting: arms bobbing in turn.
    { armL: [0, -1, 0, 1, 0, -1, 0, 1, 0, -1, 0, 1, 0, 0, 0, 0],
      armR: [0, 1, 0, -1, 0, 1, 0, -1, 0, 1, 0, -1, 0, 0, 0, 0] }
  ]
  property int move: 0
  function frame(key) {
    var track = mood === "think" ? moves[move][key] : null
    return track ? track[tick % 16] : 0
  }

  readonly property int phase: tick % 4
  // Walking, its feet shuffle a pixel one way, then the other, the body
  // bobbing up a pixel as they land.
  readonly property int step: mood === "walk" ? [0, 1, 0, -1][phase] : 0
  readonly property real lift: mood === "walk" ? (phase % 2 === 0 ? 1 : 0)
    : mood === "done" ? [0, 2, 3, 2, 0, 0][Math.min(tick, 5)] : 0
  readonly property int eyeX: frame("eyeX")
  readonly property int eyeY: frame("eyeY")
  readonly property int lean: frame("lean")
  // Waving, the right arm raised, going up and down.
  readonly property int armR: mood === "wave" ? [-3, -4, -3, -2][phase] : frame("armR")
  readonly property bool squint: frame("squint") > 0
  readonly property bool blink: mood !== "done" && !squint && tick % 24 === 23
  readonly property bool happy: mood === "done"

  // It all moves together. Walking, the legs stretch to keep it on the
  // ground; hopping, they leave it with the body.
  readonly property real reach: mood === "walk" ? lift : 0
  Item {
    width: parent.width
    height: parent.height
    x: clawd.lean * clawd.unit
    y: -clawd.lift * clawd.unit
    Pixel { gx: 4; gy: 0; w: 16; h: 11 }
    Pixel { gx: 0; gy: 3 + clawd.frame("armL"); w: 4; h: 4 }
    Pixel { gx: 20; gy: 3 + clawd.armR; w: 4; h: 4 }
    // Closed to a line to blink; squinting, shorter, as ^ ^ (happy) or a
    // narrowed look (thinking).
    Eye { at: 7 }
    Eye { at: 15 }
    // The feet stay put as the body leans over them.
    Pixel { gx: 5 + clawd.step - clawd.lean; gy: 11; w: 2; h: 4 + clawd.reach }
    Pixel { gx: 9 + clawd.step - clawd.lean; gy: 11; w: 2; h: 4 + clawd.reach }
    Pixel { gx: 13 + clawd.step - clawd.lean; gy: 11; w: 2; h: 4 + clawd.reach }
    Pixel { gx: 17 + clawd.step - clawd.lean; gy: 11; w: 2; h: 4 + clawd.reach - clawd.frame("tap") }
  }

  component Eye: Pixel {
    property int at: 0
    gx: at + clawd.eyeX
    w: 2
    color: clawd.eyeColor
    gy: clawd.blink ? 6 : clawd.squint ? 4 + clawd.eyeY : 3 + clawd.eyeY
    h: clawd.blink ? 1 : clawd.happy || clawd.squint ? 2 : 4
  }

  // A block of the grid's pixels, placed and sized in grid units.
  component Pixel: Rectangle {
    property real gx: 0
    property real gy: 0
    property real w: 1
    property real h: 1
    x: gx * clawd.unit
    y: gy * clawd.unit
    width: w * clawd.unit
    height: h * clawd.unit
    antialiasing: false
    color: clawd.color
  }
}
