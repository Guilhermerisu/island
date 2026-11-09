import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../components"

// A thin live level bar for an audio node, shown under a card's picker (as
// Omarchy's audio panel does). Only listens to the node while `shown`.
// `center` is the ControlCenter, for its theme.
Rectangle {
  id: bar
  required property var center
  property var node: null
  property bool shown: false
  property bool muted: false

  Layout.fillWidth: true
  Layout.preferredHeight: 4
  radius: 2
  color: center.host.theme.fill("strong")
  opacity: shown ? (muted ? 0.35 : 1) : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: bar.center.host.theme; pace: bar.shown ? "fade" : "exit"; curve: bar.shown ? "fade" : "exit" } }

  PwNodePeakMonitor {
    id: peakMonitor
    node: bar.node
    enabled: bar.shown && !!bar.node
  }
  Rectangle {
    height: parent.height
    radius: parent.radius
    width: parent.width * Math.max(0, Math.min(1, peakMonitor.peak))
    color: "white"
    Behavior on width { NumberAnimation { duration: 70 } }
  }
}
