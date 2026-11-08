import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import ".."

// Displays: macOS's System Settings → Displays as a pane in Settings (see
// DisplaysPage). The monitors are read from `hyprctl monitors all -j` while
// Settings is open, and again whenever one is plugged in or removed.
//
// The pane edits `draft`, a copy of the monitors as they are (`original`);
// Apply sends the changed ones to Hyprland (`hyprctl eval` of hl.monitor
// calls) and asks on the island whether to keep them (KeepPill). Keep writes them to
// monitors.lua (monitors.py); Revert, or ten seconds without an answer,
// sends the old ones back.
Addon {
  id: displaysAddon
  settingsPages: [{
    title: "Displays",
    source: Qt.resolvedUrl("DisplaysPage.qml"), properties: { displays: displaysAddon },
    about: "Arrange your monitors and set how they look.",
    search: "displays monitors screens arrangement arrange resolution refresh rate hz scale scaling larger text more space rotation rotate portrait enable disable turn off hdr high dynamic range color colour profile 10-bit night shift brightness text size font hyprland"
  }]

  // The question, on the resting island in place of the clock.
  pill: Component { KeepPill { displays: displaysAddon } }
  ongoing: confirming
  pillAsks: true
  pillWidth: 360
  pillHeight: 108
  function pillClicked() {}

  readonly property string configPath: host.home + "/.config/hypr/monitors.lua"
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("monitors.py")).replace("file://", ""))

  // Or a zone of the control center is on screen (see zoneViews in Addon.qml).
  readonly property bool watching: host.view === "settings" || zoneViews > 0
  // Edits left pending when Settings closed are dropped, as macOS does.
  onWatchingChanged: if (watching) { refresh(true); readBrightness(); readTextSize(); wallpaperRead.running = true }
  // Read once at start too, so a monitor kept in HDR pauses Night Shift
  // (see below) from login on.
  Component.onCompleted: { refresh(true); wallpaperRead.running = true }

  // The wallpaper's real file, as the previews show it: omarchy's own path is
  // a link that stays the same when the wallpaper changes, so it couldn't be
  // cached, and the previews wouldn't know to load the new one.
  property string wallpaper: ""
  Process {
    id: wallpaperRead
    command: ["readlink", "-f", displaysAddon.host.home + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector { onStreamFinished: displaysAddon.wallpaper = String(text).trim() }
  }

  // Every monitor, as the pane edits it (see entryFrom): `original` as they
  // are, `draft` with the pending edits; empty before the first read.
  property var original: []
  property var draft: []
  property bool loaded: false
  readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(original)
  property string selected: ""
  readonly property var selectedEntry: find(draft, selected)
  readonly property var enabledCount: draft.filter(function(e) { return !e.disabled }).length

  function find(list, name) {
    for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
    return null
  }
  function copy(value) { return JSON.parse(JSON.stringify(value)) }

  // ---------- Reading ----------

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (/^monitor(added|removed)/.test(event.name)) displaysAddon.refresh(false)
    }
  }
  property bool rerun: false
  property bool rerunReset: false
  property bool resetNext: false
  Process {
    id: reader
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { displaysAddon.take(JSON.parse(text), displaysAddon.resetNext) } catch (e) {}
      }
    }
    onExited: if (displaysAddon.rerun) { displaysAddon.rerun = false; displaysAddon.refresh(displaysAddon.rerunReset) }
  }
  // `reset` drops pending edits; otherwise they're kept unless the monitors
  // plugged in changed.
  function refresh(reset) {
    if (reader.running) { rerun = true; rerunReset = rerunReset || !!reset; return }
    rerunReset = false
    resetNext = !!reset
    reader.running = true
  }
  function take(list, reset) {
    var next = list.map(entryFrom).sort(function(a, b) { return a.name < b.name ? -1 : 1 })
    var sameSet = next.map(function(e) { return e.name }).join() === original.map(function(e) { return e.name }).join()
    var keep = !reset && dirty && sameSet
    // Only when they differ: a new list rebuilds every preview drawn from it.
    var json = JSON.stringify(next)
    if (json !== JSON.stringify(original)) original = next
    if (!keep && json !== JSON.stringify(draft)) draft = copy(next)
    // No HDR left (turned off, or reverted): Night Shift back, if paused.
    if (!anyHdr && !confirming) resumeNight()
    loaded = true
    if (!find(draft, selected)) {
      var focused = next.filter(function(e) { return e.focused })[0]
      selected = focused ? focused.name : next.length ? next[0].name : ""
    }
  }

  // A monitor from hyprctl: its connector name, a title (the model, as
  // macOS names displays), its mode (rate as hyprctl lists it, "359.98"),
  // scale, transform, layout position, and the modes it offers.
  function entryFrom(m) {
    var modes = []
    var seen = {}
    ;(m.availableModes || []).forEach(function(text) {
      var r = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(text)
      if (!r || seen[text]) return
      seen[text] = true
      modes.push({ width: Number(r[1]), height: Number(r[2]), rate: r[3] })
    })
    var width = m.width, height = m.height
    // A monitor that's off may report no mode: its largest then.
    if (!(width > 0 && height > 0) && modes.length) {
      var largest = resolutionsOf(modes)[0]
      width = largest.width
      height = largest.height
    }
    return {
      name: String(m.name),
      title: String(m.model || m.name),
      maker: String(m.make || ""),
      width: width, height: height,
      rate: nearestRate(modes, width, height, m.refreshRate),
      scale: Number(Number(m.scale || 1).toFixed(6)),
      transform: Number(m.transform || 0),
      x: Math.round(m.x || 0), y: Math.round(m.y || 0),
      disabled: !!m.disabled,
      focused: !!m.focused,
      physicalWidth: Number(m.physicalWidth || 0), physicalHeight: Number(m.physicalHeight || 0),
      // Colour: 10 bits a channel when its format packs 2-10-10-10, the
      // colour management preset ("srgb", "wide", "hdr"…), and SDR's
      // brightness and saturation under HDR.
      bitdepth: /2101010/.test(String(m.currentFormat || "")) ? 10 : 8,
      cm: String(m.colorManagementPreset || "srgb"),
      sdrBrightness: Number(Number(m.sdrBrightness === undefined ? 1 : m.sdrBrightness).toFixed(2)),
      sdrSaturation: Number(Number(m.sdrSaturation === undefined ? 1 : m.sdrSaturation).toFixed(2)),
      modes: modes
    }
  }
  function nearestRate(modes, width, height, rate) {
    var best = "", gap = Infinity
    modes.forEach(function(mode) {
      if (mode.width !== width || mode.height !== height) return
      var d = Math.abs(Number(mode.rate) - rate)
      if (d < gap) { gap = d; best = mode.rate }
    })
    if (best !== "") return best
    var all = ratesOf(modes, width, height)
    return all.length && !(rate > 0) ? all[0] : Number(rate || 60).toFixed(2)
  }

  // ---------- Modes and scales ----------

  // The distinct resolutions, largest first.
  function resolutionsOf(modes) {
    var result = [], seen = {}
    modes.forEach(function(mode) {
      var key = mode.width + "x" + mode.height
      if (seen[key]) return
      seen[key] = true
      result.push({ width: mode.width, height: mode.height })
    })
    return result.sort(function(a, b) { return b.width * b.height - a.width * a.height || b.width - a.width })
  }
  // A resolution's refresh rates, fastest first.
  function ratesOf(modes, width, height) {
    var result = []
    modes.forEach(function(mode) {
      if (mode.width === width && mode.height === height && result.indexOf(mode.rate) === -1) result.push(mode.rate)
    })
    return result.sort(function(a, b) { return Number(b) - Number(a) })
  }
  // Scales Hyprland takes for a resolution: whole logical pixels, in the
  // 1/120 steps of fractional scaling, from 1 up to 3 or a logical width of
  // 1024, whichever is less.
  function validScales(width, height) {
    var result = []
    var most = Math.max(1, Math.min(3, width / 1024))
    for (var k = 120; k <= 360 && k / 120 <= most + 1e-9; k++)
      if ((width * 120) % k === 0 && (height * 120) % k === 0) result.push(Number((k / 120).toFixed(6)))
    return result.length ? result : [1]
  }
  function nearest(list, value) {
    var best = list[0]
    list.forEach(function(v) { if (Math.abs(v - value) < Math.abs(best - value)) best = v })
    return best
  }
  // Hyprland's own pick when no scale is set: 2 over 200 pixels per inch,
  // 1.5 over 140, else 1; here snapped to the scales it takes.
  function defaultScale(entry, width, height) {
    var inches = Math.sqrt(Math.pow(entry.physicalWidth, 2) + Math.pow(entry.physicalHeight, 2)) / 25.4
    var ppi = inches > 0 ? Math.sqrt(width * width + height * height) / inches : 0
    return nearest(validScales(width, height), ppi > 200 ? 2 : ppi > 140 ? 1.5 : 1)
  }
  // Up to five scales from Larger Text (largest) to More Space, spread
  // evenly (in ratio) over the ones it takes, with the default and the
  // current scale always among them.
  function scaleChoices(entry, width, height) {
    var valid = validScales(width, height)
    var fallback = defaultScale(entry, width, height)
    var picks = []
    if (valid.length <= 5) picks = valid.slice()
    else {
      var lo = valid[0], hi = valid[valid.length - 1]
      for (var i = 0; i < 5; i++) {
        var pick = nearest(valid, lo * Math.pow(hi / lo, i / 4))
        if (picks.indexOf(pick) === -1) picks.push(pick)
      }
    }
    var must = [fallback]
    if (entry.width === width && entry.height === height) must.push(Number(entry.scale.toFixed(6)))
    must.forEach(function(scale) {
      if (picks.some(function(p) { return Math.abs(p - scale) < 1e-4 })) return
      if (picks.length < 5) { picks.push(scale); return }
      // In place of the nearest pick that isn't also a must.
      var at = -1
      picks.forEach(function(p, j) {
        if (must.some(function(m) { return Math.abs(m - p) < 1e-4 })) return
        if (at < 0 || Math.abs(p - scale) < Math.abs(picks[at] - scale)) at = j
      })
      if (at >= 0) picks[at] = scale
    })
    return picks.sort(function(a, b) { return b - a }).map(function(scale) {
      return { scale: scale, width: Math.round(width / scale), height: Math.round(height / scale),
               isDefault: Math.abs(scale - fallback) < 1e-4 }
    })
  }

  // A monitor's box in the layout, in logical pixels, turned with it.
  function box(entry) {
    var w = Math.round(entry.width / entry.scale), h = Math.round(entry.height / entry.scale)
    if (entry.transform % 2 === 1) { var t = w; w = h; h = t }
    return { x: entry.x, y: entry.y, w: w, h: h }
  }

  // ---------- Editing ----------

  function edit(name, change) {
    var next = copy(draft)
    var entry = find(next, name)
    if (!entry) return
    var before = box(entry)
    var wasOn = !entry.disabled
    change(entry)
    if (!entry.disabled && wasOn) {
      // Neighbours right of or below a box that grew or shrank move with
      // its edge, as macOS keeps the arrangement.
      var after = box(entry)
      next.forEach(function(other) {
        if (other === entry || other.disabled) return
        if (other.x >= before.x + before.w) other.x += after.w - before.w
        if (other.y >= before.y + before.h) other.y += after.h - before.h
      })
    }
    draft = settle(next, entry.disabled ? "" : name)
  }
  function setResolution(name, width, height) {
    edit(name, function(entry) {
      var rates = ratesOf(entry.modes, width, height)
      entry.rate = rates.indexOf(entry.rate) !== -1 ? entry.rate : rates[0] || entry.rate
      if (!validScales(width, height).some(function(s) { return Math.abs(s - entry.scale) < 1e-4 }))
        entry.scale = defaultScale(entry, width, height)
      entry.width = width
      entry.height = height
    })
  }
  function setRate(name, rate) { edit(name, function(entry) { entry.rate = rate }) }
  function setScale(name, scale) { edit(name, function(entry) { entry.scale = scale }) }
  // A flipped monitor (transforms 4–7) stays flipped.
  function setRotation(name, quarter) {
    edit(name, function(entry) { entry.transform = quarter + (entry.transform >= 4 ? 4 : 0) })
  }
  // The last monitor on stays on.
  function setEnabled(name, on) {
    var entry = find(draft, name)
    if (!entry || (!on && !entry.disabled && enabledCount <= 1)) return
    edit(name, function(e) { e.disabled = !on })
  }
  // HDR is the "hdr" preset (or "hdredid", over the display's own
  // primaries), at 10 bits; turned off, the preset it had before comes back.
  function isHdr(entry) { return !!entry && /^hdr/.test(entry.cm) }
  property var sdrPresets: ({})
  function setHdr(name, on) {
    edit(name, function(entry) {
      if (on === isHdr(entry)) return
      if (on) {
        var kept = Object.assign({}, sdrPresets)
        kept[name] = { cm: entry.cm, bitdepth: entry.bitdepth }
        sdrPresets = kept
        entry.cm = entry.cm === "edid" ? "hdredid" : "hdr"
        entry.bitdepth = 10
      } else {
        var was = sdrPresets[name] || { cm: entry.cm === "hdredid" ? "edid" : "srgb", bitdepth: entry.bitdepth }
        entry.cm = was.cm
        entry.bitdepth = was.bitdepth
      }
    })
  }
  function setColorMode(name, cm) { edit(name, function(entry) { entry.cm = cm }) }
  function setBitDepth(name, bits) { edit(name, function(entry) { entry.bitdepth = bits }) }
  function setSdrBrightness(name, v) { edit(name, function(entry) { entry.sdrBrightness = v }) }
  function setSdrSaturation(name, v) { edit(name, function(entry) { entry.sdrSaturation = v }) }
  function move(name, x, y) {
    edit(name, function(entry) { entry.x = Math.round(x); entry.y = Math.round(y) })
  }
  function discard() { draft = copy(original) }

  // The layout made whole: no box overlapping another, and each touching
  // one along an edge. Boxes are placed nearest the origin first, `last`
  // after the rest; one that doesn't fit where it is goes to the nearest
  // spot against an edge of one already placed.
  function settle(list, last) {
    var on = list.filter(function(e) { return !e.disabled })
    on.sort(function(a, b) {
      if (a.name === last) return 1
      if (b.name === last) return -1
      return Math.abs(a.x) + Math.abs(a.y) - Math.abs(b.x) - Math.abs(b.y)
    })
    var placed = []
    on.forEach(function(entry) {
      var b = box(entry)
      if (placed.length && !(touchesAny(b, placed) && !overlapsAny(b, placed))) {
        var spot = attach(b, placed)
        entry.x = spot.x
        entry.y = spot.y
        b = box(entry)
      }
      placed.push(b)
    })
    return list
  }
  function overlaps(a, b) { return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h }
  function overlapsAny(b, boxes) { return boxes.some(function(o) { return overlaps(b, o) }) }
  function touches(a, b) {
    var sideBySide = (a.x + a.w === b.x || b.x + b.w === a.x) && a.y < b.y + b.h && b.y < a.y + a.h
    var stacked = (a.y + a.h === b.y || b.y + b.h === a.y) && a.x < b.x + b.w && b.x < a.x + a.w
    return sideBySide || stacked
  }
  function touchesAny(b, boxes) { return boxes.some(function(o) { return touches(b, o) }) }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function attach(b, boxes) {
    var best = null, gap = Infinity
    boxes.forEach(function(o) {
      var alongY = clamp(b.y, o.y - b.h + 1, o.y + o.h - 1)
      var alongX = clamp(b.x, o.x - b.w + 1, o.x + o.w - 1)
      ;[{ x: o.x + o.w, y: alongY }, { x: o.x - b.w, y: alongY },
        { x: alongX, y: o.y + o.h }, { x: alongX, y: o.y - b.h }].forEach(function(spot) {
        var moved = { x: spot.x, y: spot.y, w: b.w, h: b.h }
        if (overlapsAny(moved, boxes)) return
        var d = Math.hypot(spot.x - b.x, spot.y - b.y)
        if (d < gap) { gap = d; best = spot }
      })
    })
    if (best) return best
    // Boxed in on every side: to the right of everything.
    var right = Math.max.apply(null, boxes.map(function(o) { return o.x + o.w }))
    var top = Math.min.apply(null, boxes.map(function(o) { return o.y }))
    return { x: right, y: top }
  }

  // ---------- Applying ----------

  function monitorSpec(entry) {
    return {
      output: entry.name,
      mode: entry.width + "x" + entry.height + "@" + entry.rate,
      position: entry.x + "x" + entry.y,
      scale: entry.scale,
      transform: entry.transform,
      disabled: entry.disabled,
      bitdepth: entry.bitdepth,
      cm: entry.cm,
      sdrbrightness: entry.sdrBrightness,
      sdrsaturation: entry.sdrSaturation
    }
  }
  function changedNames() {
    return draft.filter(function(entry) {
      var was = find(original, entry.name)
      return !was || JSON.stringify(monitorSpec(was)) !== JSON.stringify(monitorSpec(entry))
    }).map(function(entry) { return entry.name })
  }
  function specs(list, names) {
    return list.filter(function(e) { return names.indexOf(e.name) !== -1 }).map(monitorSpec)
  }

  // Set while the Keep dialog is up: the monitors as they were, and as
  // applied.
  property var previous: []
  property var applied: []
  readonly property bool confirming: applied.length > 0
  property int secondsLeft: 0

  function apply() {
    var names = changedNames()
    if (!names.length || confirming) return
    previous = specs(original, names)
    applied = specs(draft, names)
    // Night Shift off before HDR comes on, so it never flashes yellow.
    if (applied.some(function(m) { return !m.disabled && /^hdr/.test(m.cm) })) pauseNight()
    // The island leaves Settings to ask, at rest; it comes back to this pane
    // once answered.
    host.view = "rest"
    send(applied)
    secondsLeft = 10
    countdown.restart()
  }
  function keep() {
    if (!confirming) return
    countdown.stop()
    saver.command = ["python3", helper, "save", configPath, JSON.stringify(applied)]
    saver.running = true
    previous = []
    applied = []
    host.openSettings("Displays")
  }
  function revert() {
    if (!confirming) return
    countdown.stop()
    send(previous)
    previous = []
    applied = []
    host.openSettings("Displays")
  }
  Timer {
    id: countdown
    interval: 1000
    repeat: true
    onTriggered: {
      displaysAddon.secondsLeft--
      if (displaysAddon.secondsLeft <= 0) displaysAddon.revert()
    }
  }
  // The hl.monitor calls, each keeping its line's extra fields, run in
  // Hyprland; a reset read follows.
  property var queued: null
  function send(list) {
    if (sender.running) { queued = list; return }
    sender.command = ["bash", "-c", 'lua=$(python3 "$1" lua "$2" "$3") && hyprctl eval "$lua"', "bash",
                      helper, configPath, JSON.stringify(list)]
    sender.running = true
  }
  Process {
    id: sender
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("displays addon:", text.trim())
    }
    onExited: {
      if (displaysAddon.queued) { var list = displaysAddon.queued; displaysAddon.queued = null; displaysAddon.send(list); return }
      settleRead.restart()
    }
  }
  // A moment for Hyprland to set the new modes before reading them back.
  Timer { id: settleRead; interval: 400; onTriggered: displaysAddon.refresh(true) }
  Process {
    id: saver
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("displays addon:", text.trim())
    }
  }

  // ---------- Night Shift under HDR ----------

  // Night Shift's warm filter turns the screen yellow under HDR, so while
  // any monitor is in HDR hyprsunset is stopped (its socket can't be relied
  // on to set it to neutral), and once none is (on the next read of the
  // monitors) it's started again, if this addon stopped it. A file in the
  // runtime directory remembers that across restarts of the shell, and is
  // gone by the next login.
  readonly property bool anyHdr: original.some(function(e) { return !e.disabled && isHdr(e) })
  onAnyHdrChanged: if (anyHdr) pauseNight()
  readonly property string nightMark: '"${XDG_RUNTIME_DIR:-/tmp}/island-displays-night-paused"'
  function pauseNight() {
    Quickshell.execDetached(["bash", "-c", "pgrep -x hyprsunset >/dev/null || exit 0; pkill -x hyprsunset && touch " + nightMark])
  }
  function resumeNight() {
    Quickshell.execDetached(["bash", "-c", "[ -e " + nightMark + " ] || exit 0; rm -f " + nightMark + "; omarchy-restart-hyprsunset"])
  }

  // ---------- Brightness and text size ----------

  // Both set at once, as macOS's sliders, not held for Apply. Brightness is
  // the picked monitor's, through Omarchy (a backlight, an Apple display,
  // or DDC/CI), or -1 when it has none to set.
  property int brightness: -1
  onSelectedChanged: readBrightness()
  function readBrightness() {
    if (!selected) { brightness = -1; return }
    brightnessRead.command = ["omarchy-brightness-display", "--monitor", selected]
    brightnessRead.running = true
  }
  Process {
    id: brightnessRead
    stdout: StdioCollector {
      onStreamFinished: {
        var v = parseInt(String(text).trim(), 10)
        displaysAddon.brightness = isNaN(v) ? -1 : Math.max(1, Math.min(100, v))
      }
    }
    onExited: function(code) { if (code !== 0) displaysAddon.brightness = -1 }
  }
  // Set while dragging: the latest value waits for the one before to land.
  property int brightnessWanted: -1
  function setBrightness(percent) {
    brightness = Math.max(1, Math.min(100, Math.round(percent)))
    brightnessWanted = brightness
    if (!brightnessWrite.running) writeBrightness()
  }
  function writeBrightness() {
    brightnessWrite.command = ["omarchy-brightness-display", "--no-osd", "--monitor", selected, brightnessWanted + "%"]
    brightnessWanted = -1
    brightnessWrite.running = true
  }
  Process {
    id: brightnessWrite
    onExited: if (displaysAddon.brightnessWanted >= 0) displaysAddon.writeBrightness()
  }

  // Text size, in px, across the shell, GTK apps, and terminals (Omarchy's
  // omarchy-display-text-size), snapped to its panel's stops.
  readonly property var textStops: [9, 10, 11, 12, 14, 16, 20]
  property int textSize: 12
  function readTextSize() { textRead.running = true }
  Process {
    id: textRead
    command: ["omarchy-display-text-size"]
    stdout: StdioCollector {
      onStreamFinished: {
        var r = /text size:\s*(\d+)/.exec(text)
        if (r) displaysAddon.textSize = Number(r[1])
      }
    }
  }
  property int textWanted: 0
  function setTextSize(px) {
    if (px === textSize && !textWrite.running) return
    textSize = px
    textWanted = px
    if (!textWrite.running) writeTextSize()
  }
  function writeTextSize() {
    textWrite.command = ["omarchy-display-text-size", String(textWanted)]
    textWanted = 0
    textWrite.running = true
  }
  Process {
    id: textWrite
    onExited: displaysAddon.textWanted ? displaysAddon.writeTextSize() : displaysAddon.readTextSize()
  }
}
