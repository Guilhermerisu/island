import QtQuick
import QtQuick.Layouts

// A group of rows under a grey section title (and an optional count after
// it), with an optional footnote.
// `view` is the SettingsView, for its colours.
ColumnLayout {
  id: group
  required property var view
  property string title: ""
  property string count: ""
  property string footer: ""
  default property alias rows: groupBody.data
  Layout.fillWidth: true
  spacing: 8
  Row {
    visible: group.title !== ""
    Layout.leftMargin: 14
    spacing: 7
    Text {
      text: group.title
      color: group.view.textMuted
      font.family: group.view.host.theme.textFontFamily
      font.letterSpacing: group.view.host.theme.tracking(group.view.host.theme.textFontFamily, group.view.detailFontSize)
      font.pixelSize: group.view.detailFontSize
      font.weight: Font.Medium
    }
    Text {
      visible: group.count !== ""
      text: group.count
      color: group.view.host.theme.withAlpha(group.view.textMuted, 0.7)
      font.family: group.view.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.letterSpacing: group.view.host.theme.tracking(group.view.host.theme.textFontFamily, group.view.detailFontSize)
      font.pixelSize: group.view.detailFontSize
    }
  }
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: groupBody.implicitHeight
    radius: group.view.host.theme.radii.card
    color: group.view.card
    border.width: 1
    border.color: group.view.edge
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
    Layout.leftMargin: 14
    Layout.rightMargin: 14
    text: group.footer
    wrapMode: Text.WordWrap
    color: group.view.textMuted
    font.family: group.view.host.theme.textFontFamily
    font.letterSpacing: group.view.host.theme.tracking(group.view.host.theme.textFontFamily, group.view.detailCaptionFontSize)
    font.pixelSize: group.view.detailCaptionFontSize
  }
}
