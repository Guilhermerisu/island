pragma ComponentBehavior: Bound
import QtQuick
import "../../components"

// The top of the Displays pane, as macOS's. With two monitors on or more,
// they're laid out as arranged and dragged into place right here (see
// Arrangement). Otherwise each monitor is a small screen showing the wallpaper (see DisplayScreen), in proportion
// (turned with it) and sized by its physical size against the others, its
// name and size under it; with a second one that's off (faded), clicking
// one picks it, ringed with its name lit, and hovering lifts the other.
// `view` is the SettingsView, `displays` the DisplaysAddon.
Item {
  id: hero
  required property var view
  required property var displays
  readonly property var theme: view.host.theme
  readonly property bool several: displays.draft.length >= 2
  function diagonal(e) { return Math.sqrt(e.physicalWidth * e.physicalWidth + e.physicalHeight * e.physicalHeight) }
  readonly property real largest: Math.max.apply(null, displays.draft.map(diagonal).concat([1]))
  // With two monitors on or more, they're shown as arranged and dragged
  // into place here (see Arrangement); otherwise side by side.
  readonly property bool arranged: displays.enabledCount >= 2
  implicitHeight: arranged ? 240 : screens.implicitHeight + 8

  Arrangement {
    visible: hero.arranged
    anchors.fill: parent
    anchors.margins: 6
    view: hero.view
    displays: hero.displays
  }

  Row {
    id: screens
    visible: !hero.arranged
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    spacing: 36
    Repeater {
      // Left to right as they're arranged, as macOS draws them.
      model: hero.displays.draft.slice().sort(function(a, b) { return a.x - b.x || a.y - b.y })
      delegate: Column {
        id: screen
        required property var modelData
        readonly property bool picked: hero.several && modelData.name === hero.displays.selected
        readonly property bool turned: modelData.transform % 2 === 1
        readonly property real ratio: turned ? modelData.height / modelData.width : modelData.width / modelData.height
        // Smaller monitors drawn smaller, but never under 70% of the largest.
        readonly property real size: hero.diagonal(modelData) > 0 ? Math.max(0.7, hero.diagonal(modelData) / hero.largest) : 1
        readonly property real inches: hero.diagonal(modelData) / 25.4
        spacing: 10
        opacity: modelData.disabled ? 0.45 : 1

        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 172
          height: 108
          Item {
            id: lift
            anchors.fill: parent
            scale: pick.pressed ? 0.97 : pick.containsMouse && !screen.picked ? 1.035 : 1
            Behavior on scale { MotionAnimation { theme: hero.theme; pace: pick.pressed ? "press" : "standard" } }
            DisplayScreen {
              id: bezel
              anchors.centerIn: parent
              width: Math.min(parent.width, parent.height * screen.ratio) * screen.size
              height: width / screen.ratio
              view: hero.view
              radius: 7
            }
            Rectangle {
              anchors.centerIn: bezel
              width: bezel.width + 10
              height: bezel.height + 10
              radius: 10
              color: "transparent"
              border.width: 2.5
              border.color: hero.view.accent
              opacity: screen.picked ? 1 : 0
              scale: screen.picked ? 1 : 0.97
              Behavior on opacity { MotionAnimation { theme: hero.theme } }
              Behavior on scale { MotionAnimation { theme: hero.theme } }
            }
          }
          MouseArea {
            id: pick
            anchors.fill: parent
            hoverEnabled: true
            enabled: hero.several
            cursorShape: hero.several ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: hero.displays.selected = screen.modelData.name
          }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: screen.modelData.title
          color: screen.picked || !hero.several ? hero.view.text : hero.view.textMuted
          Behavior on color { MotionColorAnimation { theme: hero.theme } }
          font.family: hero.theme.textFontFamily
          font.letterSpacing: hero.theme.tracking(hero.theme.textFontFamily, hero.view.detailFontSize)
          font.pixelSize: hero.view.detailFontSize
          font.weight: Font.Medium
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          // "27-inch (2560 × 1440)", as macOS writes it.
          text: screen.modelData.disabled ? "Off"
            : (screen.inches > 0 ? Math.round(screen.inches) + "-inch " : "")
              + "(" + (screen.turned ? screen.modelData.height + " × " + screen.modelData.width
                                     : screen.modelData.width + " × " + screen.modelData.height) + ")"
          color: hero.view.textMuted
          font.family: hero.theme.textFontFamily
          font.letterSpacing: hero.theme.tracking(hero.theme.textFontFamily, hero.view.detailCaptionFontSize)
          font.pixelSize: hero.view.detailCaptionFontSize
          font.features: { "tnum": 1 }
        }
      }
    }
  }
}
