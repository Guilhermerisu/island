import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"

// Plugins added with `omarchy plugin add` (every third-party plugin but the
// bar in use, and the island's own notifications companion, which setup
// manages: switching it off here would quietly bring back Omarchy's
// notifications and send the island back to "Click to Setup"). Enter opens
// an enabled panel, overlay, or menu plugin through the shell; on any other
// plugin it flips enabled. Shift+Enter always flips enabled, the same as
// `omarchy plugin enable|disable`.
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

  readonly property var openKinds: ["panel", "overlay", "menu"]
  property var all: []
  property bool loading: false

  Process {
    id: listProc
    command: ["omarchy-plugin-list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        plugins.loading = false
        try {
          plugins.all = JSON.parse(text).filter(function(p) {
            return !p.firstParty && (p.kinds || []).indexOf("bar") === -1 && p.id !== "guilhermerisu.notifications"
          }).map(function(p) {
            var kinds = p.kinds || []
            return {
              key: p.id, id: String(p.id), name: String(p.name || p.id), kinds: kinds,
              enabled: !!p.enabled, canDisable: p.canDisable !== false,
              openable: kinds.some(function(k) { return plugins.openKinds.indexOf(k) !== -1 })
            }
          })
        } catch (e) {}
      }
    }
  }
  function refresh() {
    if (listProc.running) return
    loading = true
    listProc.running = true
  }

  Process {
    id: toggleProc
    onExited: plugins.refresh()
  }
  function setEnabled(entry, enabled) {
    if (!entry || toggleProc.running || (!enabled && !entry.canDisable)) return
    toggleProc.command = [enabled ? "omarchy-plugin-enable" : "omarchy-plugin-disable", entry.id]
    toggleProc.running = true
  }

  // Close first so the plugin's window, not the island, gets the keyboard.
  Process { id: runner }
  function open(entry) {
    host.view = "rest"
    runner.command = ["bash", "-c", 'sleep 0.15; exec omarchy-shell shell toggle "$1" "{}"', "--", entry.id]
    runner.startDetached()
  }

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
        font.pixelSize: 17
      }
      Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: stateLabel.left
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
          font.pixelSize: 14
          font.weight: Font.Medium
        }
        Text {
          width: parent.width
          text: String(pluginRow.entry.id || "") + " · " + (pluginRow.entry.kinds || []).join(", ")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: plugins.host.theme.muted
          font.family: plugins.host.theme.textFontFamily
          font.pixelSize: 11
        }
      }
      Text {
        id: stateLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: pluginRow.entry.enabled ? (pluginRow.entry.openable ? "Open" : "On") : "Off"
        color: pluginRow.entry.enabled ? plugins.host.theme.text : plugins.host.theme.muted
        font.family: plugins.host.theme.textFontFamily
        font.pixelSize: 12
      }
    }
  }
}
