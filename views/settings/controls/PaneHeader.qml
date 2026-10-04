import QtQuick
import QtQuick.Layouts

// The header System Settings puts at the top of a pane: the pane's icon,
// its name, and what it's for.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: header
  required property var view
  property string page: ""
  property bool compact: false
  readonly property var info: header.view.pageInfo[page] || ({})
  Layout.fillWidth: true
  implicitHeight: headerColumn.implicitHeight + (compact ? 12 : 36)
  radius: 12
  color: compact ? "transparent" : header.view.card
  border.width: compact ? 0 : 1
  border.color: header.view.host.theme.withAlpha(header.view.text, 0.04)
  Column {
    id: headerColumn
    anchors.centerIn: parent
    width: header.compact ? parent.width - 4 : Math.min(parent.width - 48, 380)
    spacing: header.compact ? 6 : 8
    PaneIcon {
      visible: !header.compact
      view: header.view
      anchors.horizontalCenter: parent.horizontalCenter
      width: 48
      height: 48
      glyph: header.info.icon || ""
      tint: header.info.color || header.view.accent
      layers: header.info.layers || []
    }
    Text {
      width: parent.width
      horizontalAlignment: header.compact ? Text.AlignLeft : Text.AlignHCenter
      text: header.page
      color: header.view.text
      font.family: "Adwaita Sans"
      font.pixelSize: header.compact ? 22 : header.view.detailTitleFontSize
      font.weight: Font.Bold
    }
    Text {
      width: parent.width
      visible: text !== ""
      horizontalAlignment: header.compact ? Text.AlignLeft : Text.AlignHCenter
      text: header.info.about || ""
      wrapMode: Text.WordWrap
      lineHeight: 1.1
      color: header.view.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: header.view.detailFontSize - 1
    }
  }
}
