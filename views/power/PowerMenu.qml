import QtQuick
import "../../components"
import Quickshell.Io

// Power menu hosted by the island, styled after Apple's Control Center: a
// row of equal tiles (outline glyph over label); the selected tile lifts to a
// lighter grey inside an accent ring set just outside it, the same ring the
// theme picker puts on its chosen card. ←/→ (or Tab, or the wheel) to
// move, Enter to run, Esc to close; clicking a tile runs it. Mirrors
// Omarchy's System menu, including its suspend/hibernate availability rules.
Item {
  id: power
  required property var host

  // Set by the Surface that shows this menu.
  property bool active: false

  readonly property int tileWidth: 104
  readonly property int tileHeight: 88
  readonly property int tileSpacing: 8
  // Matches Picker's selection ring: 2 px of accent, 2 px of island between.
  readonly property real ringGap: 2
  readonly property real ringWidth: 2
  // 10 px from the glyph's ink to the label's cap height, less the room the
  // label's line keeps above its capitals.
  readonly property int glyphGap: 7

  property bool suspendAvailable: true
  property bool hibernateAvailable: false
  // Older Omarchy has omarchy-system-shutdown/-reboot, newer merged them into
  // `omarchy-system shutdown|reboot`; plain systemctl if neither is there.
  function sessionCommand(action, fallback) {
    return ["bash", "-c",
      "if command -v omarchy-system-$0 >/dev/null; then exec omarchy-system-$0; "
      + "elif command -v omarchy-system >/dev/null; then exec omarchy-system $0; "
      + "else exec systemctl $1; fi", action, fallback]
  }
  readonly property var actions: {
    var list = [{ label: "Power Off", icon: "󰐥", command: sessionCommand("shutdown", "poweroff") }]
    list.push({ label: "Reboot", icon: "󰜉", command: sessionCommand("reboot", "reboot") })
    list.push({ label: "Lock", icon: "󰍁", command: ["omarchy-system-lock"] })
    if (hibernateAvailable) list.push({ label: "Hibernate", icon: "󰜗", command: ["systemctl", "hibernate"] })
    if (suspendAvailable) list.push({ label: "Suspend", icon: "󰖔", command: ["systemctl", "suspend"] })
    return list
  }
  property int currentIndex: 0
  readonly property int lockIndex: {
    for (var i = 0; i < actions.length; i++) if (actions[i].label === "Lock") return i
    return 0
  }

  implicitWidth: actions.length * tileWidth + (actions.length - 1) * tileSpacing
  implicitHeight: row.height

  onActiveChanged: {
    if (!active) return
    // Lock is the safe default, so a stray Enter doesn't power off.
    currentIndex = lockIndex
    suspendCheck.running = true
    hibernateCheck.running = true
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  // Same conditions as the System menu's `when` fields. Older Omarchy has no
  // omarchy-sleep-disabled; `!` of a missing command passes, so that's fine.
  Process {
    id: suspendCheck
    command: ["bash", "-c", "! omarchy-toggle-enabled suspend-off && ! omarchy-sleep-disabled"]
    onExited: function(code) { power.suspendAvailable = code === 0 }
  }
  Process {
    id: hibernateCheck
    command: ["bash", "-c", "omarchy-hibernation-available && ! omarchy-sleep-disabled"]
    onExited: function(code) { power.hibernateAvailable = code === 0 }
  }

  // Close first, then run detached: lock, suspend, and logout take the
  // session (and this shell) with them.
  Process { id: runner }
  function run(index) {
    var action = actions[index]
    if (!action) return
    host.view = "rest"
    runner.command = action.command
    runner.startDetached()
  }

  function move(delta) {
    currentIndex = Math.max(0, Math.min(actions.length - 1, currentIndex + delta))
  }

  Item {
    id: keys
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
        power.move(1); event.accepted = true
      } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
        power.move(-1); event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        power.run(power.currentIndex); event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        power.host.view = "rest"; event.accepted = true
      }
    }
  }

  WheelHandler {
    onWheel: function(event) {
      var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
      power.move(d > 0 ? -1 : 1)
    }
  }

  Row {
    id: row
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: power.tileSpacing

    Repeater {
      model: power.actions
      delegate: Item {
        id: slot
        required property var modelData
        required property int index
        readonly property bool isSelected: index === power.currentIndex
        StaggerIn { step: slot.index }
        width: power.tileWidth
        height: power.tileHeight

        Rectangle {
          id: tile
          anchors.fill: parent
          radius: power.host.theme.radii.card
          color: slot.isSelected ? power.host.theme.well : power.host.theme.card
          scale: tileMouse.pressed ? 0.97 : 1
          Behavior on color { MotionColorAnimation { theme: power.host.theme } }
          Behavior on scale { id: scaleMotion; MotionAnimation { theme: power.host.theme; pace: towards(scaleMotion.targetValue, tileMouse.pressed ? "press" : "standard") } }

          // Selection ring, a gap of island black outside the tile; fades in.
          Rectangle {
            anchors.fill: parent
            anchors.margins: -(power.ringGap + power.ringWidth)
            radius: tile.radius + power.ringGap + power.ringWidth
            color: "transparent"
            border.width: power.ringWidth
            border.color: power.host.theme.accent
            opacity: slot.isSelected ? 1 : 0
            Behavior on opacity { MotionAnimation { theme: power.host.theme; pace: "fade"; curve: "fade" } }
          }

          // The glyph sits in a 20 px box, as tall as its ink, so the gap to
          // the label is measured from the ink and not the font's line.
          // Nerd Font icons draw at about 0.8 of their pixel size.
          Column {
            anchors.centerIn: parent
            spacing: power.glyphGap
            Item {
              anchors.horizontalCenter: parent.horizontalCenter
              width: glyph.implicitWidth
              height: power.host.theme.px(20)
              Text {
                id: glyph
                anchors.centerIn: parent
                text: slot.modelData.icon
                color: power.host.theme.text
                font.family: power.host.theme.fontFamily
                font.pixelSize: power.host.theme.px(25)
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: slot.modelData.label
              color: power.host.theme.text
              font.family: power.host.theme.textFontFamily
              font.letterSpacing: power.host.theme.tracking(power.host.theme.textFontFamily, power.host.theme.size.callout)
              font.pixelSize: power.host.theme.size.callout
              font.weight: Font.Medium
            }
          }
        }
        MouseArea {
          id: tileMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: power.run(slot.index)
        }
      }
    }
  }
}
