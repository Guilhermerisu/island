import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../controls"

// Settings → Keybinds: the island's shortcuts from companion/bindings.sh, and
// recording new ones. Addons' shortcuts aren't listed here: they're set in
// each addon's options on the Addons page, through this page's recorder.
// While recording, Hyprland is switched to an empty submap so its own
// bindings don't take the keys.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "Keybinds"
  Layout.fillWidth: true
  spacing: 20

  // Loaded when the page (or Addons, which shows each addon's shortcuts)
  // opens; recording and a pending conflict end when it closes.
  readonly property bool shown: view.active && (view.currentPage === "Keybinds" || view.currentPage === "Addons")
  onShownChanged: {
    if (shown) { shortcutList.running = true; boundList.running = true }
    else { stopRecording(); cancelPending() }
  }
  Component.onDestruction: if (recordingId !== "") submapReset.running = true

  readonly property string bindingsScript: view.host.setup.companionDir + "/bindings.sh"
  property var shortcuts: []
  property string recordingId: ""
  property string recordHint: ""
  property string pendingId: ""
  property string pendingKeys: ""
  property string pendingConflict: ""
  property var setQueue: []

  Process {
    id: shortcutList
    command: ["bash", page.bindingsScript, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = []
        String(text || "").split("\n").forEach(function(line) {
          var cols = line.split("\t")
          if (cols.length >= 2 && cols[0]) list.push({ id: cols[0], label: cols[1], keys: cols[2] || "", command: cols[3] || "", addon: cols[4] || "" })
        })
        page.shortcuts = list
      }
    }
  }
  Process {
    id: shortcutSet
    onExited: page.runNextSet()
  }
  // Every live binding, so a conflict shows the moment the keys are typed.
  property var liveBindings: []
  Process {
    id: boundList
    command: ["bash", page.bindingsScript, "bound"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        page.liveBindings = String(text || "").split("\n").filter(function(line) { return line !== "" })
          .map(function(line) {
            var cols = line.split("\t")
            return { keys: cols[0], description: cols[1] || "", command: cols.slice(2).join("\t") }
          })
      }
    }
  }
  Process { id: submapEnter; command: ["hyprctl", "dispatch", "hl.dsp.submap(\"island-record\")"] }
  Process { id: submapReset; command: ["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"] }
  Timer {
    id: recordTimeout
    interval: 10000
    onTriggered: page.stopRecording()
  }

  function setShortcut(id, keys) {
    shortcuts = shortcuts.map(function(entry) {
      if (entry.id === id) return { id: entry.id, label: entry.label, keys: keys, command: entry.command, addon: entry.addon }
      if (keys !== "" && entry.keys === keys) return { id: entry.id, label: entry.label, keys: "", command: entry.command, addon: entry.addon }
      return entry
    })
    queueRun(["set", id, keys])
  }
  function restoreDefaults() {
    stopRecording()
    cancelPending()
    queueRun(["reset"])
  }
  function queueRun(args) {
    setQueue = setQueue.concat([args])
    if (!shortcutSet.running) runNextSet()
  }
  function runNextSet() {
    if (setQueue.length === 0) { shortcutList.running = true; boundList.running = true; return }
    var next = setQueue[0]
    setQueue = setQueue.slice(1)
    shortcutSet.command = ["bash", bindingsScript].concat(next)
    shortcutSet.running = true
  }

  function startRecording(id) {
    cancelPending()
    recordingId = id
    recordHint = ""
    submapEnter.running = true
    recordTimeout.restart()
    recorder.forceActiveFocus()
  }
  function stopRecording() {
    if (recordingId === "") return
    recordingId = ""
    recordHint = ""
    recordTimeout.stop()
    submapReset.running = true
    if (page.view.active) page.view.forceActiveFocus()
  }
  function captured(keys) {
    var id = recordingId
    stopRecording()
    var own = shortcuts.filter(function(e) { return e.id === id })[0]
    var used = liveBindings.filter(function(b) {
      return b.keys === keys && (!own || b.command !== own.command)
    })[0]
    if (!used) { setShortcut(id, keys); return }
    pendingId = id
    pendingKeys = keys
    pendingConflict = used.description
  }
  function applyPending() {
    if (pendingId !== "") setShortcut(pendingId, pendingKeys)
    cancelPending()
  }
  function cancelPending() {
    pendingId = ""
    pendingKeys = ""
    pendingConflict = ""
  }

  // Qt key → Hyprland key name. Digits and punctuation go by their physical
  // key, so Shift doesn't turn 1 into !.
  readonly property var scanKeys: ({
    10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0",
    20: "MINUS", 21: "EQUAL", 34: "BRACKETLEFT", 35: "BRACKETRIGHT", 47: "SEMICOLON",
    48: "APOSTROPHE", 49: "GRAVE", 51: "BACKSLASH", 59: "COMMA", 60: "PERIOD", 61: "SLASH"
  })
  function keyName(event) {
    var k = event.key
    if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
    if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
    var names = {}
    names[Qt.Key_Space] = "SPACE"; names[Qt.Key_Return] = "RETURN"; names[Qt.Key_Enter] = "RETURN"
    names[Qt.Key_Escape] = "ESCAPE"; names[Qt.Key_Tab] = "TAB"; names[Qt.Key_Backtab] = "TAB"
    names[Qt.Key_Backspace] = "BACKSPACE"; names[Qt.Key_Delete] = "DELETE"; names[Qt.Key_Insert] = "INSERT"
    names[Qt.Key_Home] = "HOME"; names[Qt.Key_End] = "END"; names[Qt.Key_PageUp] = "PRIOR"; names[Qt.Key_PageDown] = "NEXT"
    names[Qt.Key_Left] = "LEFT"; names[Qt.Key_Right] = "RIGHT"; names[Qt.Key_Up] = "UP"; names[Qt.Key_Down] = "DOWN"
    names[Qt.Key_Print] = "PRINT"
    return names[k] || scanKeys[event.nativeScanCode] || ""
  }

  function shortcutText(keys) {
    if (!keys) return "None"
    var names = {
      SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt",
      ESCAPE: "Esc", RETURN: "Enter", BACKSPACE: "Backspace", PRIOR: "Page Up", NEXT: "Page Down",
      COMMA: ",", PERIOD: ".", SLASH: "/", MINUS: "-", EQUAL: "=", GRAVE: "`", SEMICOLON: ";",
      APOSTROPHE: "'", BRACKETLEFT: "[", BRACKETRIGHT: "]", BACKSLASH: "\\"
    }
    return keys.split(" + ").map(function(part) {
      return names[part] || (part.length <= 3 ? part : part.charAt(0) + part.slice(1).toLowerCase())
    }).join(" + ")
  }

  readonly property var shortcutSections: [
    { title: "Menus", ids: ["menu", "apps", "power"] },
    { title: "Search", ids: ["keybinds", "emoji", "clipboard"] },
    { title: "Appearance", ids: ["themes", "wallpapers"] },
    { title: "Island", ids: ["controls", "player", "settings"] }
  ]
  function addonEntries(addonId) {
    return page.shortcuts.filter(function(e) { return e.addon === addonId })
  }
  function sectionEntries(section) {
    return page.shortcuts.filter(function(e) { return e.addon === "" && section.ids.indexOf(e.id) !== -1 })
  }

  Repeater {
    model: page.shortcutSections
    delegate: SettingsGroup {
      id: section
      view: page.view
      required property var modelData
      readonly property var entries: page.sectionEntries(modelData)
      visible: entries.length > 0
      title: modelData.title
      Repeater {
        model: section.entries
        delegate: ShortcutRow {
          view: page.view
          keybinds: page
          required property var modelData
          required property int index
          entry: modelData
          last: index === section.entries.length - 1
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    SettingsButton { view: page.view; label: "Restore Defaults"; onClicked: page.restoreDefaults() }
    Item { Layout.fillWidth: true }
  }

  // Takes the keyboard while a shortcut is being recorded.
  Item {
    id: recorder
    // Outside the page's layout, so it takes no room in it.
    parent: page.view
    width: 0
    height: 0
    // A modifier's own press doesn't include itself in event.modifiers yet.
    function modifierFor(key) {
      if (key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R) return Qt.MetaModifier
      if (key === Qt.Key_Shift) return Qt.ShiftModifier
      if (key === Qt.Key_Control) return Qt.ControlModifier
      if (key === Qt.Key_Alt) return Qt.AltModifier
      return 0
    }
    onActiveFocusChanged: if (!activeFocus) page.stopRecording()
    function heldMods(modifiers) {
      var mods = []
      if (modifiers & Qt.MetaModifier) mods.push("SUPER")
      if (modifiers & Qt.ShiftModifier) mods.push("SHIFT")
      if (modifiers & Qt.ControlModifier) mods.push("CTRL")
      if (modifiers & Qt.AltModifier) mods.push("ALT")
      return mods
    }
    function showHeld(modifiers) {
      var mods = heldMods(modifiers)
      page.recordHint = mods.length ? page.shortcutText(mods.join(" + ")) + " + …" : ""
    }
    Keys.onReleased: function(event) {
      event.accepted = true
      if (page.recordingId !== "" && page.keyName(event) === "") showHeld(event.modifiers & ~recorder.modifierFor(event.key))
    }
    Keys.onPressed: function(event) {
      event.accepted = true
      var name = page.keyName(event)
      if (name === "") { showHeld(event.modifiers | recorder.modifierFor(event.key)); return }
      var mods = heldMods(event.modifiers)
      if (name === "ESCAPE" && mods.length === 0) { page.stopRecording(); return }
      if ((name === "BACKSPACE" || name === "DELETE") && mods.length === 0) {
        var id = page.recordingId
        page.stopRecording()
        page.setShortcut(id, "")
        return
      }
      if (mods.length === 0 && !/^F\d+$/.test(name)) { page.recordHint = "Add a Modifier"; return }
      page.captured(mods.concat([name]).join(" + "))
    }
  }
}
