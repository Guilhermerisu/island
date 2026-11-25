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
  property string typedKeyboardName: ""
  property bool refreshPending: false
  signal switched()

  // Hyprland's own virtual keyboard (which reports a layout change on every
  // focus switch) and the power, lid and hotkey switches aren't typed on.
  function isTypedKeyboard(name) {
    return !/^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)|(-wmi-hotkeys|-wireless-radio-control)(-\d+)?$/.test(String(name || ""))
  }

  function refresh() {
    if (read.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    read.running = true
  }

  function next() { if (codes.length > 1) switcher.running = true }

  Process {
    id: read
    command: ["hyprctl", "devices", "-j"]
    onRunningChanged: if (!running && keyboard.refreshPending) keyboard.refresh()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var boards = JSON.parse(text).keyboards || []
          var typed = boards.filter(function(k) { return keyboard.isTypedKeyboard(k.name) })
          // The keyboard last typed on, else Hyprland's main one if it's real.
          var main = typed.filter(function(k) { return k.name === keyboard.typedKeyboardName })[0]
            || typed.filter(function(k) { return k.main })[0]
            || typed[0]
            || boards.filter(function(k) { return k.main })[0] || boards[0]
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
  // "activelayout>>keyboard,layout" arrives whenever any keyboard switches,
  // the virtual one included; only a typed keyboard's new layout asks
  // Hyprland for the rest.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activelayout") return
      var parts = event.parse(2)
      if (!keyboard.isTypedKeyboard(parts[0])) return
      var sameBoard = parts[0] === keyboard.typedKeyboardName
      keyboard.typedKeyboardName = parts[0]
      if (keyboard.known && sameBoard && parts[1] === keyboard.name) return
      keyboard.refresh()
    }
  }
  Component.onCompleted: refresh()
}
