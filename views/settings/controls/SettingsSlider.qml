import QtQuick

// A plain slider for a setting: a track and a knob, dragged or clicked.
// `view` is the SettingsView, for its colours; `onMoved` gets the value.
Item {
  id: slider
  required property var view
  property real from: 0
  property real to: 1
  property real value: 0
  property real step: 0.05
  signal moved(real value)
  implicitWidth: view.controlWidth
  implicitHeight: 22
  readonly property real fraction: Math.max(0, Math.min(1, (value - from) / (to - from)))
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width; height: 4; radius: 2
    color: slider.view.host.theme.solid("stronger")
    Rectangle { width: parent.width * slider.fraction; height: parent.height; radius: 2; color: slider.view.accent }
  }
  Rectangle {
    x: (slider.width - width) * slider.fraction
    anchors.verticalCenter: parent.verticalCenter
    width: 18; height: 18; radius: 9; color: "#ffffff"
  }
  MouseArea {
    anchors.fill: parent
    function setFrom(x) {
      var f = Math.max(0, Math.min(1, (x - 9) / (slider.width - 18)))
      slider.moved(Math.round((slider.from + f * (slider.to - slider.from)) / slider.step) * slider.step)
    }
    onPressed: function(m) { setFrom(m.x) }
    onPositionChanged: function(m) { if (pressed) setFrom(m.x) }
  }
}
