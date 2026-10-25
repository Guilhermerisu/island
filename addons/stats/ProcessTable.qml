pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../components"
import "../../components/IconSource.js" as IconSource

// Activity Monitor's process list: a header to sort by (click again to
// flip), then the rows, scrolled inside a fixed height. Each row has a
// lettered tile, its name, a small CPU bar with the share (bold once it's
// noticeable, orange when heavy) and its memory. An app's processes fold
// under its window's process, its row adding them up.
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
  readonly property int rowHeight: 29
  readonly property int limit: 50
  implicitHeight: 30 + rowHeight * 12

  readonly property var columns: [
    { key: "name", title: "Process", width: 0 },
    { key: "cpu", title: "% CPU", width: 116 },
    { key: "mem", title: "Memory", width: 84 }
  ]
  // How many processes match, before the list is cut at `limit`.
  readonly property int total: rows.matched || 0
  // The tile of a process without an app icon (or whose icon fails to
  // load): its first letter on a colour picked from its name, so the same
  // program keeps its colour.
  readonly property var tileColors: ["#bf5af2", "#ff9f0a", "#3a82f7", "#30d158", "#5e5ce6", "#8e8e93", "#ff6b5e", "#30b0c7"]
  function tileColor(name) {
    var hash = 0
    for (var i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) % 9973
    return tileColors[hash % tileColors.length]
  }
  // A process's CPU as a share of the whole machine (the sampler counts one
  // core as 100%), so every row stays within 0–100%.
  readonly property int cores: stats.latest && stats.latest.cpu.cores ? stats.latest.cpu.cores : 1
  function share(row) { return (row.cpu || 0) / cores }
  // Past 10% a share is worth reading (bold); past 50% it's heavy (orange).
  function cpuColor(cpu) { return cpu >= 50 ? view.host.theme.system.orange : cpu >= 10 ? view.text : view.textMuted }
  readonly property int fixedWidth: columns.reduce(function(sum, c) { return sum + c.width }, 0)
  readonly property int myUid: stats.latest ? stats.latest.uid : -1

  function appEntry(appClass) {
    return appClass ? DesktopEntries.heuristicLookup(appClass) : null
  }
  function iconFor(entry) {
    return IconSource.source(entry && entry.icon)
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
  // (count), open }], with `matched`, how many matched before the cut.
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
        icon: iconFor(entry), command: lead.command, cpu: 0, mem: 0, threads: 0
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
    result.matched = top.length
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
    if (key === "cpu") return share(row).toFixed(1)
    // One decimal throughout ("7.0 GB" beside "2.9 GB").
    if (key === "mem") return format.bytes(row.mem, true)
    return String(row[key])
  }

  // Header: small quiet titles, the sorted one in the text colour with its
  // chevron after it.
  Item {
    id: header
    width: parent.width
    height: 30
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
            anchors.leftMargin: head.isName ? 18 : 0
            anchors.right: head.isName ? undefined : parent.right
            anchors.rightMargin: 6
            spacing: 3
            Text {
              text: head.modelData.title
              color: head.sorted ? table.view.text : table.view.textMuted
              font.family: table.view.host.theme.textFontFamily
              font.letterSpacing: table.view.host.theme.tracking(table.view.host.theme.textFontFamily, table.view.detailCaptionFontSize)
              font.features: { "tnum": 1 }
              font.pixelSize: table.view.detailCaptionFontSize
              font.weight: head.sorted ? Font.DemiBold : Font.Medium
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: head.sorted
              text: table.ascending ? "󰅃" : "󰅀"
              color: table.view.text
              font.family: table.view.host.theme.fontFamily
              font.pixelSize: table.view.host.theme.px(10)
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: table.sortBy(head.modelData.key)
          }
        }
      }
    }
  }

  // Rows: faint stripes and an inset, rounded selection in the accent,
  // every name behind the same icon slot so they line up.
  ListView {
    id: list
    OverlayScrollbar { flickable: list; parent: list; theme: table.view.host.theme }
    anchors.top: header.bottom
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
          : rowHover.hovered ? table.view.host.theme.fill("subtle")
          : row.index % 2 === 1 ? table.view.host.theme.fill("quiet") : "transparent"
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
            // A disclosure triangle (for an app with more processes), then
            // the tile and name. Every top-level row keeps the triangle's
            // room, so the tiles line up.
            Row {
              visible: cellItem.isName
              x: row.modelData.depth * 16
              width: parent.width - x
              height: parent.height
              spacing: 6
              Item {
                width: 12
                height: parent.height
                Text {
                  anchors.centerIn: parent
                  visible: row.modelData.children > 0
                  text: "󰅂"
                  rotation: row.modelData.open ? 90 : 0
                  Behavior on rotation { MotionAnimation { theme: table.view.host.theme; pace: "standard" } }
                  color: row.inkMuted
                  font.family: table.view.host.theme.fontFamily
                  font.pixelSize: table.view.host.theme.px(12)
                }
                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -4
                  enabled: row.modelData.children > 0
                  cursorShape: Qt.PointingHandCursor
                  onClicked: table.toggle(row.modelData.pid)
                }
              }
              Item {
                width: 18
                height: parent.height
                // Its app's icon when it has one.
                Image {
                  id: appIcon
                  anchors.centerIn: parent
                  visible: status === Image.Ready
                  width: 18
                  height: 18
                  sourceSize.width: 36
                  sourceSize.height: 36
                  source: row.modelData.icon || ""
                  asynchronous: true
                }
                Rectangle {
                  anchors.centerIn: parent
                  visible: !appIcon.visible
                  width: 18
                  height: 18
                  radius: 5
                  color: table.tileColor(row.modelData.name)
                  Text {
                    anchors.centerIn: parent
                    text: row.modelData.name.charAt(0).toUpperCase()
                    color: "#ffffff"
                    font.family: table.view.host.theme.textFontFamily
                    font.pixelSize: table.view.host.theme.px(10)
                    font.weight: Font.Bold
                  }
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 42 - (row.showQuit ? 24 : 0)
                text: row.modelData.name
                elide: Text.ElideRight
                color: row.ink
                font.family: table.view.host.theme.textFontFamily
                font.letterSpacing: table.view.host.theme.tracking(table.view.host.theme.textFontFamily, table.view.detailFontSize)
                font.features: { "tnum": 1 }
                font.pixelSize: table.view.detailFontSize
                // The full name, its PID (or its app's processes), and the
                // command that started it.
                Tooltip {
                  theme: table.view.host.theme
                  maxWidth: 360
                  text: row.modelData.pid < 0 ? ""
                    : row.modelData.name + "\n"
                      + (row.modelData.pids ? row.modelData.pids.length + " processes" : "PID " + row.modelData.pid)
                      + (row.modelData.command ? "\n" + row.modelData.command : "")
                }
              }
            }
            // Quit Process, at the end of the name.
            Rectangle {
              scale: quitMouse.pressed ? 0.9 : 1
              Behavior on scale { MotionAnimation { theme: table.view.host.theme; pace: quitMouse.pressed ? "press" : "standard" } }
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
            readonly property bool isCpu: modelData.key === "cpu"
            // CPU: a small bar of the share before it.
            // Only for a process doing work (1% or more), so idle rows
            // show no sliver.
            Rectangle {
              visible: cellItem.isCpu && table.share(row.modelData) >= 1
              x: 6
              anchors.verticalCenter: parent.verticalCenter
              width: 48
              height: 3
              radius: 1.5
              color: table.view.host.theme.fill(row.selected ? "strong" : "raised")
              Rectangle {
                width: Math.max(2, parent.width * Math.min(1, table.share(row.modelData) / 100))
                height: parent.height
                radius: parent.radius
                color: row.selected ? table.view.accentInk : table.share(row.modelData) >= 50 ? table.view.host.theme.system.orange : table.view.host.theme.system.blue
              }
            }
            Text {
              visible: !cellItem.isName
              anchors.right: parent.right
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              readonly property real cpu: table.share(row.modelData)
              text: cellItem.isName ? "" : table.cell(row.modelData, cellItem.modelData.key)
              color: row.selected ? row.ink : cellItem.isCpu ? table.cpuColor(cpu) : table.view.text
              font.family: table.view.host.theme.textFontFamily
              font.letterSpacing: table.view.host.theme.tracking(table.view.host.theme.textFontFamily, table.view.host.theme.px(12))
              font.pixelSize: table.view.host.theme.px(12)
              font.weight: cellItem.isCpu && cpu >= 10 ? Font.Bold : Font.Normal
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
    font.family: table.view.host.theme.textFontFamily
    font.letterSpacing: table.view.host.theme.tracking(table.view.host.theme.textFontFamily, table.view.host.theme.px(13))
    font.features: { "tnum": 1 }
    font.pixelSize: table.view.host.theme.px(13)
  }
}
