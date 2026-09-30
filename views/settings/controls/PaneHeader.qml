import QtQuick
import QtQuick.Layouts

// The header System Settings puts at the top of a pane: the pane's icon,
// its name, and what it's for.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: header
  required property var view
  property string page: ""
  readonly property var info: header.view.pageInfo[page] || ({})
  Layout.fillWidth: true
  implicitHeight: headerColumn.implicitHeight + 36
  radius: 12
  color: header.view.card
  border.width: 1
  border.color: header.view.host.theme.withAlpha(header.view.text, 0.04)
  Column {
    id: headerColumn
    anchors.centerIn: parent
    width: Math.min(parent.width - 48, 380)
    spacing: 8
    PaneIcon {
      view: header.view
      anchors.horizontalCenter: parent.horizontalCenter
      width: 48
      height: 48
      glyph: header.info.icon || ""
      tint: header.info.color || header.view.accent
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: header.page
      color: header.view.text
      font.family: "Adwaita Sans"
      font.pixelSize: header.view.detailTitleFontSize
      font.weight: Font.Bold
    }
    Text {
      width: parent.width
      visible: text !== ""
      horizontalAlignment: Text.AlignHCenter
      text: header.info.about || ""
      wrapMode: Text.WordWrap
      lineHeight: 1.1
      color: header.view.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: header.view.detailFontSize - 1
    }
  }
}
