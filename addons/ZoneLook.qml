import QtQuick

// What a Settings page reads from its `view` (the SettingsView): colours,
// font sizes, the host. Stands in for it when a page is mounted as a control
// center zone (see AddonZone), with the control center's colours so the page
// sits in it like the other cards. `center` is the ControlCenter.
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
  readonly property int detailFontSize: host.theme.px(13)
  readonly property int detailCaptionFontSize: host.theme.px(11)
  readonly property int detailTitleFontSize: host.theme.px(22)
  readonly property var titleFontAxes: ({ "wght": 500 })
  readonly property int controlWidth: 156
}
