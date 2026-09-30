import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
// Omarchy's own menu model: parsing, merging your overrides, conditions,
// labels, and search ranking all behave exactly like its menu.
import "file:///usr/share/omarchy/shell/plugins/menu/MenuModel.js" as MenuModel

// The Omarchy menu in the island: Omarchy's default menu merged with your
// ~/.config/omarchy/extensions/omarchy-menu.jsonc. Enter (or →) opens a
// submenu or runs an entry; Esc, ←, or Backspace on an empty search goes
// back (Esc at the top closes). Searching covers the current menu and
// everything under it, showing where each result lives.
ListPicker {
  id: menu
  placeholder: activeMenu === "root" ? "Search" : MenuModel.pathFor(items_, activeMenu)
  emptyText: "Nothing matches"
  rowHeight: 46
  visibleRows: 9
  items: rows
  onChosen: function(entry) { activate(entry) }
  onKeyFilter: function(event) {
    var empty = query === ""
    if (event.key === Qt.Key_Escape && activeMenu !== "root") { goBack(); event.accepted = true }
    else if (empty && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) && activeMenu !== "root") { goBack(); event.accepted = true }
    else if (empty && event.key === Qt.Key_Right && selected && (selected.kind === "menu" || selected.kind === "link")) { activate(selected); event.accepted = true }
  }
  onActiveChanged: {
    if (!active) return
    var route = MenuModel.resolveRoute(items_, itemOrder, host.menuRoute || "root")
    activeMenu = MenuModel.item(items_, route) ? route : "root"
    navStack = []
    evaluateGuards()
  }

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  // ---------- Menu data ----------

  property var defaultItems: []
  property var userItems: []
  property var items_: ({})
  property var itemOrder: []
  property var whenResults: ({})
  property var checkedResults: ({})

  FileView {
    path: menu.omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
    watchChanges: true
    printErrors: false
    onLoaded: { menu.defaultItems = MenuModel.parseMenuJsonc(text()); menu.rebuild() }
    onFileChanged: reload()
  }
  FileView {
    path: menu.host.home + "/.config/omarchy/extensions/omarchy-menu.jsonc"
    watchChanges: true
    printErrors: false
    onLoaded: { menu.userItems = MenuModel.parseMenuJsonc(text()); menu.rebuild() }
    onLoadFailed: { menu.userItems = []; menu.rebuild() }
    onFileChanged: reload()
  }

  function rebuild() {
    var merged = MenuModel.mergeMenuSources(defaultItems, userItems)
    items_ = merged.items
    itemOrder = merged.itemOrder
    evaluateGuards()
  }

  // `when` (show/hide) and `checked` (✓) conditions, run as one batch the
  // way Omarchy's menu does. A row only hides on an explicit false.
  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser { onRead: function(data) { guardProc.collected += data + "\n" } }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0) return
      var nextWhen = ({}), nextChecked = ({})
      guardProc.collected.split("\n").forEach(function(line) {
        line = line.trim()
        var colon = line.lastIndexOf(":")
        if (colon < 0) return
        var value = line.substring(colon + 1) === "1"
        var rest = line.substring(0, colon)
        var tagAt = rest.lastIndexOf(":")
        if (tagAt < 0) return
        var id = rest.substring(0, tagAt), tag = rest.substring(tagAt + 1)
        if (tag === "w") nextWhen[id] = value
        else if (tag === "c") nextChecked[id] = value
      })
      menu.whenResults = nextWhen
      menu.checkedResults = nextChecked
    }
  }
  function evaluateGuards() {
    if (guardProc.running) return
    var script = MenuModel.guardScript(items_)
    if (!script) return
    guardProc.collected = ""
    guardProc.command = ["bash", "-lc", script]
    guardProc.running = true
  }

  // ---------- Providers (submenus filled at runtime) ----------

  function shellQuote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }
  readonly property var providers: ({
    "fonts": {
      script: "current=$(omarchy-font-current 2>/dev/null); omarchy-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
      icon: "",
      actionFor: function(value) { return "omarchy-font-set " + menu.shellQuote(value) }
    },
    "power-profiles": {
      script: "current=$(powerprofilesctl get 2>/dev/null); omarchy-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
      icon: "󰐋",
      actionFor: function(value) { return "omarchy-powerprofiles-set autodetect " + menu.shellQuote(value) }
    }
  })
  Process {
    id: providerProc
    property string menuId: ""
    property string providerKey: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: menu.mergeProviderRows(text, providerProc.menuId, providerProc.providerKey)
    }
  }
  function loadProvider(id) {
    var entry = MenuModel.item(items_, id)
    var spec = entry && entry.provider ? providers[entry.provider] : null
    if (!spec || providerProc.running) return
    providerProc.menuId = id
    providerProc.providerKey = entry.provider
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }
  function mergeProviderRows(raw, menuId, providerKey) {
    var spec = providers[providerKey]
    if (!spec) return
    var rows = [], taken = ({})
    String(raw || "").split("\n").forEach(function(line) {
      line = line.trim()
      if (!line) return
      var parts = line.split("\t")
      var label = parts[0] || "", value = parts[1] || parts[0] || "", current = parts[2] || ""
      if (!label) return
      var rowId = menuId + "." + MenuModel.slugify(value)
      while (taken[rowId]) rowId += "-"
      taken[rowId] = true
      rows.push({ id: rowId, parent: menuId, kind: "action", icon: value === current ? "✓" : spec.icon,
        label: label, title: "", target: "", description: "", action: spec.actionFor(value),
        provider: "", aliases: [], when: "", checked: "", order: 0 })
    })
    var merged = MenuModel.swapProviderRows(items_, itemOrder, menuId, rows)
    items_ = merged.items
    itemOrder = merged.itemOrder
  }

  // ---------- Navigation ----------

  property string activeMenu: "root"
  property var navStack: []
  function isVisible(entry) { return MenuModel.isVisible(items_, itemOrder, whenResults, entry, 0) }

  readonly property var rows: {
    var q = query.trim()
    var active = MenuModel.item(items_, activeMenu) ? activeMenu : "root"
    var list = []
    for (var i = 0; i < itemOrder.length; i++) {
      var entry = MenuModel.item(items_, itemOrder[i])
      if (!entry || entry.id === "root") continue
      if (q) {
        if (!MenuModel.isDescendantOf(items_, entry.id, active)) continue
        if (!MenuModel.matchesQuery(entry, q, isVisible(entry))) continue
        var row = MenuModel.displayRow(items_, itemOrder, checkedResults, entry,
          MenuModel.parentPathFor(items_, entry.id), MenuModel.searchScore(items_, entry, q))
        list.push(row)
      } else {
        if (entry.parent !== active || !isVisible(entry)) continue
        list.push(MenuModel.displayRow(items_, itemOrder, checkedResults, entry, "", entry.order))
      }
    }
    if (q) list.sort(function(a, b) { return a.score !== b.score ? a.score - b.score : a.path.localeCompare(b.path) })
    return list.map(function(r) { r.key = r.itemId; return r })
  }

  function openMenu(id, push) {
    if (push && id !== activeMenu) navStack = navStack.concat([activeMenu])
    activeMenu = id
    clearSearch()
    var entry = MenuModel.item(items_, id)
    if (entry && entry.provider) loadProvider(id)
  }
  function goBack() {
    if (navStack.length) {
      var previous = navStack[navStack.length - 1]
      navStack = navStack.slice(0, -1)
      openMenu(previous, false)
    } else {
      var entry = MenuModel.item(items_, activeMenu)
      openMenu(entry && entry.parent ? entry.parent : "root", false)
    }
  }

  // Close first so the action lands on your session, not the island.
  Process { id: runner }
  function run(command) {
    host.view = "rest"
    runner.command = ["bash", "-lc", "sleep 0.15; " + command]
    runner.startDetached()
  }
  function activate(row) {
    if (!row) return
    // The Apps submenu is a native list in Omarchy's menu; the island's
    // launcher covers it.
    if (row.provider === "apps") { host.view = "apps"; return }
    if (row.kind === "menu" || row.kind === "link") openMenu(row.target || row.itemId, true)
    else if (row.action) run(row.action)
  }

  row: Component {
    Item {
      id: menuRow
      property var entry: ({})
      property bool selected: false
      readonly property bool isMenu: entry.kind === "menu" || entry.kind === "link"

      Text {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        horizontalAlignment: Text.AlignHCenter
        text: String(menuRow.entry.icon || "")
        color: menu.host.theme.muted
        font.family: menuRow.entry.iconFont || menu.host.theme.fontFamily
        font.pixelSize: 17
      }
      Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: chevron.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          width: parent.width
          text: String(menuRow.entry.label || "")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: menu.host.theme.text
          font.family: "Adwaita Sans"
          font.pixelSize: 14
          font.weight: Font.Medium
        }
        Text {
          width: parent.width
          visible: text !== ""
          text: String(menuRow.entry.detail || "")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: menu.host.theme.muted
          font.family: "Adwaita Sans"
          font.pixelSize: 11
        }
      }
      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: menuRow.isMenu
        text: "󰅂"
        color: menu.host.theme.muted
        font.family: menu.host.theme.fontFamily
        font.pixelSize: 16
      }
    }
  }
}
