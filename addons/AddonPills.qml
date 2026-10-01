import QtQuick

// The enabled addons' pills, inside the island on each screen (see Addon.qml).
Item {
  id: pills
  required property var host

  Repeater {
    model: pills.host.addons.loaded.filter(function(root) { return !!root.pill })
    delegate: Loader {
      required property var modelData
      anchors.fill: parent
      sourceComponent: modelData.pill
    }
  }
}
