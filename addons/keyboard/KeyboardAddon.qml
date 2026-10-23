import QtQuick
import ".."

// The keyboard layout on the pill for a moment when it changes (see
// KeyboardPill), from the island's KeyboardLayout service: the main
// keyboard's layouts ("us", "mn") and which is active.
Addon {
  id: keyboard
  readonly property string name: host.keyboard.name
  readonly property var codes: host.keyboard.codes
  readonly property int index: host.keyboard.index

  pill: Component { KeyboardPill { layout: keyboard } }
  pillWidth: 170 + codes.length * 38

  Connections {
    target: keyboard.host.keyboard
    function onSwitched() {
      if (keyboard.host.activities.ready) keyboard.host.showFeedback("", 1400, "addon:" + keyboard.addon.id)
    }
  }
}
