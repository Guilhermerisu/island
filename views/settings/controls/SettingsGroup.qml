import QtQuick
import QtQuick.Layouts

// A group of rows under a grey section title in sentence case ("Clock",
// never uppercased), with an optional count at the title row's right end
// and a footnote.
// `view` is the SettingsView, for its colours.
ColumnLayout {
  id: group
  required property var view
  property string title: ""
  property string count: ""
  property string footer: ""
  // Its rows are found by this too (see SettingsRow); off for a group
  // that's hidden for now, so the search doesn't find its rows.
  readonly property string searchTitle: title
  property bool searchable: true
  default property alias rows: groupBody.data
  Layout.fillWidth: true
  spacing: group.view.titleSpacing
  RowLayout {
    visible: group.title !== ""
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    spacing: 6
    readonly property int size: group.view.calloutFontSize
    Text {
      Layout.fillWidth: true
      elide: Text.ElideRight
      text: group.title
      color: group.view.textMuted
      font.family: group.view.host.theme.textFontFamily
      font.capitalization: Font.MixedCase
      font.letterSpacing: group.view.host.theme.tracking(group.view.host.theme.textFontFamily, parent.size)
      font.pixelSize: parent.size
      font.weight: Font.DemiBold
    }
    Text {
      visible: group.count !== ""
      text: group.count
      color: group.view.textTertiary
      font.family: group.view.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.letterSpacing: group.view.host.theme.tracking(group.view.host.theme.textFontFamily, parent.size)
      font.pixelSize: parent.size
    }
  }
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: groupBody.implicitHeight
    radius: group.view.groupRadius
    color: group.view.card
    ColumnLayout {
      id: groupBody
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 0
    }
  }
  Text {
    visible: group.footer !== ""
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    text: group.footer
    wrapMode: Text.WordWrap
    color: group.view.textMuted
    font.family: group.view.host.theme.textFontFamily
    font.letterSpacing: group.view.host.theme.tracking(group.view.host.theme.textFontFamily, group.view.detailCaptionFontSize)
    font.pixelSize: group.view.detailCaptionFontSize
  }
}
