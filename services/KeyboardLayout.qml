import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

// The main keyboard's layouts ("us", "mn") and which is active, read from
// Hyprland at start, on refresh(), and when the active layout changes.
// `switched` fires when a reading's layout differs from the last one; the
// first is only recorded.
Item {
  id: keyboard
  property bool known: false
  property string name: ""
  property var codes: []
  property int index: 0
  signal switched()

  function refresh() { if (!read.running) read.running = true }
  function next() { if (codes.length > 1) switcher.running = true }

  Process {
    id: read
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var boards = JSON.parse(text).keyboards || []
          var main = boards.filter(function(k) { return k.main })[0] || boards[0]
          if (!main) return
          var name = String(main.active_keymap || "")
          var changed = keyboard.known && name !== keyboard.name
          keyboard.known = true
          keyboard.name = name
          keyboard.codes = String(main.layout || "").split(",").filter(function(l) { return l !== "" })
          keyboard.index = main.active_layout_index || 0
          if (changed) keyboard.switched()
        } catch (e) {}
      }
    }
  }
  Process { id: switcher; command: ["hyprctl", "switchxkblayout", "all", "next"] }
  // "activelayout>>keyboard,layout" arrives whenever any keyboard switches;
  // Hyprland is only asked for the rest when the layout's name is new.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activelayout" || read.running) return
      if (keyboard.known && event.parse(2)[1] === keyboard.name) return
      read.running = true
    }
  }
  Component.onCompleted: refresh()
}
