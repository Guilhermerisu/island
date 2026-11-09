import QtQuick
import QtQuick.Effects
import "../../components"
import QtQuick.Layouts

// macOS Control Center slider: a translucent capsule with a white fill that
// ends in a round white knob, and the icon inside on the left. `center` is the
// ControlCenter, for its colours.
Item {
  id: s
  required property var center
  property string icon: ""
  property real value: 0
  signal moved(real value)
  readonly property real clamped: Math.max(0, Math.min(1, value))
  // Animate the level only: the island's changing width must not restart
  // the fill animation or make a fixed volume appear to change.
  property real shownLevel: clamped
  Behavior on shownLevel {
    enabled: !sliderMouse.pressed
    MotionAnimation { theme: center.host.theme; pace: "quick" }
  }

  // Upright (One UI style): the whole card is one tall pill, filled from the
  // bottom up to the level; the edge of the fill is the handle, no knob.
  // `title` and `detail` are only shown then, over the pill.
  property bool vertical: false
  property string title: ""
  property string detail: ""
  Layout.fillWidth: true
  Layout.fillHeight: vertical
  Layout.preferredHeight: 30

  Item {
    id: track
    visible: !s.vertical
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 26
    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: center.host.theme.fill(sliderMouse.containsMouse ? "stronger" : "strong")
      border.width: 1
      border.color: center.host.theme.fill("quiet")
      Behavior on color { MotionColorAnimation { theme: center.host.theme } }
    }
    Rectangle {
      id: sliderFill
      height: parent.height
      radius: height / 2
      width: height + (parent.width - height) * s.shownLevel
      color: "#ececec"
    }
    // The knob, lifted off the fill by a soft shadow.
    Rectangle {
      id: knob
      x: sliderFill.width - width
      width: parent.height
      height: parent.height
      radius: height / 2
      color: "#ffffff"
      layer.enabled: visible
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.5)
        shadowBlur: 0.3
        shadowHorizontalOffset: -0.5
        shadowVerticalOffset: 0.5
      }
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 7
      anchors.verticalCenter: parent.verticalCenter
      text: s.icon
      color: sliderFill.width > x + width ? "#5c5c60" : center.textMuted
      font.family: center.iconFont
      font.pixelSize: center.host.theme.px(15)
    }
  }

  Item {
    id: pill
    visible: s.vertical
    anchors.fill: parent
    // Rounder than the other cards, and never more than a half-capsule.
    readonly property real radius: Math.min(width / 2, 2 * center.cardRadius)
    // What the card's own colour would be under the translucent well.
    Rectangle { anchors.fill: parent; radius: pill.radius; color: center.card }
    Rectangle {
      anchors.fill: parent
      radius: pill.radius
      color: center.host.theme.fill(sliderMouse.containsMouse ? "stronger" : "strong")
      border.width: 1
      border.color: center.host.theme.fill("quiet")
      Behavior on color { MotionColorAnimation { theme: center.host.theme } }
    }
    // The fill is the pill's own shape cut off flat at the level, so its
    // bottom corners follow the pill's.
    Item {
      id: pillFill
      width: parent.width
      height: parent.height * s.shownLevel
      y: parent.height - height
      clip: true
      Rectangle {
        y: pillFill.height - pill.height
        width: pill.width
        height: pill.height
        radius: pill.radius
        color: "#ececec"
      }
    }
    // Dark ink while the fill is behind a label's middle, the muted ink otherwise.
    Column {
      id: pillLabels
      x: 0
      y: 12
      width: parent.width
      spacing: 1
      Text {
        width: parent.width - 8
        x: 4
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: s.title
        color: pillFill.y < pillLabels.y + y + height / 2 ? "#5c5c60" : center.textMuted
        font.family: center.host.theme.textFontFamily
        font.pixelSize: center.host.theme.px(10)
        font.letterSpacing: -0.1
      }
      Text {
        width: parent.width - 8
        x: 4
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: s.detail
        color: pillFill.y < pillLabels.y + y + height / 2 ? "#5c5c60" : center.textMuted
        font.family: center.host.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: center.host.theme.px(12)
        font.weight: Font.DemiBold
      }
    }
    Text {
      x: (parent.width - width) / 2
      y: parent.height - height - 14
      text: s.icon
      color: pillFill.y < y + height ? "#5c5c60" : center.textMuted
      font.family: center.iconFont
      font.pixelSize: center.host.theme.px(20)
    }
  }
  MouseArea {
    id: sliderMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // The control center can scroll: a drag that wanders stays on the slider.
    preventStealing: true
    function apply(x, y) {
      if (s.vertical) s.moved(Math.max(0, Math.min(1, 1 - y / height)))
      else s.moved(Math.max(0, Math.min(1, (x - track.height / 2) / (track.width - track.height))))
    }
    onPressed: function(e) { apply(e.x, e.y) }
    onPositionChanged: function(e) { if (pressed) apply(e.x, e.y) }
    onWheel: function(e) {
      // While editing, the wheel scrolls the page (Views.qml) and must not
      // change a value under the pointer.
      if (s.center.editMode) {
        e.accepted = false
        return
      }
      s.moved(Math.max(0, Math.min(1, s.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
  }
}
