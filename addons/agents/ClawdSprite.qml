import QtQuick

// Clawd as Anthropic animates him, from the sheet clawd.py paints out of the
// Claude desktop app's own sprites: a row for each animation, `rows` naming
// them. `mood` is AgentsMascot's: "walk" (at his laptop, working a step),
// "think" (standing, now and then a thought, a glance, a sway or a bright
// idea), "wave" (waving, to call you over), "done" (a dance, then standing),
// or "rest". The frames come at the 12 a second his own clips are made for.
Item {
  id: clawd
  // clawd.py's line: { source, cellW, cellH, cols, rows }.
  property var sheet: null
  property string mood: "rest"
  property bool running: true
  // The size of a pixel of his: a cell's 36 × 32 fits the pill and the banner's tile.
  property real unit: 1
  readonly property bool ready: !!sheet && image.status === Image.Ready
  implicitWidth: sheet ? sheet.cellW * unit : 0
  implicitHeight: sheet ? sheet.cellH * unit : 0

  // His clips, as the Claude app plays them: the animation's row and its
  // frames from and to.
  readonly property var clips: ({
    stand: { row: "Thinking", from: 0, to: 0 },
    laptopIn: { row: "Laptop", from: 2, to: 16 },
    laptopLoop: { row: "Laptop", from: 17, to: 33, loop: true },
    wave: { row: "Waving", from: 3, to: 16 },
    dance: { row: "DancingHappy", from: 4, to: 38 },
    thinking: { row: "Thinking", from: 2, to: 36 },
    look: { row: "LookingAround", from: 4, to: 30 },
    sway: { row: "Swaying", from: 4, to: 48 },
    bulb: { row: "Lightbulb", from: 2, to: 48 }
  })
  readonly property var thoughts: ["thinking", "look", "sway", "bulb"]
  property string clip: "stand"
  property int frame: 0
  // Ticks he stands for before the next thing (-1: for good).
  property int wait: -1
  property string lastThought: ""

  function play(name) { clip = name; frame = clips[name].from }
  function stand(ticks) { clip = "stand"; frame = 0; wait = ticks }
  function begin() {
    if (mood === "walk") play("laptopIn")
    else if (mood === "wave") play("wave")
    else if (mood === "done") play("dance")
    else stand(mood === "think" ? 30 : -1)
  }
  // Thinking, he stands for 4 to 9 seconds between thoughts, never the same
  // one twice running.
  function next() {
    if (mood === "wave") { play("wave"); return }
    var options = thoughts.filter(function(t) { return t !== lastThought })
    lastThought = options[Math.floor(Math.random() * options.length)]
    play(lastThought)
  }
  function finished() {
    if (clip === "laptopIn") play("laptopLoop")
    else if (mood === "think") stand(48 + Math.floor(Math.random() * 60))
    else if (mood === "wave") stand(14)
    else stand(-1)
  }
  onMoodChanged: begin()
  // Starting again (a new banner, the pill back), he acts it out afresh.
  onRunningChanged: if (running) begin()
  Component.onCompleted: begin()

  Timer {
    interval: 83
    repeat: true
    running: clawd.visible && clawd.running && clawd.ready && (clawd.clip !== "stand" || clawd.wait >= 0)
    onTriggered: {
      if (clawd.clip === "stand") {
        if (clawd.wait > 0) clawd.wait--
        else clawd.next()
        return
      }
      var c = clawd.clips[clawd.clip]
      if (++clawd.frame > c.to) {
        if (c.loop) clawd.frame = c.from
        else clawd.finished()
      }
    }
  }

  Item {
    anchors.fill: parent
    clip: true
    Image {
      id: image
      source: clawd.sheet ? clawd.sheet.source : ""
      asynchronous: true
      smooth: false
      mipmap: false
      readonly property int row: clawd.sheet ? Math.max(0, clawd.sheet.rows.indexOf(clawd.clips[clawd.clip].row)) : 0
      x: clawd.sheet ? -clawd.frame * clawd.sheet.cellW * clawd.unit : 0
      y: clawd.sheet ? -row * clawd.sheet.cellH * clawd.unit : 0
      width: clawd.sheet ? clawd.sheet.cols * clawd.sheet.cellW * clawd.unit : 0
      height: clawd.sheet ? clawd.sheet.rows.length * clawd.sheet.cellH * clawd.unit : 0
    }
  }
}
