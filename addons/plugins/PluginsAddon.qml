import QtQuick
import ".."

// Plugins added with `omarchy plugin add`, as an island view (see PluginList).
Addon {
  id: pluginsAddon
  views: [{ name: "plugins", width: 520, component: pluginList }]
  Component {
    id: pluginList
    PluginList { host: pluginsAddon.host; active: pluginsAddon.host.view === "plugins" }
  }
}
