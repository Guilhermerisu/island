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
  color: selected ? side.view.accent : sideMouse.containsMouse ? side.view.host.theme.withAlpha(side.view.text, 0.06) : "transparent"
  Behavior on color { MotionColorAnimation { theme: side.view.host.theme } }
  scale: sideMouse.pressed ? 0.985 : 1
  Behavior on scale { MotionAnimation { theme: side.view.host.theme; pace: sideMouse.pressed ? "press" : "standard" } }
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 10
    PaneIcon {
      view: side.view
      Layout.preferredWidth: 26
      Layout.preferredHeight: 26
      glyph: side.info.icon || ""
      tint: side.info.color || side.view.accent
      onAccent: side.selected
    }
    Text {
      Layout.fillWidth: true
      text: side.title
      elide: Text.ElideRight
      color: side.selected ? side.view.accentInk : side.view.text
      font.family: side.view.host.theme.textFontFamily
      font.pixelSize: 15
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
