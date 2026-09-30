import QtQuick
import Quickshell.Hyprland

// Shown for a moment when the workspace changes: a dot for each workspace
// (solid with windows, faint when empty), and a white capsule with the current
// workspace's number that slides from the one you left. Its neutral accent
// follows the appearance preference. The workspaces are
// Omarchy's bar's: 1–5 always, and any other up to 10 that exists.
Item {
  id: pill
  required property var host
  readonly property bool shown: host.workspacesPill
  readonly property int slot: 18
  readonly property int gap: 6
  readonly property int focusedIndex: host.workspaceIds.indexOf(host.focusedWorkspaceId)

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) if (values[i].id === id) return values[i]
    return null
  }

  Item {
    anchors.centerIn: parent
    width: pill.host.workspaceIds.length * (pill.slot + pill.gap) - pill.gap
    height: pill.slot

    Row {
      spacing: pill.gap
      Repeater {
        model: pill.host.workspaceIds
        delegate: Item {
          id: workspaceSlot
          required property int modelData
          readonly property var workspace: pill.workspaceById(modelData)
          readonly property bool occupied: !!workspace && workspace.toplevels.values.length > 0
          width: pill.slot
          height: pill.slot
          Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 7
            radius: 3.5
            color: Qt.rgba(1, 1, 1, workspaceSlot.occupied ? 0.7 : 0.22)
          }
        }
      }
    }

    // The capsule over the current workspace; it keeps its place while
    // hidden, so the next switch slides it from the last one.
    Rectangle {
      visible: pill.focusedIndex >= 0
      x: Math.max(0, pill.focusedIndex) * (pill.slot + pill.gap) - 5
      anchors.verticalCenter: parent.verticalCenter
      width: pill.slot + 10
      height: pill.slot
      radius: height / 2
      color: pill.host.settings.colorfulLiveActivities ? "#ffffff" : pill.host.theme.accent
      Behavior on x { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
      Text {
        anchors.centerIn: parent
        text: pill.host.focusedWorkspaceId
        color: pill.host.settings.colorfulLiveActivities ? "#000000" : pill.host.theme.accentText
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
      }
    }
  }
}
