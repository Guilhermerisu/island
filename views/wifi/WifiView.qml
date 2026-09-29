import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

// Wi-Fi networks, opened from the Control Center's Wi-Fi tile. Same layout as
// the Bluetooth view: connected, saved, and available networks, with
// connect/disconnect/forget through NetworkManager. Secured networks that
// aren't saved ask for a password inline.
// Keyboard: ↑/↓ (or Tab, j/k) to move between the power switch and networks,
// Enter/Space to toggle or connect/disconnect, Delete/x to forget, Esc to
// cancel a password or go back to the Control Center.
ColumnLayout {
  id: wf
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

  readonly property var device: {
    var devs = Networking.devices ? Networking.devices.values : []
    var fallback = null
    for (var i = 0; i < devs.length; i++) {
      var d = devs[i]
      if (!d || d.type !== DeviceType.Wifi) continue
      if (d.connected) return d
      if (!fallback) fallback = d
    }
    return fallback
  }
  readonly property bool powered: !!device && Networking.wifiEnabled
  readonly property bool scanning: !!(device && device.scannerEnabled)

  // Network being joined, so its connectionFailed can be reported.
  property var attempt: null
  property string failedName: ""
  property string failedReason: ""
  // Name of the network whose password field is open.
  property string passwordFor: ""
  // Kept here, not in the field: delegates are rebuilt whenever rows change.
  property string passwordText: ""

  // Rows hold plain values only, as in the Bluetooth view: networks come and
  // go during scans. Actions look the network up again by name.
  readonly property var rows: {
    var nets = device && device.networks ? device.networks.values : []
    var groups = { connected: [], known: [], nearby: [] }
    for (var i = 0; i < nets.length; i++) {
      var n = nets[i]
      if (!n) continue
      var name = String(n.name || "").trim()
      if (!name) continue
      var section = n.connected ? "connected" : n.known ? "known" : "nearby"
      var pending = n.state === ConnectionState.Connecting ? "connecting"
        : n.state === ConnectionState.Disconnecting ? "disconnecting" : ""
      groups[section].push({
        address: name,
        name: name,
        section: section,
        connected: !!n.connected,
        secure: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe,
        strength: n.signalStrength,
        pending: pending
      })
    }
    var titles = { connected: "Connected", known: "Saved Networks", nearby: "Available" }
    var list = []
    for (var key in titles) {
      var group = groups[key].sort(key === "nearby"
        ? function(a, b) { return b.strength - a.strength }
        : function(a, b) { return a.name.localeCompare(b.name) })
      if (!group.length) continue
      list.push({ header: titles[key] })
      list = list.concat(group)
    }
    return list
  }

  // Keyboard cursor, by name so it survives rows reordering; "power" is the
  // header switch.
  property string selectedKey: ""
  readonly property var navKeys: {
    var keys = wf.device ? ["power"] : []
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
  function rowFor(name) {
    for (var i = 0; i < rows.length; i++) if (rows[i].address === name) return rows[i]
    return null
  }

  function networkFor(name) {
    var nets = device && device.networks ? device.networks.values : []
    for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].name === name) return nets[i]
    return null
  }
  function togglePower() { if (device) Networking.wifiEnabled = !Networking.wifiEnabled }
  function activate(row) {
    if (row.pending) return
    var n = networkFor(row.address)
    if (!n) return
    failedName = ""
    if (row.connected) { n.disconnect(); return }
    if (row.section === "nearby" && row.secure) { passwordText = ""; passwordFor = row.address; return }
    attempt = n
    n.connect()
  }
  function join(name, psk) {
    var n = networkFor(name)
    passwordFor = ""
    if (!n || !psk) return
    failedName = ""
    attempt = n
    n.connectWithPsk(psk)
  }
  function forget(row) {
    var n = networkFor(row.address)
    if (n && !row.pending) n.forget()
  }

  Connections {
    target: wf.attempt
    function onConnectionFailed(reason) {
      wf.failedName = wf.attempt.name
      wf.failedReason = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout
        ? "Wrong password" : "Couldn't connect"
    }
  }

  // Scan only while the view is open.
  Binding {
    when: !!wf.device
    target: wf.device
    property: "scannerEnabled"
    value: wf.active && wf.powered
    restoreMode: Binding.RestoreNone
  }

  onActiveChanged: if (active) { selectedKey = ""; passwordFor = ""; failedName = ""; Qt.callLater(function() { wf.forceActiveFocus() }) }
  Keys.onPressed: function(event) {
    var k = event.key
    var row = wf.rowFor(wf.cursor)
    if (k === Qt.Key_Down || k === Qt.Key_J || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) wf.move(1)
    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) wf.move(-1)
    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
      if (wf.cursor === "power") wf.togglePower()
      else if (row) wf.activate(row)
    } else if (k === Qt.Key_Delete || k === Qt.Key_X) {
      if (row && row.section !== "nearby") wf.forget(row)
    } else if (k === Qt.Key_Escape) wf.host.view = "controls"
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
      color: backMouse.containsMouse ? wf.well : wf.card
      Text { anchors.centerIn: parent; text: "󰅁"; color: wf.text; font.family: wf.iconFont; font.pixelSize: 17 }
      MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wf.host.view = "controls" }
    }
    Text {
      text: "Wi-Fi"
      color: wf.text
      font.family: "Adwaita Sans"
      font.pixelSize: 17
      font.weight: Font.DemiBold
    }
    Item { Layout.fillWidth: true }
    Text {
      visible: wf.scanning
      text: "Scanning…"
      color: wf.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }
    // Power switch.
    Rectangle {
      Layout.preferredWidth: 42
      Layout.preferredHeight: 24
      radius: 12
      opacity: wf.device && Networking.wifiHardwareEnabled !== false ? 1 : 0.5
      color: wf.powered ? wf.accent : wf.well
      border.width: wf.cursor === "power" ? 2 : 0
      border.color: wf.text
      Behavior on color { ColorAnimation { duration: 180 * wf.host.motionScale } }
      Rectangle {
        width: 20; height: 20; radius: 10
        y: 2
        x: wf.powered ? parent.width - width - 2 : 2
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: 180 * wf.host.motionScale; easing.type: Easing.OutCubic } }
      }
      MouseArea {
        anchors.fill: parent
        enabled: !!wf.device
        cursorShape: Qt.PointingHandCursor
        onClicked: wf.togglePower()
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: wf.rows.length ? list.height + 16 : 74
    radius: 16
    color: wf.card
    border.width: 1
    border.color: wf.edge

    Text {
      visible: !wf.rows.length
      anchors.centerIn: parent
      text: !wf.device ? "No Wi-Fi adapter" : !wf.powered ? "Wi-Fi is off" : "Looking for networks…"
      color: wf.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }

    ListView {
      id: list
      visible: wf.rows.length > 0
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 8
      height: Math.min(contentHeight, 520)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: wf.rows
      delegate: Item {
        id: row
        required property var modelData
        readonly property bool isHeader: modelData.header !== undefined
        readonly property bool isSelected: !isHeader && modelData.address === wf.cursor
        readonly property bool askingPassword: !isHeader && modelData.address === wf.passwordFor
        width: ListView.view.width
        height: isHeader ? 30 : 44

        Text {
          visible: row.isHeader
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 6
          text: row.modelData.header || ""
          color: wf.textMuted
          font.family: "Adwaita Sans"
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }

        Rectangle {
          visible: !row.isHeader
          anchors.fill: parent
          radius: 10
          color: rowMouse.containsMouse || row.isSelected || row.askingPassword ? wf.tile : "transparent"

          // Accent bar marking the keyboard cursor, as in ListPicker.
          Rectangle {
            visible: row.isSelected
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3; height: 22; radius: 1.5
            color: wf.accent
          }

          Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16
            color: row.modelData.connected ? wf.accent : wf.well
            Text {
              anchors.centerIn: parent
              readonly property int bars: Math.max(0, Math.min(4, Math.floor((row.modelData.strength || 0) * 5)))
              text: (row.modelData.secure ? ["󰤬", "󰤡", "󰤤", "󰤧", "󰤪"] : ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"])[bars]
              color: row.modelData.connected ? wf.accentInk : wf.text
              font.family: wf.iconFont
              font.pixelSize: 16
            }
          }
          Column {
            visible: !row.askingPassword
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
              color: wf.text
              font.family: "Adwaita Sans"
              font.pixelSize: 13
              font.weight: Font.Medium
            }
            Text {
              width: parent.width
              readonly property string status: row.modelData.pending === "connecting" ? "Connecting…"
                : row.modelData.pending === "disconnecting" ? "Disconnecting…"
                : row.modelData.name === wf.failedName ? wf.failedReason
                : ""
              visible: status !== ""
              text: status
              color: wf.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: 11
            }
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: !row.askingPassword
            hoverEnabled: true
            cursorShape: row.modelData.pending ? Qt.BusyCursor : Qt.PointingHandCursor
            onClicked: wf.activate(row.modelData)
          }
          // Password for joining a secured network; Enter joins, Esc cancels.
          TextInput {
            id: password
            visible: row.askingPassword
            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            echoMode: TextInput.Password
            color: wf.text
            selectionColor: wf.host.withAlpha(wf.accent, 0.4)
            selectedTextColor: wf.text
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            clip: true
            function sync() { if (visible) { text = wf.passwordText; forceActiveFocus() } }
            Component.onCompleted: sync()
            onVisibleChanged: sync()
            onTextChanged: if (visible) wf.passwordText = text
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) wf.join(row.modelData.address, text)
              else if (event.key === Qt.Key_Escape) wf.passwordFor = ""
              else return
              event.accepted = true
              wf.forceActiveFocus()
            }
            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: password.text === ""
              text: "Password for " + (row.modelData.name || "")
              color: wf.textMuted
              font: password.font
            }
          }
          Row {
            id: actions
            visible: !row.askingPassword
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.pending ? "" : row.modelData.connected ? "Disconnect" : "Connect"
              visible: rowMouse.containsMouse || forgetMouse.containsMouse || row.isSelected
              color: wf.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: 11
            }
            // Forget, for saved networks.
            Rectangle {
              visible: row.modelData.section !== "nearby" && !row.modelData.pending
              width: 24; height: 24; radius: 12
              color: forgetMouse.containsMouse ? wf.wellHover : "transparent"
              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: forgetMouse.containsMouse ? wf.text : wf.textMuted
                font.family: wf.iconFont
                font.pixelSize: 13
              }
              MouseArea {
                id: forgetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: wf.forget(row.modelData)
              }
            }
          }
        }
      }
    }
  }
}
