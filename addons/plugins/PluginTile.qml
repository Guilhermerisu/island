import QtQuick
import "../../views/control-center"

// A plugin as a compact tile (a CcTile like the others) in the Plugins zone
// (see PluginsZone): its name over its shortcut. A click does what Enter does
// in the list (see PluginList): opens an enabled plugin that opens, or else
// flips whether it's enabled. `addon` is the PluginsAddon, `entry` the plugin.
CcTile {
  required property var addon
  required property var entry

  icon: addon.iconOf(entry.id).text
  iconFamily: addon.iconOf(entry.id).family
  title: entry.name
  checked: entry.enabled
  subtitle: !entry.enabled ? "Off"
    : !entry.openable ? "On"
    : addon.keysById[entry.id] ? addon.keyText(addon.keysById[entry.id]) : "Open"
  onClicked: entry.openable && entry.enabled ? addon.open(entry) : addon.setEnabled(entry, !entry.enabled)
}
