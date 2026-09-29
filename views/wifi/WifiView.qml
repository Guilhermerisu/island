import QtQuick
import QtQuick.Layouts
import "../../components"
import Quickshell.Io
import Quickshell.Networking

// Wi-Fi networks, opened from the Control Center's Wi-Fi tile, laid out like
// macOS's Wi-Fi module: Known Networks (the connected one first),
// a collapsible Other Networks, and Wi-Fi Settings. Connect, disconnect, and
// forget go through NetworkManager; secured networks that aren't saved ask for
// a password inline.
// Keyboard: ↑/↓ (or Tab, j/k) to move, Enter/Space to toggle, connect or
// disconnect, open Other Networks, or open settings; Delete/x to forget; Esc
// to cancel a password or go back to the Control Center.
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
  readonly property bool mockMode: !!host.settings.hardwarePreview

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
  readonly property bool powered: mockMode ? host.previewWifiEnabled : !!device && Networking.wifiEnabled
  readonly property bool scanning: mockMode ? active && powered : !!(device && device.scannerEnabled)

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
    if (mockMode) {
      if (!host.previewWifiEnabled) return []
      var demoNetworks = [
        { name: "Studio Wi-Fi", section: "known", secure: true, strength: 0.9 },
        { name: "Home Network", section: "known", secure: true, strength: 0.76 },
        { name: "Cafe Guest", section: "nearby", secure: false, strength: 0.68 },
        { name: "Omarchy Guest", section: "nearby", secure: true, strength: 0.52 }
      ]
      var demoGroups = { connected: [], known: [], nearby: [] }
      for (var j = 0; j < demoNetworks.length; j++) {
        var demo = demoNetworks[j]
        var isConnected = host.previewWifiConnected === demo.name
        demoGroups[isConnected ? "connected" : demo.section].push({
          address: demo.name, name: demo.name, section: isConnected ? "connected" : demo.section,
          connected: isConnected, secure: demo.secure, strength: demo.strength, pending: ""
        })
      }
      var demoTitles = { connected: "Connected", known: "Saved Networks", nearby: "Available" }
      var demoRows = []
      for (var demoKey in demoTitles) {
        if (!demoGroups[demoKey].length) continue
        demoRows.push({ header: demoTitles[demoKey] })
        demoRows = demoRows.concat(demoGroups[demoKey])
      }
      return demoRows
    }
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

  // What the list shows: Known Networks (connected first, then saved) and
  // Other Networks, which starts collapsed while a network is connected, as
  // on macOS.
  readonly property bool anyConnected: rows.some(function(r) { return !!r.connected })
  property var otherOpenChoice: null
  readonly property bool otherOpen: otherOpenChoice !== null ? otherOpenChoice : !anyConnected
  readonly property var displayRows: {
    var known = rows.filter(function(r) { return r.address && r.section !== "nearby" })
    var other = rows.filter(function(r) { return r.address && r.section === "nearby" })
    var out = []
    if (known.length) out = out.concat([{ header: "Known Networks" }], known)
    if (other.length) {
      out.push({ header: "Other Networks", toggle: true })
      if (otherOpen) out = out.concat(other)
    }
    return out
  }

  // Keyboard cursor, by name so it survives rows reordering; "other" is the
  // Other Networks header, "settings" the footer.
  property string selectedKey: ""
  // The keyboard highlight appears once the keys are used, as on macOS.
  property bool usingKeys: false
  readonly property var navKeys: {
    var keys = []
    for (var i = 0; i < displayRows.length; i++) {
      if (displayRows[i].address) keys.push(displayRows[i].address)
      else if (displayRows[i].toggle) keys.push("other")
    }
    keys.push("settings")
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
  function rowFor(name) {
    for (var i = 0; i < rows.length; i++) if (rows[i].address === name) return rows[i]
    return null
  }

  function networkFor(name) {
    var nets = device && device.networks ? device.networks.values : []
    for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].name === name) return nets[i]
    return null
  }
  Process { id: settingsLauncher; command: ["omarchy-launch-tui", "nmtui"] }
  function openSettings() {
    host.view = "rest"
    settingsLauncher.running = true
  }
  function activate(row) {
    if (row.pending) return
    if (mockMode) {
      if (row.connected) host.previewWifiConnected = ""
      else if (row.section === "nearby" && row.secure) { passwordText = ""; passwordFor = row.address }
      else host.previewWifiConnected = row.address
      return
    }
    var n = networkFor(row.address)
    if (!n) return
    failedName = ""
    if (row.connected) { n.disconnect(); return }
    if (row.section === "nearby" && row.secure) { passwordText = ""; passwordFor = row.address; return }
    attempt = n
    n.connect()
  }
  function join(name, psk) {
    if (mockMode) {
      passwordFor = ""
      if (psk) host.previewWifiConnected = name
      return
    }
    var n = networkFor(name)
    passwordFor = ""
    if (!n || !psk) return
    failedName = ""
    attempt = n
    n.connectWithPsk(psk)
  }
  function forget(row) {
    if (mockMode) return
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
    when: !wf.mockMode && !!wf.device
    target: wf.device
    property: "scannerEnabled"
    value: wf.active && wf.powered
    restoreMode: Binding.RestoreNone
  }

  onActiveChanged: if (active) { selectedKey = ""; passwordFor = ""; failedName = ""; otherOpenChoice = null; usingKeys = false; Qt.callLater(function() { wf.forceActiveFocus() }) }
  Keys.onPressed: function(event) {
    var k = event.key
    var row = wf.rowFor(wf.cursor)
    if (k === Qt.Key_Down || k === Qt.Key_J || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) wf.move(1)
    else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) wf.move(-1)
    else if (!wf.usingKeys && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Delete || k === Qt.Key_X))
      wf.usingKeys = true
    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
      if (wf.cursor === "other") wf.otherOpenChoice = !wf.otherOpen
      else if (wf.cursor === "settings") wf.openSettings()
      else if (row) wf.activate(row)
    } else if (k === Qt.Key_Delete || k === Qt.Key_X) {
      if (row && row.section !== "nearby") wf.forget(row)
    } else if (k === Qt.Key_Escape) wf.host.view = "controls"
    else return
    event.accepted = true
  }

  spacing: 8

  // Header: back to the Control Center and the title. Wi-Fi itself turns on
  // and off from the Control Center's tile.
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
      color: backMouse.containsMouse ? wf.well : wf.card
      Tooltip { text: "Control Center" }
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
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: body.implicitHeight + 12
    radius: 16
    color: wf.card
    border.width: 1
    border.color: wf.edge

    ColumnLayout {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 6
      spacing: 0

      Text {
        visible: !wf.displayRows.length
        Layout.fillWidth: true
        Layout.preferredHeight: 70
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: !wf.mockMode && !wf.device ? "No Wi-Fi adapter" : !wf.powered ? "Wi-Fi is off" : "Looking for networks…"
        color: wf.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: 14
      }

      ListView {
        id: list
        visible: wf.displayRows.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 460)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: wf.displayRows
        delegate: Item {
          id: row
          required property var modelData
          required property int index
          readonly property bool isHeader: modelData.header !== undefined
          readonly property bool isSelected: wf.usingKeys && (isHeader ? (!!modelData.toggle && wf.cursor === "other") : modelData.address === wf.cursor)
          readonly property bool askingPassword: !isHeader && modelData.address === wf.passwordFor
          width: ListView.view.width
          height: isHeader ? 38 : 48

          // Section header; Other Networks opens and closes, with a spinner
          // while Wi-Fi scans.
          Rectangle {
            visible: row.isHeader
            anchors.fill: parent
            anchors.topMargin: row.index > 0 ? 4 : 0
            radius: 8
            color: row.modelData.toggle && (headerMouse.containsMouse || row.isSelected) ? wf.tile : "transparent"
            Rectangle {
              visible: row.index > 0
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              anchors.bottom: parent.top
              anchors.bottomMargin: 2
              height: 1
              color: wf.host.withAlpha(wf.text, 0.09)
            }
            Text {
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.header || ""
              color: wf.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: 14
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
                visible: wf.scanning
                text: "󰑓"
                color: wf.textMuted
                font.family: wf.iconFont
                font.pixelSize: 14
                // Stepped, so scanning doesn't repaint the island at the
                // display's full refresh rate.
                Timer {
                  interval: 40
                  repeat: true
                  running: spinner.visible && wf.active
                  onTriggered: spinner.rotation = (spinner.rotation + 360 * 40 / 1200) % 360
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅂"
                rotation: wf.otherOpen ? 90 : 0
                color: wf.textMuted
                font.family: wf.iconFont
                font.pixelSize: 17
                Behavior on rotation { NumberAnimation { duration: 160 * wf.host.motionScale; easing.type: Easing.OutCubic } }
              }
            }
            MouseArea {
              id: headerMouse
              anchors.fill: parent
              enabled: !!row.modelData.toggle
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: wf.otherOpenChoice = !wf.otherOpen
            }
          }

          // A network: round signal icon (accent when connected), the name,
          // and a lock for secured ones.
          Rectangle {
            visible: !row.isHeader
            anchors.fill: parent
            radius: 8
            color: rowMouse.containsMouse || forgetMouse.containsMouse || row.isSelected || row.askingPassword ? wf.tile : "transparent"

            Rectangle {
              id: badge
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 34; height: 34; radius: 17
              color: row.modelData.connected ? wf.accent : wf.well
              // The same glyph as the Control Center's Wi-Fi tile.
              Text {
                anchors.centerIn: parent
                text: "\uf1eb"
                color: row.modelData.connected ? wf.accentInk : wf.text
                font.family: wf.iconFont
                font.pixelSize: 18
              }
            }
            Column {
              visible: !row.askingPassword
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
                color: wf.text
                font.family: "Adwaita Sans"
                font.pixelSize: 15
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
                font.pixelSize: 12
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
            // Password for joining a secured network: a macOS-style field.
            // Enter joins, Esc cancels.
            Rectangle {
              visible: row.askingPassword
              anchors.left: badge.right
              anchors.leftMargin: 10
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              height: 32
              radius: 7
              color: wf.well
              border.width: 2
              border.color: wf.host.withAlpha(wf.accent, 0.55)
              TextInput {
                id: password
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                color: wf.text
                selectionColor: wf.host.withAlpha(wf.accent, 0.4)
                selectedTextColor: wf.text
                font.family: "Adwaita Sans"
                font.pixelSize: 15
                clip: true
                function sync() { if (row.askingPassword) { text = wf.passwordText; forceActiveFocus() } }
                Component.onCompleted: sync()
                onVisibleChanged: sync()
                onTextChanged: if (row.askingPassword) wf.passwordText = text
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
            }
            // Trailing: forget (saved networks, on hover) and the lock.
            Row {
              id: trailing
              visible: !row.askingPassword
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6
              Rectangle {
                visible: row.modelData.section !== "nearby" && !row.modelData.pending
                  && (rowMouse.containsMouse || forgetMouse.containsMouse || row.isSelected)
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 13
                color: forgetMouse.containsMouse ? wf.wellHover : "transparent"
                Tooltip { text: "Forget This Network" }
                Text {
                  anchors.centerIn: parent
                  text: "󰅖"
                  color: forgetMouse.containsMouse ? wf.text : wf.textMuted
                  font.family: wf.iconFont
                  font.pixelSize: 15
                }
                MouseArea {
                  id: forgetMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: wf.forget(row.modelData)
                }
              }
              Text {
                visible: !!row.modelData.secure
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌾"
                color: wf.textMuted
                font.family: wf.iconFont
                font.pixelSize: 15
              }
            }
          }
        }
      }

      // Footer: Wi-Fi Settings, below a hairline, as on macOS.
      Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        Layout.preferredHeight: 1
        color: wf.host.withAlpha(wf.text, 0.09)
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 8
        color: settingsMouse.containsMouse || (wf.usingKeys && wf.cursor === "settings") ? wf.tile : "transparent"
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "Wi-Fi Settings…"
          color: wf.text
          font.family: "Adwaita Sans"
          font.pixelSize: 15
        }
        MouseArea {
          id: settingsMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: wf.openSettings()
        }
      }
    }
  }
}
