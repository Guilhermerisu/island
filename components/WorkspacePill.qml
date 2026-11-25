import QtQuick
import Quickshell.Hyprland

// Shown for a moment when the workspace changes: a dot for each of the
// workspaces 1–10 (solid with windows, faint when empty), and a white capsule
// with the current workspace's number that slides from the one you left. Its
// neutral accent follows the appearance preference. Only a window of them
// shows (5–10, see workspaceHudCount), widened to reach the highest workspace
// with windows so none is left out of sight; it stays put while the current
// workspace is inside it, and slides just far enough to bring it in when you
// switch past either edge.
IslandPill {
  id: pill
  readonly property int slot: 18
  readonly property int gap: 8
  readonly property int count: 10
  readonly property int chosenCount: Math.max(5, Math.min(count, host.settings.workspaceHudCount || 5))
  // Whether each of workspaces 1–10 has windows, by id (index 0 unused).
  readonly property var occupied: {
    var result = []
    for (var id = 0; id <= count; id++) result.push(false)
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var workspaceId = values[i].id
      if (workspaceId >= 1 && workspaceId <= count && values[i].toplevels.values.length > 0) result[workspaceId] = true
    }
    return result
  }
  // The highest of workspaces 1–10 with windows, or 0.
  readonly property int highestOccupied: Math.max(0, occupied.lastIndexOf(true))
  readonly property int visibleCount: Math.max(chosenCount, highestOccupied)
  readonly property int step: slot + gap
  // How far the capsule reaches past its dot on each side.
  readonly property int capsuleBleed: 2
  readonly property int focused: host.focusedWorkspaceId
  readonly property bool focusedInRange: focused >= 1 && focused <= count

  // The first workspace in the window. It's kept while the pill is hidden,
  // so the next switch slides from where the last one left it.
  property int windowStart: 1
  function followFocus() {
    if (!focusedInRange) return
    if (focused < windowStart) windowStart = focused
    else if (focused > windowStart + visibleCount - 1) windowStart = focused - visibleCount + 1
  }
  onFocusedChanged: followFocus()
  // Widened for a workspace with windows, from the start so every one up to
  // it shows; otherwise it stays where it is, as far as it still fits. Then
  // far enough to keep the current one in.
  onVisibleCountChanged: {
    windowStart = highestOccupied > chosenCount ? 1 : Math.max(1, Math.min(windowStart, count - visibleCount + 1))
    followFocus()
  }
  Component.onCompleted: followFocus()

  shown: host.workspacesPill
  pillWidth: visibleCount * step + 56
  pillHeight: host.clockHeight

  // The window: visibleCount slots wide, plus room for the capsule's ends.
  Item {
    anchors.centerIn: parent
    width: pill.visibleCount * pill.step - pill.gap + pill.capsuleBleed * 2
    height: pill.slot
    clip: true

    // All ten dots and the capsule, shifted so the window's first one is at
    // the left edge.
    Item {
      id: strip
      x: pill.capsuleBleed - (pill.windowStart - 1) * pill.step
      width: pill.count * pill.step - pill.gap
      height: pill.slot
      Behavior on x { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }

      Row {
        spacing: pill.gap
        Repeater {
          model: pill.count
          delegate: Item {
            id: workspaceSlot
            required property int index
            readonly property int workspaceId: index + 1
            readonly property bool occupied: pill.occupied[workspaceId]
            readonly property bool inWindow: workspaceId >= pill.windowStart
              && workspaceId < pill.windowStart + pill.visibleCount
            width: pill.slot
            height: pill.slot
            opacity: inWindow ? 1 : 0
            Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
            Rectangle {
              anchors.centerIn: parent
              width: 6
              height: 6
              radius: 3
              // The island's text colour, so they show on a light theme background.
              color: pill.host.theme.withAlpha(pill.host.theme.text, workspaceSlot.occupied ? 0.75 : 0.2)
            }
          }
        }
      }

      // The capsule over the current workspace; it keeps its place while
      // hidden, so the next switch slides it from the last one.
      Rectangle {
        visible: pill.focusedInRange
        x: (Math.max(1, Math.min(pill.count, pill.focused)) - 1) * pill.step - pill.capsuleBleed
        anchors.verticalCenter: parent.verticalCenter
        width: pill.slot + pill.capsuleBleed * 2
        height: pill.slot
        radius: height / 2
        color: pill.host.settings.colorfulLiveActivities ? pill.host.theme.text : pill.host.theme.accent
        Behavior on x { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
        Text {
          anchors.centerIn: parent
          text: pill.focused
          color: pill.host.settings.colorfulLiveActivities ? pill.host.theme.background : pill.host.theme.accentText
          font.family: pill.host.theme.textFontFamily
          font.letterSpacing: pill.host.theme.tracking(pill.host.theme.textFontFamily, pill.host.theme.size.callout)
          font.pixelSize: pill.host.theme.size.callout
          font.weight: Font.Medium
          font.features: { "tnum": 1 }
        }
      }
    }
  }
}
