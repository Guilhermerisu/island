import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"

// Keybindings: the shared list view over Omarchy's keybinding list (what the
// binding does, with its keys as keycaps). Type to search by description or
// keys ("super t"), Enter or a click to run the binding, like Omarchy's own
// list does.
ListPicker {
  id: keybinds
  placeholder: "Search keybindings"
  emptyText: "No keybindings match"
  rowHeight: 44
  visibleRows: 9
  items: {
    var q = query.trim().toLowerCase()
    if (!q) return all
    var terms = q.split(/\s+/)
    return all.filter(function(b) {
      return terms.every(function(t) { return b.search.indexOf(t) !== -1 })
    })
  }
  onChosen: function(entry) { run(entry) }
  onActiveChanged: if (active && !loader.running) loader.running = true

  // Omarchy's keybindings script, loaded for its functions: its records give
  // each binding's label plus the dispatcher and argument to run it, and
  // dispatch_binding runs one exactly the way its own list does.
  readonly property string script: 'set -- --print; source "$(command -v omarchy-menu-keybindings)" >/dev/null; '

  property var all: []
  Process {
    id: loader
    command: ["bash", "-c", keybinds.script + "output_binding_records"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: keybinds.all = keybinds.parse(text)
    }
  }

  // "SUPER SHIFT + RETURN   → Browser\texec\tomarchy-launch-browser"
  function parse(raw) {
    var list = []
    String(raw || "").split("\n").forEach(function(line) {
      var cols = line.split("\t")
      var label = cols[0] || ""
      var arrow = label.indexOf("→")
      if (arrow === -1) return
      var keys = label.slice(0, arrow).trim()
      var description = label.slice(arrow + 1).trim()
      var parts = keys.split("+")
      var mods = parts.length > 1 ? parts[0].trim().split(/\s+/).filter(function(m) { return m }) : []
      var key = parts.length > 1 ? parts.slice(1).join("+").trim() : keys
      list.push({
        key: keys + " " + description,
        name: description,
        caps: mods.concat([key]),
        dispatcher: cols[1] || "",
        arg: cols.slice(2).join("\t"),
        search: (description + " " + keys).toLowerCase()
      })
    })
    return list
  }

  // Close first so the binding acts on your window, not the island.
  Process { id: runner }
  function run(entry) {
    if (!entry || !entry.dispatcher) return
    host.view = "rest"
    runner.command = ["bash", "-c",
      'd="$1"; a="$2"; sleep 0.15; ' + keybinds.script + 'dispatch_binding "$d" "$a"',
      "--", entry.dispatcher, entry.arg]
    runner.startDetached()
  }

  row: Component {
    Item {
      id: bindRow
      property var entry: ({})
      property bool selected: false

      Text {
        anchors.left: parent.left
        anchors.right: caps.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: String(bindRow.entry.name || "")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: keybinds.host.theme.text
        font.family: keybinds.host.theme.textFontFamily
        font.pixelSize: keybinds.host.theme.px(16)
        font.weight: Font.Medium
      }
      // Keys as keycaps.
      Row {
        id: caps
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
          model: bindRow.entry.caps || []
          delegate: Rectangle {
            id: cap
            required property var modelData
            width: Math.max(26, capLabel.implicitWidth + 14)
            height: 24
            radius: 6
            color: keybinds.host.theme.withAlpha(keybinds.host.theme.text, 0.08)
            border.width: 1
            border.color: keybinds.host.theme.withAlpha(keybinds.host.theme.text, 0.1)
            Text {
              id: capLabel
              anchors.centerIn: parent
              text: String(cap.modelData)
              textFormat: Text.PlainText
              color: keybinds.host.theme.muted
              font.family: keybinds.host.theme.textFontFamily
              font.pixelSize: keybinds.host.theme.px(11)
              font.weight: Font.DemiBold
            }
          }
        }
      }
    }
  }
}
