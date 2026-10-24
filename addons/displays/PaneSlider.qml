import QtQuick
import QtQuick.Effects
import "../../components"

// macOS's System Settings slider: a thin track filled in the accent colour
// up to a round white knob, a small glyph at each end. With `stops`, it
// snaps to them (and ticks mark them). `live` sends each move while
// dragging; otherwise only where it's let go.
// `view` is the SettingsView; `value` runs from 0 to 1.
Item {
  id: slider
  required property var view
  property real value: 0
  property int stops: 0
  property bool live: true
  property string leading: ""
  property string trailing: ""
  property real leadingSize: 11
  property real trailingSize: 11
  signal moved(real value)

  // While dragging, the knob follows the pointer, not `value`; let go, it
  // stays there until `value` catches up (or a moment passes).
  property real dragged: 0
  property bool holding: false
  readonly property bool dragging: mouse.pressed || holding
  readonly property real shown: Math.max(0, Math.min(1, dragging ? dragged : value))
  onValueChanged: holding = false
  // Where the knob and fill are drawn: gliding to a click on the track, a
  // stop it snaps to, or a new value, but right under the pointer while
  // it drags freely.
  property bool tracking: false
  property real glide: shown
  Behavior on glide {
    enabled: !slider.tracking || slider.stops > 1
    MotionAnimation { theme: slider.view.host.theme; pace: "quick" }
  }
  Timer { id: release; interval: 2500; onTriggered: slider.holding = false }
  function snap(v) {
    v = Math.max(0, Math.min(1, v))
    return stops > 1 ? Math.round(v * (stops - 1)) / (stops - 1) : v
  }

  implicitWidth: 250
  implicitHeight: 24

  // The glyphs sit in slots of one width, so sliders in rows above and
  // below line up.
  Item {
    id: lead
    visible: slider.leading !== ""
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 18
    height: parent.height
    Text {
      anchors.centerIn: parent
      text: slider.leading
      color: slider.view.textMuted
      font.family: slider.view.host.theme.textFontFamily
      font.letterSpacing: slider.view.host.theme.tracking(slider.view.host.theme.textFontFamily, slider.leadingSize)
      font.pixelSize: slider.leadingSize
    }
  }
  Item {
    id: trail
    visible: slider.trailing !== ""
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 18
    height: parent.height
    Text {
      anchors.centerIn: parent
      text: slider.trailing
      color: slider.view.textMuted
      font.family: slider.view.host.theme.textFontFamily
      font.letterSpacing: slider.view.host.theme.tracking(slider.view.host.theme.textFontFamily, slider.trailingSize)
      font.pixelSize: slider.trailingSize
    }
  }

  Item {
    id: track
    anchors.left: lead.visible ? lead.right : parent.left
    anchors.right: trail.visible ? trail.left : parent.right
    anchors.leftMargin: lead.visible ? 6 : 0
    anchors.rightMargin: trail.visible ? 6 : 0
    anchors.verticalCenter: parent.verticalCenter
    height: knob.height
    readonly property real span: width - knob.width

    Rectangle {
      id: groove
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: knob.width / 2
      anchors.rightMargin: knob.width / 2
      anchors.verticalCenter: parent.verticalCenter
      height: 3
      radius: 1.5
      color: slider.view.well
      Rectangle {
        width: groove.width * slider.glide
        height: parent.height
        radius: parent.radius
        color: slider.view.accent
      }
    }
    Repeater {
      model: slider.stops > 1 ? slider.stops : 0
      delegate: Rectangle {
        required property int index
        x: knob.width / 2 + track.span * index / (slider.stops - 1) - width / 2
        y: groove.y + groove.height + 4
        width: 1
        height: 3
        color: slider.view.textMuted
        opacity: 0.45
      }
    }
    Rectangle {
      id: knob
      x: track.span * slider.glide
      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18
      radius: 9
      color: "#ffffff"
      border.width: 0.5
      border.color: Qt.rgba(0, 0, 0, 0.18)
      scale: mouse.pressed ? 1.06 : 1
      Behavior on scale { MotionAnimation { theme: slider.view.host.theme; pace: "press" } }
      layer.enabled: visible
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.45)
        shadowBlur: 0.35
        shadowVerticalOffset: 1
        autoPaddingEnabled: true
      }
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      anchors.topMargin: -6
      anchors.bottomMargin: -6
      cursorShape: Qt.PointingHandCursor
      enabled: slider.enabled
      function at(x) { return slider.snap((x - knob.width / 2) / Math.max(1, track.span)) }
      onPressed: function(e) {
        slider.tracking = false
        slider.dragged = at(e.x)
        if (slider.live) slider.moved(slider.dragged)
      }
      onPositionChanged: function(e) {
        if (!pressed) return
        slider.tracking = true
        var v = at(e.x)
        if (v === slider.dragged) return
        slider.dragged = v
        if (slider.live) slider.moved(v)
      }
      onReleased: {
        slider.tracking = false
        slider.holding = true
        release.restart()
        if (!slider.live) slider.moved(slider.dragged)
      }
    }
  }
}
