import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
import "../../components/KeyNames.js" as KeyNames

// Keybindings: the shared list view over Omarchy's keybinding list (what the
// binding does, with its keys as keycaps). Type to search by description or
// keys ("super t"), Enter or a click to run the binding, like Omarchy's own
// list does.
ListPicker {
  id: keybinds
  placeholder: "Search keybindings"
  emptyText: "No keybindings match"
  rowHeight: 40
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

  // "SUPER SHIFT + RETURN   → Browser\texec\tomarchy-launch-browser". A
  // binding with two combos lists them as "SUPER + W / SUPER + Q"; each
  // becomes its own group of keycaps.
  function parse(raw) {
    var list = []
    String(raw || "").split("\n").forEach(function(line) {
      var cols = line.split("\t")
      var label = cols[0] || ""
      var arrow = label.indexOf("→")
      if (arrow === -1) return
      var keys = label.slice(0, arrow).trim()
      var description = label.slice(arrow + 1).trim()
      var combos = keys.split(" / ").map(function(combo) {
        var parts = combo.split("+")
        var mods = parts.length > 1 ? parts[0].trim().split(/\s+/).filter(function(m) { return m }) : []
        var key = parts.length > 1 ? parts.slice(1).join("+").trim() : combo.trim()
        return mods.concat([key]).map(KeyNames.key)
      })
      list.push({
        key: keys + " " + description,
        name: description,
        combos: combos,
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
        font.letterSpacing: keybinds.host.theme.tracking(keybinds.host.theme.textFontFamily, keybinds.host.theme.px(14))
        font.pixelSize: keybinds.host.theme.px(14)
      }
      // Each combo as keycaps; alternatives joined by "or".
      Row {
        id: caps
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: bindRow.entry.combos || []
          delegate: Row {
            id: combo
            required property var modelData
            required property int index
            Text {
              visible: combo.index > 0
              anchors.verticalCenter: parent.verticalCenter
              leftPadding: 4
              rightPadding: 4
              text: "or"
              color: keybinds.host.theme.secondary
              font.family: keybinds.host.theme.textFontFamily
              font.letterSpacing: keybinds.host.theme.tracking(keybinds.host.theme.textFontFamily, keybinds.host.theme.px(12))
              font.pixelSize: keybinds.host.theme.px(12)
            }
            Row {
              spacing: 4
              Repeater {
                model: combo.modelData
                delegate: Rectangle {
                  id: cap
                  required property var modelData
                  width: Math.max(22, capLabel.implicitWidth + 14)
                  height: 22
                  radius: 6
                  color: keybinds.host.theme.tile
                  // The key's lower edge, a shade lighter, as a keycap's.
                  Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: parent.radius / 2
                    anchors.rightMargin: parent.radius / 2
                    height: 1
                    color: keybinds.host.theme.wellHover
                  }
                  Text {
                    id: capLabel
                    anchors.centerIn: parent
                    text: String(cap.modelData)
                    textFormat: Text.PlainText
                    color: keybinds.host.theme.text
                    font.family: keybinds.host.theme.textFontFamily
                    font.letterSpacing: keybinds.host.theme.tracking(keybinds.host.theme.textFontFamily, keybinds.host.theme.px(12))
                    font.pixelSize: keybinds.host.theme.px(12)
                    font.weight: Font.Medium
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
