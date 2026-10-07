import QtQuick
import QtQuick.Layouts

// A group of rows under a bold section title, with an optional footnote.
// `view` is the SettingsView, for its colours.
ColumnLayout {
  id: group
  required property var view
  property string title: ""
  property string footer: ""
  default property alias rows: groupBody.data
  Layout.fillWidth: true
  spacing: 6
  Text {
    visible: group.title !== ""
    Layout.leftMargin: 2
    text: group.title
    color: group.view.text
    font.family: group.view.host.theme.textFontFamily
    font.pixelSize: group.view.detailFontSize
    font.weight: Font.DemiBold
  }
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: groupBody.implicitHeight
    radius: 10
    color: group.view.card
    border.width: 1
    border.color: group.view.host.theme.withAlpha(group.view.text, 0.04)
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
    Layout.leftMargin: 2
    text: group.footer
    wrapMode: Text.WordWrap
    color: group.view.textMuted
    font.family: group.view.host.theme.textFontFamily
    font.pixelSize: group.view.detailCaptionFontSize
  }
}
