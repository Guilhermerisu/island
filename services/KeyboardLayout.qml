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

  function isTypedKeyboard(name) {
    return !/^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)|(-wmi-hotkeys|-wireless-radio-control)(-\d+)?$/.test(String(name || ""))
  }

  function eventKeyboardName(event) {
    var parts = []
    try {
      if (event && event.parse) parts = event.parse(2)
    } catch (e) {}
    if (!parts || parts.length === 0) parts = String(event && event.data ? event.data : "").split(",")
    var name = String(parts[0] || "")
    return isTypedKeyboard(name) ? name : ""
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
          var typed = boards.filter(function(k) {
            return keyboard.isTypedKeyboard(k.name)
          })
          var main = typed.filter(function(k) {
            return k.name === keyboard.typedKeyboardName
          })[0]

          if (!main) {
            main = typed.reduce(function(furthest, k) {
              var furthestIndex = (furthest && furthest.active_layout_index) || 0
              var kIndex = k.active_layout_index || 0
              return kIndex > furthestIndex ? k : furthest
            }, typed[0])
          }
          if (!main) main = boards.filter(function(k) { return k.main })[0] || boards[0]
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
      if (!event || event.name !== "activelayout") return
      var named = keyboard.eventKeyboardName(event)
      if (named) keyboard.typedKeyboardName = named
      keyboard.refresh()
    }
  }
  Component.onCompleted: refresh()
}
