import QtQuick

// A core live activity, drawn over the whole island while `shown`. The
// island sizes itself to pillWidth × pillHeight, plus the clock's growth
// when `keepsClock` (the clock stays in its middle), rounds its corners to
// pillRadius when set, and hands it clicks. The first shown pill in
// Island.qml's pill layer is the one on the island.
Item {
  id: pill
  required property var host
  property bool shown: false
  property real pillWidth: 280
  property real pillHeight: host.pillHeight
  property real pillRadius: 0
  property bool keepsClock: false
  function clicked(mouse) { host.view = "controls" }

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }
}
