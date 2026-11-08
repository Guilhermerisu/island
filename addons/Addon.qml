import QtQuick

// An addon's root (see Addons.qml): loaded once while the addon is enabled,
// it holds the addon's state. What it adds to the island is declared here
// as Components, which the island makes on each screen:
//
//   pill    its live activity, drawn over the whole island while pillShown,
//           which the island sizes to pillWidth × pillHeight, its corners
//           rounded to pillRadius when set (for a pill grown too tall to
//           stay a capsule). Show it with
//           host.showFeedback("", ms, "addon:" + addon.id), or hold the
//           resting island with it for as long as `ongoing` is set (over
//           the media and download pills), the clock kept in its middle.
//           With `pillAsks` set too, the pill is a question waiting for
//           an answer (Displays' "Keep these display settings?"): it goes
//           ahead of the other addons' ongoing pills and fills the island,
//           the clock hidden.
//   views   [{ name, width, padding, component }], each opened with
//           `show <name>`; its item is on screen while host.view is name.
//           An item with surfaceWidth, surfacePadding, or surfaceRadius
//           (corner radius) shapes the island to them as they change.
//   tiles   [{ key, title, wide, present, component }], control center cards.
//           Each component's parent has `center` (the ControlCenter),
//           `controlKey`, and `galleryPreview`, as the core cards get.
//   zone    the addon's place in the control center, where the user can put
//           it in any of its 1 to 3 columns. Nothing to write: the zone is
//           the addon's first view, or without views its first settingsPage,
//           in a card (AddonZone), the registry's `zone: true` in Addons.qml
//           being all it takes. The view (or page) is made as wide as the
//           column less the card's padding, as tall as its implicitHeight,
//           and is given what it needs to be one of several zones on screen:
//             view   `inZone: true` if it has the property (it then leaves
//                    the keyboard to the control center, whose Esc closes
//                    it, and doesn't close or hide itself), and `active`
//                    following the control center being open;
//             page   the same `inZone`, its `view` a ZoneLook (the colours,
//                    sizes and host a SettingsView gives), and `shown`
//                    following the zone being on screen.
//           A column narrower than the entry's `zone.minWidth` (else the
//           view's width less its padding, once the addon is on) shows a
//           warning in its place. An addon whose view isn't right in a column
//           sets `zone` here to a Component of its own (made in a Loader, its
//           parent, with `center` (the ControlCenter) and `zoneActive`; wrap
//           it in AddonZone for the card).
//   zones   for an addon with several: { key: Component } of the ones it
//           draws itself; a key without one is the first view as above. Named
//           by the entry's `zones: [{ key, title, minWidth, editable }]`
//           (`editable` keeps the zone's content in edit mode, for one with
//           its own editing). Their ids are "addon:<id>/<key>"; a lone `zone`
//           is "addon:<id>".
//   zoneViews  how many of its zones are on screen (AddonZone counts them in
//           and out): an addon that only needs to work while its content is
//           shown, a sampler, reads `host.view === "settings" || zoneViews > 0`.
//   settingsPages  [{ title, icon, color, about, search, source,
//           properties }], each a pane in Settings' sidebar after Addons,
//           made from the file at `source` with `properties` and `view`
//           (the SettingsView) while it's the open pane, and told `shown`
//           while Settings is on screen too. With `header: false` the
//           pane draws its own header in place of Settings' icon, title,
//           and `about`.
//   launcherRow(text)  a row the launcher adds for its typed text, or null:
//           { glyph, tile, ink, label, detail, first, run }, a glyph on a
//           tile of its colors, then label and muted detail. `first` puts
//           it above the apps (it is also first when no app matches), and
//           `run` is called when it's chosen. launcherHint ("ask") joins
//           the search field's placeholder: "Search or ask".
//
// `addon` is its id and name, plus option(key) and setOption(key, value).
Item {
  id: addonRoot
  required property var host
  required property var addon

  property Component pill: null
  property bool ongoing: false
  property bool pillAsks: false
  readonly property bool pillShown: host.addonPill === addonRoot
  property real pillWidth: 280
  // The island's live-activity height; a pill that grows starts from it.
  readonly property real restHeight: host.pillHeight
  property real pillHeight: restHeight
  property real pillRadius: 0
  function pillClicked() { host.view = "controls" }

  property var views: []
  property var tiles: []
  property Component zone: null
  property var zones: ({})
  property int zoneViews: 0
  property var settingsPages: []
  property string launcherHint: ""
  function launcherRow(text) { return null }
}
