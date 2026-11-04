import QtQuick
import "../../views/control-center"

// A control center tile for a plugin that opens, a CcTile like the others:
// the plugin's name over its shortcut, opening the plugin. `addon` is the
// PluginsAddon, `pluginId` the plugin's.
CcTile {
  required property var addon
  property string pluginId: ""
  readonly property var entry: addon.entryFor(pluginId)

  anchors.fill: parent
  icon: "󰐱"
  title: entry ? entry.name : pluginId
  subtitle: addon.keysById[pluginId] ? addon.keyText(addon.keysById[pluginId]) : "Open"
  available: parent.galleryPreview || (!!entry && entry.enabled)
  onClicked: if (entry) addon.open(entry)
}
