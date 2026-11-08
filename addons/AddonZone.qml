import QtQuick

// The card an addon's content sits in as a control center zone (see `zone` in
// Addon.qml): the other cards' look, padded as CcSection is, and as tall as
// what's in it. Its parent is the zone's Loader, which says whether the
// control center is open (`zoneActive`), whose it is (`center`), and for an
// addon's, which (`addonRoot`).
//
// With `mount`, the card holds the addon's own content, so an addon needs
// nothing written for its zone: its first view (made with `inZone` set, and
// `active` following the control center), else its first Settings page (made
// with its `properties`, a ZoneLook as its `view`, `inZone` set, and `shown`
// following the zone). Both are told `inZone` only if they have it. Without,
// whatever is put in the card (a zone an addon draws itself).
Rectangle {
  id: card
  readonly property var center: parent.center
  readonly property bool zoneActive: !!parent.zoneActive
  default property alias content: body.data
  // A Settings page draws its own cards, so it goes without this one.
  readonly property real padding: mountedPage ? 0 : 16

  property bool mount: false
  readonly property var owner: mount ? parent.addonRoot : null
  readonly property var mountedView: owner ? (owner.views || [])[0] || null : null
  readonly property var mountedPage: owner && !mountedView ? (owner.settingsPages || [])[0] || null : null
  // On screen: the control center open and the card not folded to its title
  // bar by edit mode.
  readonly property bool shown: zoneActive && visible

  implicitHeight: body.height + 2 * padding
  radius: center.cardRadius
  color: mountedPage ? "transparent" : center.card
  border.width: mountedPage ? 0 : 1
  border.color: center.edge

  Item {
    id: body
    x: card.padding
    y: card.padding
    width: card.width - 2 * card.padding
    height: childrenRect.height

    Loader {
      width: parent.width
      height: item ? item.implicitHeight : 0
      active: !!card.mountedView
      sourceComponent: card.mountedView ? card.mountedView.component : null
      onLoaded: {
        if (item.inZone !== undefined) item.inZone = true
        if (item.active !== undefined) item.active = Qt.binding(function() { return card.zoneActive })
      }
    }
    Loader {
      id: page
      width: parent.width
      height: item ? item.implicitHeight : 0
      onLoaded: {
        if (item.inZone !== undefined) item.inZone = true
        if (item.shown !== undefined) item.shown = Qt.binding(function() { return card.shown })
      }
    }
  }

  // Counted once while shown, whatever the number of screens showing it: an
  // addon that only works while its content is on screen (a sampler) reads
  // zoneViews > 0. `countedOwner` is the root it was counted on, as the
  // addon can be made again (see Addons.qml) while the zone is on screen.
  property var countedOwner: null
  onShownChanged: count()
  onOwnerChanged: count()
  // The Loader this is made in can hand over the addon after making it, and
  // an addon made again hands over a new root (and new properties) to a zone
  // that is already up.
  onMountedPageChanged: mountPage()
  Component.onCompleted: { mountPage(); count() }
  Component.onDestruction: if (countedOwner) countedOwner.zoneViews -= 1

  // What the page was made with, to make it again only when that differs: a
  // page keeps the objects it was given (the addon's root, as `stats`), and
  // once that root is gone it reads null and never recovers. Comparing the
  // values, not the pages' objects, as the addon's `settingsPages` may be
  // rebuilt with the same contents.
  property var madeWith: null
  function mountPage() {
    var next = mountedPage ? Object.assign({ source: String(mountedPage.source) }, mountedPage.properties || {}) : null
    var same = !!next && !!madeWith && Object.keys(next).length === Object.keys(madeWith).length
      && Object.keys(next).every(function(key) { return next[key] === madeWith[key] })
    if (same && page.item) return
    madeWith = next
    if (!next) page.source = ""
    else page.setSource(mountedPage.source, Object.assign({ view: center.zoneLook }, mountedPage.properties || {}))
  }
  function count() {
    var next = shown ? owner : null
    if (next === countedOwner) return
    if (countedOwner) countedOwner.zoneViews -= 1
    countedOwner = next
    if (next) next.zoneViews += 1
  }
}
