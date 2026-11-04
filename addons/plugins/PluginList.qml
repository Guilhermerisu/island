import QtQuick
import "../../components"

// Plugins added with `omarchy plugin add` (every third-party plugin but the
// bar in use, and the island's own notifications companion, which setup
// manages: switching it off here would quietly bring back Omarchy's
// notifications and send the island back to "Click to Setup"). Enter opens
// an enabled panel, overlay, or menu plugin through the shell, or a bar
// widget from the bar layout (see services/BarWidgetHost); on any other
// plugin it flips enabled. Shift+Enter always flips enabled, the same as
// `omarchy plugin enable|disable`. An openable plugin shows its shortcut at
// the right; clicking the keys opens Settings → Keybinds, where it is set.
ListPicker {
  id: plugins
  placeholder: "Search plugins"
  emptyText: all.length ? "Nothing matches" : loading ? "Loading…" : "No plugins added"
  rowHeight: 46
  visibleRows: 9
  items: {
    var q = query.trim().toLowerCase()
    return all.filter(function(p) {
      return !q || p.name.toLowerCase().indexOf(q) !== -1 || p.id.toLowerCase().indexOf(q) !== -1
    })
  }
  onChosen: function(entry) {
    if (entry.openable && entry.enabled) open(entry)
    else setEnabled(entry, !entry.enabled)
  }
  onKeyFilter: function(event) {
    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier)) {
      if (selected) setEnabled(selected, !selected.enabled)
      event.accepted = true
    }
  }
  onActiveChanged: if (active) refresh()

  // The list, shortcuts, and actions live in the addon (see PluginsAddon),
  // which the control center's tiles share.
  required property var addon
  readonly property var all: addon.all
  readonly property bool loading: addon.loading
  readonly property var keysById: addon.keysById
  function keyText(keys) { return addon.keyText(keys) }
  function refresh() { addon.refresh() }
  function setEnabled(entry, enabled) { addon.setEnabled(entry, enabled) }
  function open(entry) { addon.open(entry) }

  row: Component {
    Item {
      id: pluginRow
      property var entry: ({})
      property bool selected: false

      Text {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        horizontalAlignment: Text.AlignHCenter
        text: "󰐱"
        color: pluginRow.entry.enabled ? plugins.host.theme.accent : plugins.host.theme.muted
        font.family: plugins.host.theme.fontFamily
        font.pixelSize: plugins.host.theme.px(17)
      }
      Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: keysChip.visible ? keysChip.left : stateLabel.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          width: parent.width
          text: String(pluginRow.entry.name || "")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: plugins.host.theme.text
          font.family: plugins.host.theme.textFontFamily
          font.letterSpacing: plugins.host.theme.tracking(plugins.host.theme.textFontFamily, plugins.host.theme.px(13))
          font.pixelSize: plugins.host.theme.px(13)
          font.weight: Font.Medium
        }
        Text {
          width: parent.width
          text: String(pluginRow.entry.id || "") + " · " + (pluginRow.entry.kinds || []).join(", ")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: plugins.host.theme.muted
          font.family: plugins.host.theme.textFontFamily
          font.letterSpacing: plugins.host.theme.tracking(plugins.host.theme.textFontFamily, plugins.host.theme.px(11))
          font.pixelSize: plugins.host.theme.px(11)
        }
      }
      // Taken by the picker before its own click (see ListPicker's clickAt).
      function clickAt(x, y) {
        var at = mapToItem(keysChip, x, y)
        if (!keysChip.visible || at.x < 0 || at.y < 0 || at.x > keysChip.width || at.y > keysChip.height) return false
        plugins.host.openSettings("Keybinds")
        return true
      }
      Rectangle {
        id: keysChip
        visible: pluginRow.entry.openable === true && pluginRow.entry.enabled === true
        anchors.right: stateLabel.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: keysText.implicitWidth + 14
        height: 22
        radius: plugins.host.theme.radii.small
        color: plugins.host.theme.solid("raised")
        Text {
          id: keysText
          anchors.centerIn: parent
          readonly property string keys: plugins.keysById[pluginRow.entry.id] || ""
          text: plugins.keyText(keys)
          color: keys === "" ? plugins.host.theme.muted : plugins.host.theme.text
          font.family: plugins.host.theme.textFontFamily
          font.letterSpacing: plugins.host.theme.tracking(plugins.host.theme.textFontFamily, plugins.host.theme.px(11))
          font.pixelSize: plugins.host.theme.px(11)
          font.weight: Font.DemiBold
        }
      }
      Text {
        id: stateLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: pluginRow.entry.enabled ? (pluginRow.entry.openable ? "Open" : "On") : "Off"
        color: pluginRow.entry.enabled ? plugins.host.theme.text : plugins.host.theme.muted
        font.family: plugins.host.theme.textFontFamily
        font.letterSpacing: plugins.host.theme.tracking(plugins.host.theme.textFontFamily, plugins.host.theme.px(12))
        font.pixelSize: plugins.host.theme.px(12)
      }
    }
  }
}
