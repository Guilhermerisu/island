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
//           the clock hidden. With `pillFills` instead, it only fills the
//           island (a pill grown on hover), keeping its place in the order.
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
//           Zone sizes. The user sets each zone XSmall, Small or Normal (the
//           default, all of the above) in edit mode; a zone is told its
//           size as `zoneSize`: "xsmall" | "small" | "normal", and, for XSmall,
//           its line as `zoneRoom`. Where each is:
//             view, page  `property string zoneSize` and `property real
//                         zoneRoom` on the item, set (and kept up to date)
//                         only if it declares them. No declaration: it is
//                         drawn as Normal.
//             drawn zone  `zoneSize: parent.zoneSize` (and `zoneRoom:
//                         parent.zoneRoom` if it is not an AddonZone) in the
//                         component's root, as `center: parent.center` (the
//                         Loader's); a root that is an AddonZone already has
//                         `zoneSize` and `room`.
//             ControlLayout, NotificationHistory  `property string zoneSize`,
//                         `property real zoneRoom` (set by ZoneCard).
//           A zone is as tall as it is, and nothing scrolls inside a zone:
//           when the zones are taller than the island may be (the height the
//           user chose on its handle, setting `controlCenterMaxHeight`, 780
//           by default, within the screen), it is the island's page that
//           scrolls. An island whose zones are shorter than that is as short
//           as they are.
//             xsmall  one line: center.zoneXsHeight = 58 (a third of a column
//                     at the island's least height, 260), or the content's
//                     implicitHeight if that is more (a zone of several
//                     rows). In an AddonZone the padding is 8 and the
//                     content has `room` = 42, centered in it if shorter. A
//                     click is a direct action; if the addon has a view, it
//                     opens it with `host.view = "<name>"`, else the zone
//                     does nothing.
//             small, normal  the height the content has (its implicitHeight,
//                     in an AddonZone the card's: content plus padding 12
//                     (small) or 16 (normal)), whatever it is: 80 or 400.
//                     Nothing is cut and nothing has to stretch. Small and
//                     Normal differ only in the body's style (below) and the
//                     padding.
//           Edit mode changes none of this: every zone keeps the size, the
//           height and the content it has outside it. What editing adds is a
//           title bar ABOVE each zone, in the column: 28 px and a gap, with
//           the zone's grip, name, XS · S · M and − (see ZoneCard). The bars
//           are on top of the zones' heights, so no zone is smaller than
//           outside edit mode. A zone is a preview under its bar (no click,
//           hover or wheel to its body; the wheel goes to the page), so a body
//           need not do anything for editing. The island in edit mode is the
//           header, the zones with their bars, the bar's handle, the add panel
//           and the panel's own handle (setting
//           `controlCenterEditPanelHeight`, 0 for the default), up to the
//           screen, the panel shrinking first; the page scrolls beyond. The
//           one exception is a zone with its own editing (the grid,
//           `editable` zones): it keeps the pointer in every size (XS pips,
//           S tiles, Normal), each with its −, reordered by dragging and
//           added to by a drop from the panel; its content is as outside edit
//           mode but for a little room around it for the −.
//           `zoneRoom` (a body that is not in an AddonZone) and `room`
//           (AddonZone, less the padding) are INFORMATIVE: XS has its line
//           (58, room 42, a constant that can be used: a Row of `room`
//           height centered in it), Small and Normal have none (infinite:
//           the height is the content's own, never read it for them). The
//           content is drawn at the height it has and is never spread over a
//           room. Never derive the content's implicitHeight (nor its
//           visibility) from `room` / `zoneRoom`: the height of the zone
//           comes from that implicitHeight, so it would loop. A plain body's
//           `zoneRoom` is the whole line (no card padding). In an AddonZone
//           the mounted view or page gets `zoneRoom` = the card's `room`.
//           The size picks the style: xsmall is one line, small is compact,
//           normal is the complete one (unchanged). An addon draws a visual
//           of its own for xsmall and small, not its Normal one cut: in a
//           drawn zone it swaps what the AddonZone holds (`visible:
//           zone.zoneSize === "xsmall"`, and the like), and a view or page
//           that is made for zones does likewise on its own `zoneSize`. In
//           edit mode a zone is told the size it has, as outside it.
//           Nothing is out of reach in xsmall and small: whatever can be done
//           in the Normal zone can be done from the smaller ones, by a
//           popover (below), a click that opens the addon's view
//           (`host.view = "<name>"`), or its Settings page
//           (`host.view = "settings"`).
//           Zone popover. Any zone body opens one with
//             center.openPopover(anchorItem, component, properties)
//             center.closePopover()      center.popoverOpen
//           `anchorItem` is the item it sits under (the popover is centered on
//           it, above it if there is no room below, kept within the control
//           center and what the page shows); `component` is a Component made
//           when it opens, with `properties` as its initial properties (so a
//           `required property` works), and destroyed once the popover has
//           faded out; the popover sets its `width` and `height` (as wide as
//           its `implicitWidth` up to 280 px or its zone's width if that is
//           narrower, filling that if the implicit one is 0; as tall as its
//           `implicitHeight` within what is in view; 8 px of padding around).
//           It is over all the columns, so no zone's clip cuts it. One at a
//           time: opening another replaces it. It closes on a click anywhere
//           outside (also on the anchor, so a second click on the button
//           that opened it toggles), Esc, the control center closing, edit
//           mode starting, the page or the anchor's zone scrolling, the
//           anchor being destroyed, and closePopover(). Content can close
//           itself with `center.closePopover()`. For example, from a zone:
//             Item {
//               id: chip
//               property var center            // the ControlCenter
//               MouseArea {
//                 id: more; width: 24; height: 24
//                 onClicked: chip.center.openPopover(more, sources, { host: chip.center.host })
//               }
//               Component {
//                 id: sources
//                 Column {
//                   required property var host
//                   implicitWidth: 220; implicitHeight: 120
//                   // ... a ListPicker, buttons ...
//                 }
//               }
//             }
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
  property bool pillFills: false
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
