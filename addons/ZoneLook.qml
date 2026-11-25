import QtQuick
import "../views/settings/controls"

// What a Settings page reads from its `view` (the SettingsView): colours,
// font sizes, the host, the pop-up menu. Stands in for it when a page is
// mounted as a control center zone (see AddonZone), with the control center's
// colours so the page sits in it like the other cards. One for the whole
// control center, over it, so a menu isn't held inside a card; no font picker,
// which no page mounted as a zone has. `center` is the ControlCenter.
Item {
  id: look
  required property var center
  readonly property var host: center.host
  readonly property var settings: host.settings
  readonly property bool active: center.active
  readonly property color panel: host.theme.background
  readonly property color text: center.text
  readonly property color textMuted: center.textMuted
  readonly property color card: center.card
  readonly property color edge: center.edge
  readonly property color divider: center.edge
  readonly property color well: center.well
  readonly property color wellHover: host.theme.wellHover
  readonly property color accent: center.accent
  readonly property color accentInk: center.accentInk
  // The controls' greys (see SettingsView).
  readonly property color textTertiary: host.theme.tertiary
  readonly property bool dark: host.theme.background.hslLightness < 0.5
  function ink(alpha) { return dark ? Qt.rgba(1, 1, 1, alpha) : host.theme.withAlpha(host.theme.text, alpha) }
  readonly property color controlFill: dark ? "#2c2c2e" : host.theme.tile
  readonly property color segmentChip: dark ? "#636366" : Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.31))
  readonly property color switchOff: dark ? "#3a3a3c" : host.theme.solid("stronger")
  readonly property color insetFill: dark ? "#111113" : host.theme.solid("quiet")
  readonly property int groupRadius: 12
  readonly property int detailFontSize: host.theme.px(13)
  readonly property int rowTitleFontSize: host.theme.px(14)
  readonly property int detailCaptionFontSize: host.theme.px(11)
  readonly property int calloutFontSize: host.theme.px(12)
  readonly property int detailTitleFontSize: host.theme.px(22)
  readonly property var titleFontAxes: ({ "wght": 500 })
  readonly property int controlWidth: 156
  // The pages' spacing (see SettingsView).
  readonly property int contentPadding: 16
  readonly property int groupSpacing: 12
  readonly property int titleSpacing: 6

  property alias menuButton: popMenu.button
  function openMenu(button) { popMenu.openFor(button) }
  Connections {
    target: look.center
    function onActiveChanged() { look.menuButton = null }
    function onEditModeChanged() { look.menuButton = null }
  }
  MouseArea {
    anchors.fill: parent
    z: 49
    visible: look.menuButton !== null
    onClicked: look.menuButton = null
    onWheel: function(wheel) { look.menuButton = null }
  }
  SettingsMenu { id: popMenu; view: look }
}
