import QtQuick
import "../../views/control-center"

// The control center tile, a CcTile like the others: the timer's time left
// ("12:34", "Paused · 12:34"), or "Off" while it's unset, lit while
// it's set. Opens the timer view. `timer` is the TimerAddon.
CcTile {
  required property var timer
  readonly property string phase: timer.phase

  anchors.fill: parent
  icon: "󰔛"
  title: "Timer"
  subtitle: phase === "running" ? timer.timeText(timer.remaining)
    : phase === "paused" ? "Paused · " + timer.timeText(timer.remaining)
    : "Off"
  checked: phase !== "idle"
  onClicked: timer.host.view = "timer"
}
