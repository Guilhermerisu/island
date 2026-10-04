import QtQuick

// An addon's root (see Addons.qml): loaded once while the addon is enabled,
// it holds the addon's state. What it adds to the island is declared here
// as Components, which the island makes on each screen:
//
//   pill    its live activity, drawn over the whole island while pillShown,
//           which the island sizes to pillWidth × pillHeight. Show it with
//           host.showFeedback("", ms, "addon:" + addon.id), or hold the
//           resting island with it for as long as `ongoing` is set (over
//           the media and download pills), the clock kept in its middle.
//   views   [{ name, width, padding, component }], each opened with
//           `show <name>`; its item is on screen while host.view is name.
//   tiles   [{ key, title, wide, present, component }], control center cards.
//           Each component's parent has `center` (the ControlCenter),
//           `controlKey`, and `galleryPreview`, as the core cards get.
//   settingsPages  [{ title, icon, color, about, search, source,
//           properties }], each a pane in Settings' sidebar after Addons,
//           made from the file at `source` with `properties` and `view`
//           (the SettingsView) while it's the open pane, and told `shown`
//           while Settings is on screen too.
//
// `addon` is its id and name, plus option(key) and setOption(key, value).
Item {
  id: addonRoot
  required property var host
  required property var addon

  property Component pill: null
  property bool ongoing: false
  readonly property bool pillShown: host.addonPill === addonRoot
  property real pillWidth: 280
  property real pillHeight: host.settings.notch ? 40 : 44
  function pillClicked() { host.view = "controls" }

  property var views: []
  property var tiles: []
  property var settingsPages: []
}
