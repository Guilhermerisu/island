import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Bluetooth devices, opened from the Control Center's Bluetooth tile. Mirrors
// Omarchy's stock Bluetooth panel: connected, remembered, and nearby devices
// (nearby only while scanning), with pair/connect/disconnect/forget going
// through omarchy-bluetooth-device.
// Keyboard: ↑/↓ (or Tab, j/k) to move between the power switch and devices,
// Enter/Space to toggle or connect/disconnect, Delete/x to forget, Esc to go
// back to the Control Center.
ColumnLayout {
  id: bt
  required property var host
  property bool active: false

  readonly property color accent: host.colorAccent
  readonly property color accentInk: host.colorAccentText
  readonly property color text: host.colorText
  readonly property color textMuted: Qt.tint(host.colorBackground, host.withAlpha(text, 0.6))
  readonly property color tile: Qt.tint(host.colorBackground, host.withAlpha(text, 0.11))
  readonly property color card: Qt.tint(host.colorBackground, host.withAlpha(text, 0.075))
  readonly property color edge: host.withAlpha(text, 0.05)
  readonly property color well: Qt.tint(host.colorBackground, host.withAlpha(text, 0.16))
  readonly property color wellHover: Qt.tint(host.colorBackground, host.withAlpha(text, 0.22))
  readonly property string iconFont: host.fontFamily

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

  // Keyboard cursor, by address so it survives rows reordering; "power" is the
  // header switch.
  property string selectedKey: ""
  readonly property var navKeys: {
    var keys = bt.adapter ? ["power"] : []
    for (var i = 0; i < rows.length; i++) if (rows[i].address) keys.push(rows[i].address)
    return keys
  }
  readonly property string cursor: navKeys.indexOf(selectedKey) !== -1 ? selectedKey : navKeys.length > 1 ? navKeys[1] : navKeys[0] || ""
  onCursorChanged: {
    for (var i = 0; i < rows.length; i++) if (rows[i].address === cursor) { list.positionViewAtIndex(i, ListView.Contain); return }
  }
  function move(delta) {
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

  onActiveChanged: if (active) { selectedKey = ""; Qt.callLater(function() { bt.forceActiveFocus() }) }
  Keys.onPressed: function(event) {
    var k = event.key
    var row = bt.rowFor(bt.cursor)
    if (k === Qt.Key_Down || k === Qt.Key_J || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) bt.move(1)
    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) bt.move(-1)
    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
      if (bt.cursor === "power") bt.adapter.enabled = !bt.adapter.enabled
      else if (row) bt.activate(row)
    } else if (k === Qt.Key_Delete || k === Qt.Key_X) {
      if (row && row.section !== "nearby" && !row.pending) bt.run(row, "forget", "forgetting")
    } else if (k === Qt.Key_Escape) bt.host.view = "controls"
    else return
    event.accepted = true
  }

  spacing: 10

  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    spacing: 8
    Rectangle {
      Layout.preferredWidth: 32
      Layout.preferredHeight: 32
      radius: 16
      color: backMouse.containsMouse ? bt.well : bt.card
      Text { anchors.centerIn: parent; text: "󰅁"; color: bt.text; font.family: bt.iconFont; font.pixelSize: 17 }
      MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.host.view = "controls" }
    }
    Text {
      text: "Bluetooth"
      color: bt.text
      font.family: "Adwaita Sans"
      font.pixelSize: 17
      font.weight: Font.DemiBold
    }
    Item { Layout.fillWidth: true }
    Text {
      visible: bt.scanning
      text: "Scanning…"
      color: bt.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }
    // Power switch.
    Rectangle {
      Layout.preferredWidth: 42
      Layout.preferredHeight: 24
      radius: 12
      opacity: bt.adapter ? 1 : 0.5
      color: bt.powered ? bt.accent : bt.well
      border.width: bt.cursor === "power" ? 2 : 0
      border.color: bt.text
      Behavior on color { ColorAnimation { duration: 180 * bt.host.motionScale } }
      Rectangle {
        width: 20; height: 20; radius: 10
        y: 2
        x: bt.powered ? parent.width - width - 2 : 2
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: 180 * bt.host.motionScale; easing.type: Easing.OutCubic } }
      }
      MouseArea {
        anchors.fill: parent
        enabled: !!bt.adapter
        cursorShape: Qt.PointingHandCursor
        onClicked: bt.adapter.enabled = !bt.adapter.enabled
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: bt.rows.length ? list.height + 16 : 74
    radius: 16
    color: bt.card
    border.width: 1
    border.color: bt.edge

    Text {
      visible: !bt.rows.length
      anchors.centerIn: parent
      text: !bt.adapter ? "No Bluetooth adapter" : !bt.powered ? "Bluetooth is off" : "Looking for devices…"
      color: bt.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }

    ListView {
      id: list
      visible: bt.rows.length > 0
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 8
      height: Math.min(contentHeight, 520)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: bt.rows
      delegate: Item {
        id: row
        required property var modelData
        readonly property bool isHeader: modelData.header !== undefined
        readonly property bool isSelected: !isHeader && modelData.address === bt.cursor
        width: ListView.view.width
        height: isHeader ? 30 : 44

        Text {
          visible: row.isHeader
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 6
          text: row.modelData.header || ""
          color: bt.textMuted
          font.family: "Adwaita Sans"
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }

        Rectangle {
          visible: !row.isHeader
          anchors.fill: parent
          radius: 10
          color: rowMouse.containsMouse || row.isSelected ? bt.tile : "transparent"

          // Accent bar marking the keyboard cursor, as in ListPicker.
          Rectangle {
            visible: row.isSelected
            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 3; height: 22; radius: 1.5
            color: bt.accent
          }

          Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16
            color: row.modelData.connected ? bt.accent : bt.well
            Text {
              anchors.centerIn: parent
              text: "󰂯"
              color: row.modelData.connected ? bt.accentInk : bt.text
              font.family: bt.iconFont
              font.pixelSize: 16
            }
          }
          Column {
            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: actions.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            Text {
              width: parent.width
              text: row.modelData.name || ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: bt.text
              font.family: "Adwaita Sans"
              font.pixelSize: 13
              font.weight: Font.Medium
            }
            Text {
              width: parent.width
              readonly property string status: row.modelData.pending === "connecting" ? "Connecting…"
                : row.modelData.pending === "disconnecting" ? "Disconnecting…"
                : row.modelData.pending === "forgetting" ? "Forgetting…"
                : row.modelData.battery >= 0 ? row.modelData.battery + "% battery" : ""
              visible: status !== ""
              text: status
              color: bt.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: 11
            }
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.modelData.pending ? Qt.BusyCursor : Qt.PointingHandCursor
            onClicked: bt.activate(row.modelData)
          }
          Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.pending ? "" : row.modelData.connected ? "Disconnect" : "Connect"
              visible: rowMouse.containsMouse || forgetMouse.containsMouse || row.isSelected
              color: bt.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: 11
            }
            // Forget, for remembered devices.
            Rectangle {
              visible: row.modelData.section !== "nearby" && !row.modelData.pending
              width: 24; height: 24; radius: 12
              color: forgetMouse.containsMouse ? bt.wellHover : "transparent"
              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: forgetMouse.containsMouse ? bt.text : bt.textMuted
                font.family: bt.iconFont
                font.pixelSize: 13
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
