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
  Layout.preferredHeight: 32
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
    spacing: 9
    PaneIcon {
      view: side.view
      Layout.preferredWidth: 22
      Layout.preferredHeight: 22
      glyph: side.info.icon || ""
      tint: side.info.color || side.view.accent
      layers: side.info.layers || []
    }
    Text {
      Layout.fillWidth: true
      text: side.title
      elide: Text.ElideRight
      color: side.view.text
      font.family: side.view.host.theme.textFontFamily
      font.letterSpacing: side.view.host.theme.tracking(side.view.host.theme.textFontFamily, side.view.detailFontSize)
      font.pixelSize: side.view.detailFontSize
      font.weight: side.selected ? Font.Medium : Font.Normal
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
