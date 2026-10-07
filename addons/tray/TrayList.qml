import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../components"

// The system tray as a list. Enter (or a click) on an app with a menu opens
// that menu here, led by an "Open" row; an app without one is activated.
// Menus render in the island rather than as platform menus, which Omarchy's
// shell can't show (it isn't a QApplication). Esc, ←, or Backspace on an
// empty search goes back up.
ListPicker {
  id: tray
  placeholder: menuItem ? stack.map(function(s) { return s.title }).join(" › ") : "Search tray"
  emptyText: menuItem ? "Empty menu" : SystemTray.items.values.length ? "Nothing matches" : "Nothing in the tray"
  rowHeight: 44
  visibleRows: 9
  items: menuItem ? menuRows : appRows
  onChosen: function(entry) { choose(entry) }
  onKeyFilter: function(event) {
    var empty = query === ""
    if (!menuItem) return
    if (event.key === Qt.Key_Escape || (empty && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Left))) {
      goBack(); event.accepted = true
    }
  }
  onActiveChanged: if (!active) closeMenu()

  function matches(text) {
    var q = query.trim().toLowerCase()
    return !q || String(text).toLowerCase().indexOf(q) !== -1
  }
  function appTitle(item) {
    return String(item.tooltipTitle || item.title || item.id || "").trim()
  }

  readonly property var appRows: SystemTray.items.values.filter(function(item) {
    return item.status !== Status.Passive && tray.matches(tray.appTitle(item))
  }).map(function(item) {
    return { key: item.id, kind: "app", item: item, label: tray.appTitle(item), icon: String(item.icon || ""), children: item.hasMenu && !!item.menu }
  })

  // ---------- Menus ----------

  // Each level keeps its own opener: a child entry is owned by its parent
  // opener's model, so the parents must outlive it (same as Omarchy's tray).
  property var menuItem: null
  property var stack: []
  Component { id: openerComponent; QsMenuOpener {} }

  readonly property var menuRows: {
    if (!stack.length) return []
    var rows = []
    if (stack.length === 1 && matches("Open " + stack[0].title))
      rows.push({ key: "open", kind: "open", label: "Open " + stack[0].title, icon: "", children: false })
    var values = stack[stack.length - 1].opener.children.values
    for (var i = 0; i < values.length; i++) {
      var e = values[i]
      if (e.isSeparator || !e.enabled || !matches(e.text)) continue
      rows.push({ key: "entry" + i, kind: "entry", entry: e, label: String(e.text || "").replace(/_(?=\S)/g, "").replace(/&&/g, "&"),
        icon: String(e.icon || ""), children: e.hasChildren, checked: e.checkState === Qt.Checked })
    }
    return rows
  }

  function push(menu, title) {
    var opener = openerComponent.createObject(tray, { menu: menu })
    if (opener) stack = stack.concat([{ opener: opener, title: title }])
    clearSearch()
  }
  function goBack() {
    var top = stack[stack.length - 1]
    stack = stack.slice(0, -1)
    top.opener.destroy()
    if (!stack.length) menuItem = null
    clearSearch()
  }
  // Deepest first: an inner opener's entry lives in its parent's model.
  function closeMenu() {
    var openers = stack
    stack = []
    menuItem = null
    for (var i = openers.length - 1; i >= 0; i--) openers[i].opener.destroy()
  }

  // Close first so the app's window, not the island, gets the keyboard.
  function closeThen(action) {
    host.view = "rest"
    Qt.callLater(action)
  }
  function choose(row) {
    if (!row) return
    if (row.kind === "app" && row.children) {
      menuItem = row.item
      push(row.item.menu, row.label)
    } else if (row.kind === "app") {
      closeThen(function() { row.item.activate() })
    } else if (row.kind === "open") {
      var item = menuItem
      closeThen(function() { item.activate() })
    } else if (row.children) {
      push(row.entry, row.label)
    } else {
      var entry = row.entry
      entry.triggered()
      host.view = "rest"
    }
  }

  row: Component {
    Item {
      id: trayRow
      property var entry: ({})
      property bool selected: false

      IconImage {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 20
        visible: String(trayRow.entry.icon || "") !== ""
        source: String(trayRow.entry.icon || "")
      }
      Text {
        anchors.centerIn: icon
        visible: !icon.visible
        text: trayRow.entry.checked ? "󰄬" : trayRow.entry.kind === "open" ? "󰏌" : ""
        color: tray.host.theme.muted
        font.family: tray.host.theme.fontFamily
        font.pixelSize: tray.host.theme.px(16)
      }
      Text {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: chevron.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: String(trayRow.entry.label || "")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: tray.host.theme.text
        font.family: tray.host.theme.textFontFamily
        font.pixelSize: tray.host.theme.px(14)
        font.weight: Font.Medium
      }
      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !!trayRow.entry.children
        text: "󰅂"
        color: tray.host.theme.muted
        font.family: tray.host.theme.fontFamily
        font.pixelSize: tray.host.theme.px(16)
      }
    }
  }
}
