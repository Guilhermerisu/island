import QtQuick
import QtQuick.Layouts

// The header System Settings puts at the top of a pane: the pane's icon,
// its name, and what it's for. Hidden for an addon pane that draws its own
// (`header: false`, see addons/Addon.qml).
// Spaced by what's drawn, not by the text boxes (whose ascent and descent
// would add their own gaps): 18 over the icon, 6 from the icon to the
// title's capitals, 6 from the title's baseline to the description's
// capitals, and 16 from the description's last baseline to the bottom.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: header
  required property var view
  property string page: ""
  readonly property var info: header.view.pageInfo[page] || ({})
  visible: header.info.header !== false
  Layout.fillWidth: true
  // The text under the last baseline (its descent), taken back from the 16.
  readonly property real tail: about.visible ? aboutMetrics.descent : titleMetrics.descent
  implicitHeight: 18 + headerColumn.implicitHeight - tail + 16
  radius: header.view.host.theme.radii.card
  color: header.view.card
  border.width: 1
  border.color: header.view.edge

  FontMetrics { id: titleMetrics; font: title.font }
  FontMetrics { id: aboutMetrics; font: about.font }
  // A capital's height, from the baseline up.
  TextMetrics { id: titleCap; font: title.font; text: "H" }
  TextMetrics { id: aboutCap; font: about.font; text: "H" }

  ColumnLayout {
    id: headerColumn
    x: 16
    y: 18
    width: parent.width - 32
    spacing: 0
    PaneIcon {
      view: header.view
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: 44
      Layout.preferredHeight: 44
      flat: true
      glyph: header.info.icon || ""
      tint: header.info.color || header.view.accent
      layers: header.info.layers || []
    }
    Text {
      id: title
      Layout.fillWidth: true
      Layout.topMargin: 6 - (titleMetrics.ascent + titleCap.tightBoundingRect.y)
      horizontalAlignment: Text.AlignHCenter
      text: header.page
      color: header.view.text
      font.family: header.view.host.theme.textFontFamily
      font.pixelSize: header.view.paneTitleFontSize
      font.weight: Font.DemiBold
      font.variableAxes: ({ "wght": 600 })
      font.letterSpacing: header.view.host.theme.tracking(header.view.host.theme.textFontFamily, header.view.paneTitleFontSize)
    }
    Text {
      id: about
      Layout.fillWidth: true
      Layout.topMargin: 6 - titleMetrics.descent - (aboutMetrics.ascent + aboutCap.tightBoundingRect.y)
      visible: text !== ""
      horizontalAlignment: Text.AlignHCenter
      text: header.info.about || ""
      wrapMode: Text.WordWrap
      color: header.view.textMuted
      font.family: header.view.host.theme.textFontFamily
      font.letterSpacing: header.view.host.theme.tracking(header.view.host.theme.textFontFamily, header.view.calloutFontSize)
      font.pixelSize: header.view.calloutFontSize
    }
  }
}
