import QtQuick
import "../components"

// The enabled addons' pills, inside the island on each screen (see Addon.qml),
// standing in for whichever addon's is on the island.
IslandPill {
  id: pills
  readonly property var current: host.addonPill
  shown: !!current
  pillWidth: current ? current.pillWidth : 0
  pillHeight: current ? current.pillHeight : 0
  pillRadius: current ? current.pillRadius : 0
  // An ongoing pill keeps the clock in its middle; a momentary or asking one
  // fills the island.
  keepsClock: !!current && host.view !== "feedback" && !current.pillAsks
  function clicked(mouse) { current.pillClicked() }
  // Each addon's pill fades itself.
  opacity: 1

  Repeater {
    model: pills.host.addons.loaded.filter(function(root) { return !!root.pill })
    delegate: Loader {
      required property var modelData
      anchors.fill: parent
      sourceComponent: modelData.pill
    }
  }
}
