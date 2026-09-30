import QtQuick

// Shown for a moment when the keyboard layout changes: the keyboard leading,
// the layout's name in the middle, and trailing a chip for each layout with a
// white capsule that slides from the one you left, like WorkspacePill.
Item {
  id: pill
  required property var host
  readonly property bool shown: host.keyboardPill
  readonly property int chip: 30
  readonly property int gap: 8

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  // Leading: the keyboard, settling gently into place.
  Text {
    id: leading
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    text: "󰌌"
    color: pill.host.theme.accent
    font.family: pill.host.theme.fontFamily
    font.pixelSize: 20
    scale: pill.shown ? 1 : 0.86
    Behavior on scale { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
  }

  // Middle: the layout's name.
  Text {
    anchors.left: leading.right
    anchors.leftMargin: 10
    anchors.right: trailing.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: pill.host.keyboardLayoutName
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: "#ffffff"
    font.family: "Adwaita Sans"
    font.pixelSize: 13
    font.weight: Font.Medium
    font.letterSpacing: -0.2
  }

  // Trailing: a chip per layout; the capsule keeps its place while hidden,
  // so the next switch slides it from the last one.
  Item {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: pill.host.keyboardLayoutCodes.length * (pill.chip + pill.gap) - pill.gap
    height: 22

    Rectangle {
      x: pill.host.keyboardLayoutIndex * (pill.chip + pill.gap)
      width: pill.chip
      height: parent.height
      radius: height / 2
      color: "#ffffff"
      Behavior on x { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
    }

    Row {
      spacing: pill.gap
      Repeater {
        model: pill.host.keyboardLayoutCodes
        delegate: Text {
          required property string modelData
          required property int index
          width: pill.chip
          height: trailing.height
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: modelData.toUpperCase()
          color: index === pill.host.keyboardLayoutIndex ? "#000000" : Qt.rgba(1, 1, 1, 0.45)
          Behavior on color { MotionColorAnimation { theme: pill.host.theme } }
          font.family: "Adwaita Sans"
          font.pixelSize: 11
          font.weight: Font.Bold
        }
      }
    }
  }
}
