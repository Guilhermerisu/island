import QtQuick
import "../../components"
import Quickshell.Io

// Power menu hosted by the island, styled after Apple's Control Center: a
// row of squircle tiles (icon over label); the selected tile fills with the
// theme accent and grows a touch. ←/→ (or Tab, or the wheel) to
// move, Enter to run, Esc to close; clicking a tile runs it. Mirrors
// Omarchy's System menu, including its suspend/hibernate availability rules.
Item {
  id: power
  required property var host

  // Set by the Surface that shows this menu.
  property bool active: false

  readonly property int tileWidth: 116
  readonly property int tileHeight: 92
  // Slightly wider than a tile so the enlarged selected one clears its
  // neighbours.
  readonly property int slotWidth: tileWidth + 6
  readonly property int tileSpacing: 6

  property bool suspendAvailable: true
  property bool hibernateAvailable: false
  readonly property var actions: {
    var list = [{ label: "Power Off", icon: "󰐥", command: ["omarchy-system-shutdown"] }]
    list.push({ label: "Reboot", icon: "󰜉", command: ["omarchy-system-reboot"] })
    list.push({ label: "Lock", icon: "", command: ["omarchy-system-lock"] })
    if (hibernateAvailable) list.push({ label: "Hibernate", icon: "󰤁", command: ["systemctl", "hibernate"] })
    if (suspendAvailable) list.push({ label: "Suspend", icon: "󰖔", command: ["systemctl", "suspend"] })
    return list
  }
  property int currentIndex: 0
  readonly property int lockIndex: {
    for (var i = 0; i < actions.length; i++) if (actions[i].label === "Lock") return i
    return 0
  }

  implicitWidth: actions.length * slotWidth + (actions.length - 1) * tileSpacing
  implicitHeight: row.height

  onActiveChanged: {
    if (!active) return
    // Lock is the safe default, so a stray Enter doesn't power off.
    currentIndex = lockIndex
    suspendCheck.running = true
    hibernateCheck.running = true
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  // Same conditions as the System menu's `when` fields.
  Process {
    id: suspendCheck
    command: ["omarchy-toggle-enabled", "suspend-off"]
    onExited: function(code) { power.suspendAvailable = code !== 0 }
  }
  Process {
    id: hibernateCheck
    command: ["omarchy-hibernation-available"]
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
        width: power.slotWidth
        // Room for the selected tile to grow.
        height: power.tileHeight * 1.06

        Rectangle {
          id: tile
          anchors.horizontalCenter: parent.horizontalCenter
          y: power.tileHeight * 0.03
          width: power.tileWidth
          height: power.tileHeight
          radius: 23
          color: slot.isSelected ? power.host.theme.accent : power.host.theme.withAlpha(power.host.theme.text, 0.1)
          scale: tileMouse.pressed ? 0.97 : slot.isSelected ? 1.025 : 1
          Behavior on color { MotionColorAnimation { theme: power.host.theme } }
          Behavior on scale { MotionAnimation { theme: power.host.theme; pace: tileMouse.pressed ? "press" : "standard" } }

          Column {
            anchors.centerIn: parent
            spacing: 8
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: slot.modelData.icon
              color: slot.isSelected ? power.host.theme.accentText : power.host.theme.text
              font.family: power.host.theme.fontFamily
              font.pixelSize: 26
              Behavior on color { MotionColorAnimation { theme: power.host.theme } }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: slot.modelData.label
              color: slot.isSelected ? power.host.theme.accentText : power.host.theme.text
              opacity: slot.isSelected ? 1 : 0.8
              font.family: "Adwaita Sans"
              font.pixelSize: 13
              font.weight: Font.DemiBold
              Behavior on color { MotionColorAnimation { theme: power.host.theme } }
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
