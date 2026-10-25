import QtQuick
import "../../../components"
import QtQuick.Layouts

// A pane in the sidebar: its icon and name, highlighted when it's open and
// hidden when the search doesn't match it. `view` is the SettingsView.
Rectangle {
  id: side
  required property var view
  property string title: ""
  readonly property var info: side.view.pageInfo[title] || ({})
  readonly property bool selected: side.view.currentPage === title
  Layout.fillWidth: true
  Layout.preferredHeight: 36
  radius: 8
  visible: side.view.pageMatches(title)
  // The open pane's grey is the sidebar's one gliding highlight (see
  // SettingsView); a row only lights up itself while hovered.
  color: !selected && sideMouse.containsMouse ? side.view.host.theme.fill("quiet") : "transparent"
  Behavior on color { MotionColorAnimation { theme: side.view.host.theme } }
  scale: sideMouse.pressed ? 0.985 : 1
  Behavior on scale { MotionAnimation { theme: side.view.host.theme; pace: sideMouse.pressed ? "press" : "standard" } }
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 6
    anchors.rightMargin: 8
    spacing: 11
    PaneIcon {
      view: side.view
      Layout.preferredWidth: 24
      Layout.preferredHeight: 24
      flat: true
      glyph: side.info.icon || ""
      tint: side.info.color || side.view.accent
      layers: side.info.layers || []
    }
    Text {
      Layout.fillWidth: true
      text: side.title
      elide: Text.ElideRight
      // A size up from the rows, semibold for the open pane and a touch dimmer
      // for the rest, as macOS's sidebars.
      readonly property int size: side.view.host.theme.px(14)
      color: side.selected ? side.view.text : side.view.host.theme.withAlpha(side.view.text, 0.85)
      font.family: side.view.host.theme.textFontFamily
      font.letterSpacing: side.view.host.theme.tracking(side.view.host.theme.textFontFamily, size)
      font.pixelSize: size
      font.weight: side.selected ? Font.DemiBold : Font.Medium
    }
  }
  MouseArea {
    id: sideMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: side.view.currentPage = side.title
  }
}
