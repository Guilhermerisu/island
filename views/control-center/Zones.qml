import QtQuick
import "zones.js" as ZoneModel

// The control center's zones: what each column holds, saved in the island's
// settings (controlCenterZones, one list of zone ids per column). A zone is
// the control grid ("controls"), the notifications ("notifications"), or an
// addon's ("addon:<id>", or "addon:<id>/<key>" for one of several, for the
// entries in addons/Addons.qml that declare a `zone` or `zones`, read whether
// or not the addon is on; what a zone shows comes from the addon, see ZoneCard).
// Nothing here is drawn.
Item {
  id: zones
  required property var host
  readonly property var settings: host.settings

  readonly property int columns: ZoneModel.clampColumns(settings.controlCenterColumns)
  readonly property var definitions: [
    { id: "controls", title: "Controls" },
    { id: "notifications", title: "Notifications" }
  ].concat(host.addons.entries.reduce(function(list, entry) {
    // `zone: true` is a zone named for the addon, sized by what it shows.
    var own = entry.zones || (entry.zone ? [entry.zone === true ? {} : entry.zone] : [])
    return list.concat(own.map(function(zone) {
      return { id: "addon:" + entry.id + (zone.key ? "/" + zone.key : ""), key: zone.key || "",
        title: zone.title || entry.name, name: entry.name, addon: entry.id,
        minWidth: zone.minWidth || 0, editable: !!zone.editable }
    }))
  }, []))
  readonly property var ids: definitions.map(function(zone) { return zone.id })
  // Ids saved before the Plugins addon had two zones: its one was the tiles.
  readonly property var aliases: ({ "addon:plugins": "addon:plugins/pinned" })
  // Shrinking the columns only folds them on screen: the saved lists stay
  // until the next change, so going back to more columns puts them back.
  readonly property var arrangement: ZoneModel.normalize(settings.controlCenterZones, columns, ids, aliases)
  readonly property var absent: ZoneModel.absent(arrangement, ids)
  // How many columns hold something; the island is no wider than that
  // outside edit mode.
  readonly property int occupied: Math.max(1, arrangement.filter(function(column) { return column.length > 0 }).length)
  readonly property bool empty: arrangement.every(function(column) { return column.length === 0 })

  // Each column's share of the width, one per column; written with
  // setShares (null for an even split), per column count so that changing the
  // count and back finds them again.
  readonly property var shares: ZoneModel.shares(settings.controlCenterColumnWidths, columns)

  function definition(id) {
    for (var i = 0; i < definitions.length; i++) if (definitions[i].id === id) return definitions[i]
    return null
  }
  function save(next) {
    var json = JSON.stringify(next)
    if (json !== settings.controlCenterZones) settings.controlCenterZones = json
  }
  function setShares(values) {
    var json = ZoneModel.withShares(settings.controlCenterColumnWidths, columns, values)
    if (json !== settings.controlCenterColumnWidths) settings.controlCenterColumnWidths = json
  }
  function setColumns(count) { settings.controlCenterColumns = ZoneModel.clampColumns(count) }
  function add(id) {
    save(ZoneModel.add(arrangement, id))
    // An addon's zone needs the addon; removing the zone leaves it on.
    var zone = definition(id)
    if (zone && zone.addon) host.addons.setEnabled(zone.addon, true)
  }
  // Put it in a column only if it isn't in one already.
  function ensure(id) { if (absent.indexOf(id) !== -1) add(id) }
  function remove(id) { save(ZoneModel.remove(arrangement, id)) }
  function move(id, column, index) { save(ZoneModel.move(arrangement, id, column, index)) }
}
