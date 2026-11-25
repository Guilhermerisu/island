import QtQuick
import QtQuick.Layouts
import "../../../components"

// One row of a group: an optional icon, label (and optional detail) on the
// left, a control on the right, and a hairline under every row but the
// last, inset to where the text starts (past the icon), as macOS's lists.
// `indent` sets a row in under the one it belongs to.
// Settings' search finds a row by its label, detail, group title and
// `keywords`, and tints the ones it found.
// `view` is the SettingsView, for its colours.
Item {
  id: row
  required property var view
  property string label: ""
  property string detail: ""
  property bool last: false
  property string icon: ""
  property color iconTint: view.accent
  // A status dot before the detail (a connection's green), or none.
  property color detailDot: "transparent"
  property int indent: 0
  // More words the search should find it by.
  property string keywords: ""
  // Off for a row that's hidden for now (its addon is off, or it only
  // applies to another choice), so the search doesn't send you to it; a
  // hidden group's rows likewise (see SettingsGroup).
  property bool searchable: true
  property string groupTitle: ""
  property Item searchGroup: null
  readonly property string searchText: [label, detail, keywords, groupTitle].join(" ")
  readonly property bool searchHit: searchable && (!searchGroup || searchGroup.searchable !== false)
    && !!view.matches && view.matches(searchText)
  Component.onCompleted: if (view.registerSearchable) view.registerSearchable(row)
  Component.onDestruction: if (view.unregisterSearchable) view.unregisterSearchable(row)
  default property alias control: slot.data
  Layout.fillWidth: true
  // At least 50, with 8 over and under the text; grows with the text size
  // so a larger label and detail keep their margins.
  implicitHeight: Math.max(50, labels.implicitHeight + 16)
  // A row the search found.
  Rectangle {
    anchors.fill: parent
    anchors.margins: 3
    radius: row.view.host.theme.radii.medium
    color: row.view.host.theme.accentFill("soft")
    opacity: row.searchHit ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: row.view.host.theme; pace: "fade"; curve: "fade" } }
  }
  PaneIcon {
    id: rowIcon
    visible: row.icon !== ""
    view: row.view
    x: 12 + row.indent
    anchors.verticalCenter: parent.verticalCenter
    width: 24
    height: 24
    glyphSize: 14
    flat: true
    glyph: row.icon
    tint: row.iconTint
  }
  Column {
    id: labels
    anchors.left: parent.left
    anchors.leftMargin: 12 + row.indent + (row.icon !== "" ? rowIcon.width + 11 : 0)
    anchors.right: slot.left
    anchors.rightMargin: 11
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    Text {
      width: parent.width
      text: row.label
      elide: Text.ElideRight
      color: row.view.text
      font.family: row.view.host.theme.textFontFamily
      font.letterSpacing: row.view.host.theme.tracking(row.view.host.theme.textFontFamily, row.view.rowTitleFontSize)
      font.pixelSize: row.view.rowTitleFontSize
    }
    Row {
      width: parent.width
      visible: row.detail !== ""
      spacing: 5
      Rectangle {
        id: detailDot
        visible: row.detailDot.a > 0
        anchors.verticalCenter: parent.verticalCenter
        width: 6; height: 6; radius: 3
        color: row.detailDot
      }
      Text {
        width: parent.width - (detailDot.visible ? detailDot.width + parent.spacing : 0)
        text: row.detail
        elide: Text.ElideRight
        color: row.view.textMuted
        font.family: row.view.host.theme.textFontFamily
        font.letterSpacing: row.view.host.theme.tracking(row.view.host.theme.textFontFamily, row.view.detailCaptionFontSize)
        font.pixelSize: row.view.detailCaptionFontSize
      }
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
    anchors.leftMargin: labels.anchors.leftMargin
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: row.view.divider
  }
}
