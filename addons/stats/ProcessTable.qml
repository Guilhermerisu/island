pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../components"

// Activity Monitor's process list: a header to sort by (click again to
// flip), then the rows, scrolled inside a fixed height. An app's processes
// fold under its window's process, its row adding them up.
Item {
  id: table
  required property var view
  required property var stats
  required property var format
  property string query: ""
  property string sortKey: "mem"
  property bool ascending: false
  property int selectedPid: -1
  property var expanded: ({})
  // A row's ⓧ was clicked: Quit or Force Quit it (see QuitSheet).
  signal quitRequested(var row)
  readonly property int rowHeight: 24
  readonly property int limit: 50
  implicitHeight: 30 + rowHeight * 12

  readonly property var columns: [
    { key: "name", title: "Process Name", width: 0 },
    { key: "cpu", title: "% CPU", width: 54 },
    { key: "mem", title: "Memory", width: 84 }
  ]
  readonly property int fixedWidth: columns.reduce(function(sum, c) { return sum + c.width }, 0)
  readonly property int myUid: stats.latest ? stats.latest.uid : -1

  // The program icon processes without an app of their own show.
  readonly property string defaultIcon: Quickshell.iconPath("application-x-executable", true)
  function appEntry(appClass) {
    return appClass ? DesktopEntries.heuristicLookup(appClass) : null
  }
  function iconFor(entry) {
    var icon = entry ? String(entry.icon || "") : ""
    if (!icon) return ""
    return icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true)
  }

  function sortValue(row) {
    if (sortKey === "name") return row.name.toLowerCase()
    var v = row[sortKey]
    return v === null || v === undefined ? -1 : v
  }
  function compare(a, b) {
    var x = sortValue(a), y = sortValue(b)
    var order = x < y ? -1 : x > y ? 1 : a.pid - b.pid
    return ascending ? order : -order
  }
  function matches(row) {
    var q = query.trim().toLowerCase()
    return q === "" || row.name.toLowerCase().indexOf(q) !== -1 || String(row.pid).indexOf(q) === 0
  }

  // The rows as drawn: [{ pid, name, cpu, mem, uid, depth, icon, children
  // (count), open }].
  readonly property var rows: {
    var latest = stats.latest
    if (!latest) return []
    var procs = latest.processes
    var result = []
    // Grouped: each app's processes under its window's.
    var groups = {}, singles = []
    for (var k = 0; k < procs.length; k++) {
      var proc = procs[k]
      if (proc.app === null || proc.app === undefined) { singles.push(proc); continue }
      if (!groups[proc.app]) groups[proc.app] = { members: [], lead: null }
      groups[proc.app].members.push(proc)
      if (proc.pid === proc.app) groups[proc.app].lead = proc
    }
    var top = singles.filter(matches).map(function(p) { return Object.assign({}, p, { depth: 0, children: 0 }) })
    var childRows = {}
    for (var app in groups) {
      var group = groups[app]
      var lead = group.lead || group.members[0]
      var entry = appEntry(lead.appClass)
      var row = {
        pid: lead.pid, uid: lead.uid, start: lead.start, app: lead.app, depth: 0, children: group.members.length - 1,
        pids: group.members.map(function(p) { return p.pid }),
        name: entry && entry.name ? entry.name : lead.appClass || lead.name,
        icon: iconFor(entry), cpu: 0, mem: 0, threads: 0
      }
      for (var m = 0; m < group.members.length; m++) {
        var member = group.members[m]
        row.cpu += member.cpu
        row.mem += member.mem
        row.threads += member.threads
      }
      row.cpu = Math.round(row.cpu * 10) / 10
      var memberMatch = group.members.some(matches)
      if (!matches(row) && !memberMatch) continue
      top.push(row)
      childRows[row.pid] = group.members.filter(function(p) { return p.pid !== lead.pid })
    }
    top.sort(compare)
    top = top.slice(0, limit)
    for (var t = 0; t < top.length; t++) {
      var r = top[t]
      result.push(r)
      r.open = !!expanded[r.pid]
      if (r.open && childRows[r.pid]) {
        var members = childRows[r.pid].slice().sort(compare)
        for (var c = 0; c < members.length; c++) result.push(Object.assign({}, members[c], { depth: 1, children: 0 }))
      }
    }
    return result
  }
  // One slot per row drawn, grown or cut at the end as the rows change, so
  // the rows on screen stay put and only their contents update; a new array
  // as the model would rebuild them all each reading.
  ListModel { id: slots }
  onRowsChanged: {
    while (slots.count < rows.length) slots.append({})
    if (slots.count > rows.length) slots.remove(rows.length, slots.count - rows.length)
  }

  function toggle(pid) {
    var next = Object.assign({}, expanded)
    if (next[pid]) delete next[pid]; else next[pid] = true
    expanded = next
  }
  function sortBy(key) {
    if (sortKey === key) ascending = !ascending
    else { sortKey = key; ascending = key === "name" }
  }
  function cell(row, key) {
    if (key === "cpu") return (row.cpu || 0).toFixed(1)
    if (key === "mem") return format.bytes(row.mem)
    return String(row[key])
  }

  // Header: small titles, the sorted one darker with its chevron after it,
  // hairlines between columns and under the header, as in Activity Monitor.
  Item {
    id: header
    width: parent.width
    height: 26
    Row {
      x: 8
      width: parent.width - 16
      height: parent.height
      Repeater {
        model: table.columns
        delegate: Item {
          id: head
          required property var modelData
          required property int index
          readonly property bool sorted: table.sortKey === modelData.key
          readonly property bool isName: modelData.key === "name"
          width: modelData.width || (header.width - 16 - table.fixedWidth)
          height: header.height
          Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: head.isName ? parent.left : undefined
            anchors.leftMargin: head.isName ? 26 : 0
            anchors.right: head.isName ? undefined : parent.right
            anchors.rightMargin: 6
            spacing: 3
            Text {
              text: head.modelData.title
              color: head.sorted ? table.view.text : table.view.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: table.view.host.theme.px(12)
              font.weight: Font.DemiBold
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: head.sorted
              text: table.ascending ? "󰅃" : "󰅀"
              color: table.view.textMuted
              font.family: table.view.host.theme.fontFamily
              font.pixelSize: table.view.host.theme.px(9)
            }
          }
          Rectangle {
            visible: head.index > 0
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 12
            color: table.view.divider
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: table.sortBy(head.modelData.key)
          }
        }
      }
    }
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width
      height: 1
      color: table.view.divider
    }
  }

  // Rows: faint stripes and an inset, rounded selection in the accent,
  // every name behind the same icon slot so they line up.
  ListView {
    id: list
    anchors.top: header.bottom
    anchors.topMargin: 4
    anchors.bottom: parent.bottom
    width: parent.width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: slots
    delegate: Item {
      id: row
      required property int index
      readonly property var modelData: table.rows[index] || ({ pid: -1, name: "", depth: 0, children: 0 })
      readonly property bool selected: modelData.pid === table.selectedPid
      readonly property color ink: selected ? table.view.accentInk : table.view.text
      readonly property color inkMuted: selected ? table.view.accentInk : table.view.textMuted
      // Only your own processes can be quit; their ⓧ shows on hover or
      // while selected.
      readonly property bool quittable: modelData.pid > 0 && modelData.uid === table.myUid
      readonly property bool showQuit: quittable && (rowHover.hovered || selected)
      width: list.width
      height: table.rowHeight
      HoverHandler { id: rowHover }

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: row.selected ? table.view.accent
          : row.index % 2 === 1 ? table.view.host.theme.withAlpha(table.view.text, 0.04) : "transparent"
      }
      MouseArea {
        anchors.fill: parent
        onClicked: table.selectedPid = row.modelData.pid
        onDoubleClicked: if (row.modelData.children > 0) table.toggle(row.modelData.pid)
      }
      Row {
        x: 8
        width: parent.width - 16
        height: parent.height
        Repeater {
          model: table.columns
          delegate: Item {
            id: cellItem
            required property var modelData
            readonly property bool isName: modelData.key === "name"
            width: modelData.width || (list.width - 16 - table.fixedWidth)
            height: row.height
            // Disclosure triangle, icon slot, name.
            Row {
              visible: cellItem.isName
              x: row.modelData.depth * 16
              width: parent.width - x
              height: parent.height
              spacing: 5
              Item {
                width: 10
                height: parent.height
                Text {
                  anchors.centerIn: parent
                  visible: row.modelData.children > 0
                  text: row.modelData.open ? "▾" : "▸"
                  color: row.inkMuted
                  font.family: "Adwaita Sans"
                  font.pixelSize: table.view.host.theme.px(11)
                }
                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -3
                  enabled: row.modelData.children > 0
                  cursorShape: Qt.PointingHandCursor
                  onClicked: table.toggle(row.modelData.pid)
                }
              }
              Item {
                width: 16
                height: parent.height
                // Its app's icon, or the generic program icon when it has
                // none (or the app's fails to load).
                Image {
                  id: appIcon
                  anchors.centerIn: parent
                  visible: status === Image.Ready
                  width: 16
                  height: 16
                  sourceSize.width: 32
                  sourceSize.height: 32
                  readonly property string wanted: row.modelData.icon || ""
                  property bool failed: false
                  onWantedChanged: failed = false
                  source: wanted !== "" && !failed ? wanted : table.defaultIcon
                  asynchronous: true
                  onStatusChanged: if (status === Image.Error && wanted !== "") failed = true
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - (row.showQuit ? 24 : 0)
                text: row.modelData.name
                elide: Text.ElideRight
                color: row.ink
                font.family: "Adwaita Sans"
                font.pixelSize: table.view.host.theme.px(13)
              }
            }
            // Quit Process, at the end of the name.
            Rectangle {
              visible: cellItem.isName && row.showQuit
              anchors.right: parent.right
              anchors.rightMargin: 4
              anchors.verticalCenter: parent.verticalCenter
              width: 20
              height: 20
              radius: 10
              color: quitMouse.containsMouse
                ? table.view.host.theme.withAlpha(row.selected ? table.view.accentInk : table.view.text, 0.16) : "transparent"
              Text {
                anchors.centerIn: parent
                text: "󰅙"
                color: quitMouse.containsMouse ? row.ink : row.inkMuted
                font.family: table.view.host.theme.fontFamily
                font.pixelSize: table.view.host.theme.px(15)
              }
              MouseArea {
                id: quitMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  table.selectedPid = row.modelData.pid
                  table.quitRequested(row.modelData)
                }
              }
              Tooltip { theme: table.view.host.theme; text: "Quit Process" }
            }
            Text {
              visible: !cellItem.isName
              anchors.right: parent.right
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              text: cellItem.isName ? "" : table.cell(row.modelData, cellItem.modelData.key)
              color: row.ink
              font.family: "Adwaita Sans"
              font.pixelSize: table.view.host.theme.px(12)
              font.features: { "tnum": 1 }
            }
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: list
    visible: table.rows.length === 0
    text: table.stats.latest ? "No Processes" : "Loading…"
    color: table.view.textMuted
    font.family: "Adwaita Sans"
    font.pixelSize: table.view.host.theme.px(13)
  }
}
