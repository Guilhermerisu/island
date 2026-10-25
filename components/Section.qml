import QtQuick
import QtQuick.Layouts

// A System Settings group for the widget panes (System Stats, Agents): a
// bold title over the box, with the reading's meaning on the right as a
// coloured dot and a word, or (in `accessory`) a control such as a search
// field. With no title, just the box.
ColumnLayout {
  id: section
  required property var view
  property string title: ""
  // A number after the title, quieter (the processes listed).
  property string count: ""
  property string status: ""
  property color statusColor: "#30d158"
  default property alias content: box.data
  property alias accessory: accessorySlot.data
  spacing: 7

  RowLayout {
    visible: section.title !== ""
    Layout.fillWidth: true
    Layout.leftMargin: 14
    Layout.rightMargin: 14
    Layout.minimumHeight: 20
    spacing: 6
    Text {
      text: section.title
      elide: Text.ElideRight
      color: section.view.text
      font.family: section.view.host.theme.textFontFamily
      font.letterSpacing: section.view.host.theme.tracking(section.view.host.theme.textFontFamily, section.view.detailFontSize)
      font.pixelSize: section.view.detailFontSize
      font.weight: Font.DemiBold
    }
    Text {
      visible: section.count !== ""
      Layout.leftMargin: 1
      text: section.count
      color: section.view.textMuted
      font.family: section.view.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.letterSpacing: section.view.host.theme.tracking(section.view.host.theme.textFontFamily, section.view.detailCaptionFontSize)
      font.pixelSize: section.view.detailCaptionFontSize
    }
    Item { Layout.fillWidth: true }
    Rectangle {
      visible: section.status !== ""
      Layout.alignment: Qt.AlignVCenter
      width: 7
      height: 7
      radius: 3.5
      color: section.statusColor
    }
    Text {
      visible: section.status !== ""
      text: section.status
      color: section.view.textMuted
      font.family: section.view.host.theme.textFontFamily
      font.letterSpacing: section.view.host.theme.tracking(section.view.host.theme.textFontFamily, section.view.detailCaptionFontSize)
      font.pixelSize: section.view.detailCaptionFontSize
    }
    Row { id: accessorySlot }
  }
  ColumnLayout {
    id: box
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 0
  }
}
