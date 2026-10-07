import QtQuick
import QtQuick.Layouts
import "../../components"
import Quickshell
import Quickshell.Bluetooth

// Bluetooth devices, opened from the Control Center's Bluetooth tile, laid out
// like the Wi-Fi view and macOS's Bluetooth module: My Devices (connected
// first, then remembered) and a collapsible Other Devices, found while the
// view scans. Bluetooth itself turns on and off from the Control Center's
// tile. Actions use omarchy-bluetooth-device.
// Keyboard: ↑/↓ (or Tab, j/k) to move, Enter/Space to connect, disconnect, or
// open Other Devices; Delete/x to forget; Esc to go back to the Control
// Center.
ColumnLayout {
  id: bt
  required property var host
  property bool active: false

  readonly property color accent: host.theme.accent
  readonly property color accentInk: host.theme.accentText
  readonly property color text: host.theme.text
  readonly property color textMuted: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.6))
  readonly property color tile: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.11))
  readonly property color card: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.075))
  readonly property color edge: host.theme.withAlpha(text, 0.05)
  readonly property color well: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.16))
  readonly property color wellHover: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.22))
  readonly property string iconFont: host.theme.fontFamily

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool powered: !!(adapter && adapter.enabled)
  readonly property bool scanning: !!(adapter && adapter.discovering)
  // Set once we start a scan, cleared once BlueZ reports it down. Nothing
  // else ends the scan quickshell holds, and a lingering one starves A2DP.
  property bool owesDiscoveryStop: false
  // Address -> "connecting" | "disconnecting" | "forgetting".
  property var pending: ({})

  // Rows hold plain values only: a live BlueZ Device in a delegate can be
  // destroyed mid-incubation during discovery churn and crash quickshell.
  // Actions look the device up again by address.
  readonly property var rows: {
    var devs = Bluetooth.devices ? Bluetooth.devices.values : []
    var groups = { connected: [], known: [], nearby: [] }
    for (var i = 0; i < devs.length; i++) {
      var d = devs[i]
      if (!d) continue
      var name = String(d.deviceName || d.name || "").trim()
      if (!name || /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(name) || /^[0-9a-f-]{32,36}$/i.test(name)) continue
      var section = d.connected ? "connected" : (d.paired || d.bonded || d.trusted) ? "known" : "nearby"
      var action = pending[d.address] || ""
      if ((action === "connecting" && d.connected) || (action === "disconnecting" && !d.connected)
          || (action === "forgetting" && section === "nearby")) action = ""
      groups[section].push({
        address: String(d.address || ""),
        name: name,
        section: section,
        connected: !!d.connected,
        battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1,
        pending: action
      })
    }
    var titles = { connected: "Connected", known: "My Devices", nearby: "Nearby" }
    var list = []
    for (var key in titles) {
      if (key === "nearby" && !scanning) continue
      var group = groups[key].sort(function(a, b) { return a.name.localeCompare(b.name) })
      if (!group.length) continue
      list.push({ header: titles[key] })
      list = list.concat(group)
    }
    return list
  }

  // What the list shows: My Devices (connected first, then remembered) and
  // Other Devices, which starts collapsed while a device is connected, as the
  // Wi-Fi view's Other Networks does.
  readonly property bool anyConnected: rows.some(function(r) { return !!r.connected })
  property var otherOpenChoice: null
  readonly property bool otherOpen: otherOpenChoice !== null ? otherOpenChoice : !anyConnected
  readonly property var displayRows: {
    var mine = rows.filter(function(r) { return r.address && r.section !== "nearby" })
    var other = rows.filter(function(r) { return r.address && r.section === "nearby" })
    var out = []
    if (mine.length) out = out.concat([{ header: "My Devices" }], mine)
    if (other.length || scanning) {
      out.push({ header: "Other Devices", toggle: true })
      if (otherOpen) out = out.concat(other)
    }
    return out
  }

  // Keyboard cursor, by address so it survives rows reordering; "other" is the
  // Other Devices header.
  property string selectedKey: ""
  // The keyboard highlight appears once the keys are used, as on macOS.
  property bool usingKeys: false
  readonly property var navKeys: {
    var keys = []
    for (var i = 0; i < displayRows.length; i++) {
      if (displayRows[i].address) keys.push(displayRows[i].address)
      else if (displayRows[i].toggle) keys.push("other")
    }
    return keys
  }
  readonly property string cursor: navKeys.indexOf(selectedKey) !== -1 ? selectedKey : navKeys[0] || ""
  onCursorChanged: {
    for (var i = 0; i < displayRows.length; i++) {
      var r = displayRows[i]
      if (r.address === cursor || (cursor === "other" && r.toggle)) { list.positionViewAtIndex(i, ListView.Contain); return }
    }
  }
  function move(delta) {
    if (!usingKeys) { usingKeys = true; return }
    var i = navKeys.indexOf(cursor)
    if (i !== -1) selectedKey = navKeys[Math.max(0, Math.min(navKeys.length - 1, i + delta))]
  }
  function rowFor(address) {
    for (var i = 0; i < rows.length; i++) if (rows[i].address === address) return rows[i]
    return null
  }

  function deviceFor(address) {
    var devs = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < devs.length; i++) if (devs[i] && devs[i].address === address) return devs[i]
    return null
  }
  function setPending(address, action) {
    var next = {}
    for (var k in pending) next[k] = pending[k]
    if (action) next[address] = action
    else delete next[address]
    pending = next
    if (action) pendingTimeout.restart()
  }
  function run(row, action, label) {
    setPending(row.address, label)
    Quickshell.execDetached(["omarchy-bluetooth-device", action, row.address])
  }
  function activate(row) {
    if (row.pending) return
    if (row.connected) {
      var d = deviceFor(row.address)
      if (d && d.disconnect) d.disconnect()
      run(row, "disconnect", "disconnecting")
    } else run(row, row.section === "known" ? "connect" : "pair", "connecting")
  }

  // Pairing gives up after ~20s in omarchy-bluetooth-device; drop any spinner
  // that never saw its state change.
  Timer { id: pendingTimeout; interval: 25000; onTriggered: bt.pending = ({}) }

  // BlueZ rejects StartDiscovery while the adapter powers up, and scans time
  // out on their own: keep nudging it on while the view is open.
  Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: bt.active && bt.powered && !bt.scanning
    onTriggered: { bt.owesDiscoveryStop = true; bt.adapter.discovering = true }
  }
  // Stop bound to BlueZ's confirmed state, not a write at close: quickshell
  // drops a write matching the last reported value, so a stop sent before a
  // start is confirmed would be swallowed.
  Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    property int attempts: 0
    running: !bt.active && bt.owesDiscoveryStop && bt.scanning
    onRunningChanged: if (running) attempts = 0
    onTriggered: {
      if (++attempts > 3) { bt.owesDiscoveryStop = false; return }
      bt.adapter.discovering = false
    }
  }
  Connections {
    target: bt.adapter
    function onDiscoveringChanged() { if (!bt.adapter.discovering) bt.owesDiscoveryStop = false }
  }

  onActiveChanged: if (active) { selectedKey = ""; otherOpenChoice = null; usingKeys = false; Qt.callLater(function() { bt.forceActiveFocus() }) }
  Keys.onPressed: function(event) {
    var k = event.key
    var row = bt.rowFor(bt.cursor)
    if (k === Qt.Key_Down || k === Qt.Key_J || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) bt.move(1)
    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) bt.move(-1)
    else if (!bt.usingKeys && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Delete || k === Qt.Key_X))
      bt.usingKeys = true
    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
      if (bt.cursor === "other") bt.otherOpenChoice = !bt.otherOpen
      else if (row) bt.activate(row)
    } else if (k === Qt.Key_Delete || k === Qt.Key_X) {
      if (row && row.section !== "nearby" && !row.pending) bt.run(row, "forget", "forgetting")
    } else if (k === Qt.Key_Escape) bt.host.view = "controls"
    else return
    event.accepted = true
  }

  spacing: 8

  // Header: back to the Control Center and the title.
  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    Layout.leftMargin: 4
    Layout.rightMargin: 6
    spacing: 8
    Rectangle {
      Layout.preferredWidth: 32
      Layout.preferredHeight: 32
      radius: 16
      color: backMouse.containsMouse ? bt.well : bt.card
      Tooltip { theme: bt.host.theme; text: "Control Center" }
      Text { anchors.centerIn: parent; text: "󰅁"; color: bt.text; font.family: bt.iconFont; font.pixelSize: bt.host.theme.px(17) }
      MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.host.view = "controls" }
    }
    Text {
      text: "Bluetooth"
      color: bt.text
      font.family: bt.host.theme.textFontFamily
      font.pixelSize: bt.host.theme.px(17)
      font.weight: Font.DemiBold
    }
    Item { Layout.fillWidth: true }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: body.implicitHeight + 12
    radius: 16
    color: bt.card
    border.width: 1
    border.color: bt.edge

    ColumnLayout {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 6
      spacing: 0

      Text {
        visible: !bt.displayRows.length
        Layout.fillWidth: true
        Layout.preferredHeight: 70
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: !bt.adapter ? "No Bluetooth adapter" : !bt.powered ? "Bluetooth is off" : "Looking for devices…"
        color: bt.textMuted
        font.family: bt.host.theme.textFontFamily
        font.pixelSize: bt.host.theme.px(14)
      }

      ListView {
        id: list
        visible: bt.displayRows.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 460)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: bt.displayRows
        delegate: Item {
          id: row
          required property var modelData
          required property int index
          readonly property bool isHeader: modelData.header !== undefined
          readonly property bool isSelected: bt.usingKeys && (isHeader ? (!!modelData.toggle && bt.cursor === "other") : modelData.address === bt.cursor)
          width: ListView.view.width
          height: isHeader ? 38 : 48

          // Section header; Other Devices opens and closes, with a spinner
          // while Bluetooth scans.
          Rectangle {
            visible: row.isHeader
            anchors.fill: parent
            anchors.topMargin: row.index > 0 ? 4 : 0
            radius: 8
            color: row.modelData.toggle && (headerMouse.containsMouse || row.isSelected) ? bt.tile : "transparent"
            Rectangle {
              visible: row.index > 0
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              anchors.bottom: parent.top
              anchors.bottomMargin: 2
              height: 1
              color: bt.host.theme.withAlpha(bt.text, 0.09)
            }
            Text {
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.header || ""
              color: bt.textMuted
              font.family: bt.host.theme.textFontFamily
              font.pixelSize: bt.host.theme.px(14)
              font.weight: Font.DemiBold
            }
            Row {
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8
              visible: !!row.modelData.toggle
              Text {
                id: spinner
                anchors.verticalCenter: parent.verticalCenter
                visible: bt.scanning
                text: "󰑓"
                color: bt.textMuted
                font.family: bt.iconFont
                font.pixelSize: bt.host.theme.px(14)
                AmbientRotation {
                  target: spinner
                  period: 1200
                  running: spinner.visible && bt.active
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅂"
                rotation: bt.otherOpen ? 90 : 0
                color: bt.textMuted
                font.family: bt.iconFont
                font.pixelSize: bt.host.theme.px(17)
                Behavior on rotation { MotionAnimation { theme: bt.host.theme; pace: "standard" } }
              }
            }
            MouseArea {
              id: headerMouse
              anchors.fill: parent
              enabled: !!row.modelData.toggle
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: bt.otherOpenChoice = !bt.otherOpen
            }
          }

          // A device: round Bluetooth icon (accent when connected), the name
          // and what it's doing, and its battery on the right.
          Rectangle {
            visible: !row.isHeader
            anchors.fill: parent
            radius: 8
            color: rowMouse.containsMouse || forgetMouse.containsMouse || row.isSelected ? bt.tile : "transparent"

            Rectangle {
              id: badge
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 34; height: 34; radius: 17
              color: row.modelData.connected ? bt.accent : bt.well
              Text {
                anchors.centerIn: parent
                text: "󰂯"
                color: row.modelData.connected ? bt.accentInk : bt.text
                font.family: bt.iconFont
                font.pixelSize: bt.host.theme.px(18)
              }
            }
            Column {
              anchors.left: badge.right
              anchors.leftMargin: 10
              anchors.right: trailing.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              Text {
                width: parent.width
                text: row.modelData.name || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: bt.text
                font.family: bt.host.theme.textFontFamily
                font.pixelSize: bt.host.theme.px(15)
              }
              Text {
                width: parent.width
                readonly property string status: row.modelData.pending === "connecting" ? "Connecting…"
                  : row.modelData.pending === "disconnecting" ? "Disconnecting…"
                  : row.modelData.pending === "forgetting" ? "Forgetting…"
                  : ""
                visible: status !== ""
                text: status
                color: bt.textMuted
                font.family: bt.host.theme.textFontFamily
                font.pixelSize: bt.host.theme.px(12)
              }
            }
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: row.modelData.pending ? Qt.BusyCursor : Qt.PointingHandCursor
              onClicked: bt.activate(row.modelData)
            }
            // Trailing: the battery of a connected device, as macOS shows it,
            // then forget (remembered devices, on hover).
            Row {
              id: trailing
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8
              Row {
                visible: !!row.modelData.connected && row.modelData.battery >= 0 && !row.modelData.pending
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                readonly property bool low: row.modelData.battery <= 20
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.modelData.battery + "%"
                  color: parent.low ? "#ff453a" : bt.textMuted
                  font.family: bt.host.theme.textFontFamily
                  font.pixelSize: bt.host.theme.px(13)
                  font.features: { "tnum": 1 }
                }
                BatteryIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  level: row.modelData.battery || 0
                  low: parent.low
                  color: bt.text
                }
              }
              Rectangle {
                visible: row.modelData.section !== "nearby" && !row.modelData.pending
                  && (rowMouse.containsMouse || forgetMouse.containsMouse || row.isSelected)
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 13
                color: forgetMouse.containsMouse ? bt.wellHover : "transparent"
                Tooltip { theme: bt.host.theme; text: "Forget This Device" }
                Text {
                  anchors.centerIn: parent
                  text: "󰅖"
                  color: forgetMouse.containsMouse ? bt.text : bt.textMuted
                  font.family: bt.iconFont
                  font.pixelSize: bt.host.theme.px(15)
                }
                MouseArea {
                  id: forgetMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: bt.run(row.modelData, "forget", "forgetting")
                }
              }
            }
          }
        }
      }
    }
  }
}
