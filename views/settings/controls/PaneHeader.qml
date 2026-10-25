import QtQuick
import QtQuick.Layouts

// The header System Settings puts at the top of a pane: the pane's icon,
// its name, and what it's for. Hidden for an addon pane that draws its own
// (`header: false`, see addons/Addon.qml).
// `view` is the SettingsView, for its colours.
Rectangle {
  id: header
  required property var view
  property string page: ""
  property bool compact: false
  readonly property var info: header.view.pageInfo[page] || ({})
  visible: header.info.header !== false
  Layout.fillWidth: true
  implicitHeight: headerColumn.implicitHeight + (compact ? 12 : 30)
  radius: header.view.host.theme.radii.card
  color: compact ? "transparent" : header.view.card
  border.width: compact ? 0 : 1
  border.color: header.view.edge
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
      flat: true
      glyph: header.info.icon || ""
      tint: header.info.color || header.view.accent
      layers: header.info.layers || []
    }
    Text {
      width: parent.width
      horizontalAlignment: header.compact ? Text.AlignLeft : Text.AlignHCenter
      text: header.page
      color: header.view.text
      font.family: header.view.host.theme.textFontFamily
      font.pixelSize: header.compact ? header.view.host.theme.px(22) : header.view.detailTitleFontSize
      font.weight: Font.Bold
      font.variableAxes: header.view.titleFontAxes
      font.letterSpacing: -0.3
    }
    Text {
      width: parent.width
      visible: text !== ""
      horizontalAlignment: header.compact ? Text.AlignLeft : Text.AlignHCenter
      text: header.info.about || ""
      wrapMode: Text.WordWrap
      lineHeight: 1.1
      color: header.view.textMuted
      font.family: header.view.host.theme.textFontFamily
      font.letterSpacing: header.view.host.theme.tracking(header.view.host.theme.textFontFamily, header.view.detailFontSize)
      font.pixelSize: header.view.detailFontSize
    }
  }
}
