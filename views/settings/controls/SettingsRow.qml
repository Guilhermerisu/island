import QtQuick
import QtQuick.Layouts

// One row of a group: an optional icon, label (and optional detail) on the
// left, a control on the right, and a hairline under every row but the last.
// `indent` sets a row in under the one it belongs to.
// `view` is the SettingsView, for its colours.
Item {
  id: row
  required property var view
  property string label: ""
  property string detail: ""
  property bool last: false
  property string icon: ""
  property color iconTint: view.accent
  property int indent: 0
  default property alias control: slot.data
  Layout.fillWidth: true
  implicitHeight: detail !== "" ? 54 : 42
  PaneIcon {
    id: rowIcon
    visible: row.icon !== ""
    view: row.view
    x: 14 + row.indent
    anchors.verticalCenter: parent.verticalCenter
    width: 28
    height: 28
    glyph: row.icon
    tint: row.iconTint
  }
  Column {
    anchors.left: parent.left
    anchors.leftMargin: 14 + row.indent + (row.icon !== "" ? rowIcon.width + 12 : 0)
    anchors.right: slot.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    Text {
      width: parent.width
      text: row.label
      elide: Text.ElideRight
      color: row.view.text
      font.family: "Adwaita Sans"
      font.pixelSize: row.view.detailFontSize
    }
    Text {
      width: parent.width
      visible: row.detail !== ""
      text: row.detail
      elide: Text.ElideRight
      color: row.view.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: row.view.detailCaptionFontSize
    }
  }
  Item {
    id: slot
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }
  Rectangle {
    visible: !row.last
    anchors.left: parent.left
    anchors.leftMargin: 14 + row.indent
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.bottom: parent.bottom
    height: 1
    color: row.view.divider
  }
}
