import QtQuick
import QtQuick.Layouts
import "../../components"

// What can be added to the control center, in edit mode, across its whole
// width under the columns: the controls that aren't in the grid, the plugins
// not yet pinned, and the zones that aren't on show. Each section has its own
// file (ControlGallery, PluginGallery, ZoneGallery); the list scrolls. A
// control dragged out of the grid, or a plugin out of the Plugins zone, onto
// the panel is removed (see ControlLayout, PluginsZone). `center` is the ControlCenter.
Rectangle {
  id: panel
  required property var center
  // The control grid's layout, while its zone is on show: what a control
  // card is dragged through.
  readonly property var layout: center.controlLayout
  // A control or a pinned plugin is dragged over it, to be removed.
  readonly property bool removing: (!!layout && layout.removeDropActive) || (!!center.pluginsZone && center.pluginsZone.removeDropActive)
  // The grid's cards need its zone; without it there's nothing to add them to.
  readonly property bool hasControls: center.zones.absent.indexOf("controls") === -1
  // The cards in a row: always even, so a wide card (two cells) never leaves
  // a gap at the end of one.
  readonly property int cardColumns: 2 * Math.max(1, Math.floor(scroll.width / 500))
  // What a card is wide: a cell of the row, set here, not from the grid it
  // sits in, so that one card alone doesn't stretch to the whole width.
  readonly property real cardWidth: scroll.width / cardColumns
  function resetScroll() { scroll.contentY = 0 }

  visible: center.editMode
  opacity: visible ? 1 : 0
  Behavior on opacity { enabled: panel.center.settled; MotionAnimation { theme: panel.center.host.theme; pace: "fade"; curve: "fade" } }
  Layout.fillWidth: true
  Layout.preferredHeight: content.implicitHeight + 26
  radius: center.cardRadius
  color: center.host.theme.solid("quiet")
  border.width: 1
  border.color: center.edge

  component SectionTitle: Text {
    Layout.leftMargin: 4
    color: panel.center.text
    font.family: panel.center.host.theme.textFontFamily
    font.letterSpacing: panel.center.host.theme.tracking(panel.center.host.theme.textFontFamily, panel.center.host.theme.px(13))
    font.pixelSize: panel.center.host.theme.px(13)
    font.weight: Font.DemiBold
  }

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: 12
    anchors.topMargin: 14
    spacing: 10
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4
      Layout.rightMargin: 4
      SectionTitle { text: "Add"; Layout.leftMargin: 0 }
      Item { Layout.fillWidth: true }
      Text {
        text: panel.removing ? "Release to remove" : "Drag in or click +"
        color: panel.center.textMuted
        font.family: panel.center.host.theme.textFontFamily
        font.letterSpacing: panel.center.host.theme.tracking(panel.center.host.theme.textFontFamily, panel.center.host.theme.px(11))
        font.pixelSize: panel.center.host.theme.px(11)
      }
    }
    Flickable {
      id: scroll
      OverlayScrollbar { flickable: scroll; parent: scroll; theme: panel.center.host.theme }
      Layout.fillWidth: true
      Layout.preferredHeight: 260
      contentWidth: width
      contentHeight: sections.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      ColumnLayout {
        id: sections
        width: scroll.width
        spacing: 8
        SectionTitle { visible: panel.hasControls; text: "Controls" }
        ControlGallery { visible: panel.hasControls; Layout.fillWidth: true; panel: panel }
        SectionTitle { Layout.topMargin: 8; text: "Plugins" }
        PluginGallery { Layout.fillWidth: true; panel: panel }
        SectionTitle { Layout.topMargin: 8; text: "Zones" }
        ZoneGallery { Layout.fillWidth: true; panel: panel }
      }
    }
  }
}
