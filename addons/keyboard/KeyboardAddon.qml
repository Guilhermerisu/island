import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import ".."

// The keyboard layout on the pill for a moment when it changes (see
// KeyboardPill): the main keyboard's layouts ("us", "mn") and which is
// active, read from Hyprland. The pill only shows when the active layout
// differs from the last reading; the first one is only recorded.
Addon {
  id: keyboard
  property bool known: false
  property string name: ""
  property var codes: []
  property int index: 0

  pill: Component { KeyboardPill { layout: keyboard } }
  pillWidth: 170 + codes.length * 38

  Process {
    id: layoutRead
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
          if (changed) keyboard.host.showFeedback("", 1400, "addon:" + keyboard.addon.id)
        } catch (e) {}
      }
    }
  }
  // "activelayout>>keyboard,layout" arrives whenever any keyboard switches;
  // Hyprland is only asked for the rest when the layout's name is new.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activelayout" || !keyboard.host.activities.ready || layoutRead.running) return
      if (keyboard.known && event.parse(2)[1] === keyboard.name) return
      layoutRead.running = true
    }
  }
  Component.onCompleted: layoutRead.running = true
}
