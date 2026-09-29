import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets

// A compact Control Center with grouped switches, sliders, and notifications.
ColumnLayout {
  id: cc
  required property var host
  property bool active: false

  // Keep the black island while deriving its controls from the active theme.
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
  readonly property int animDuration: 180 * host.motionScale
  property bool editMode: false
  property bool addPickerOpen: false
  property string draggedKey: ""
  property var previewOrder: []
  readonly property var hiddenControlKeys: host.controlCenterKeys.filter(function(key) { return !host.controlCenterIsShown(key) })

  // --- Network ---
  readonly property var netDevices: Networking.devices ? Networking.devices.values : []
  function findDevice(type) {
    var fallback = null
    for (var i = 0; i < netDevices.length; i++) {
      var d = netDevices[i]
      if (!d || d.type !== type) continue
      if (d.connected) return d
      if (!fallback) fallback = d
    }
    return fallback
  }
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var wifiNetwork: {
    var nets = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].connected) return nets[i]
    return null
  }

  // --- Audio ---
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property var outputs: {
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    return nodes.filter(function(n) { return n && n.isSink && !n.isStream && n.audio })
  }
  property bool outputsOpen: false

  // --- Bluetooth ---
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property var btConnected: {
    var devs = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < devs.length; i++) if (devs[i] && devs[i].connected) return devs[i]
    return null
  }

  // --- Battery / power profile ---
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!(battery && battery.isLaptopBattery)
  readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : 0
  readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
  readonly property var profileNames: ["power-saver", "balanced", "performance"]
  readonly property string profileName: profileNames[PowerProfiles.profile] || "balanced"
  readonly property string batteryIcon: charging ? "󰂄" : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.round(batteryPercent / 10)]
  // Through Omarchy so the choice is remembered per AC/battery, as in its menu.
  function cycleProfile() {
    var usable = PowerProfiles.hasPerformanceProfile ? profileNames : profileNames.slice(0, 2)
    var next = usable[(usable.indexOf(profileName) + 1) % usable.length]
    Quickshell.execDetached(["omarchy-powerprofiles-set", "autodetect", next])
  }

  // --- Shell services ---
  readonly property var notifications: host.shell ? host.shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var nightlight: host.shell ? host.shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property bool dnd: notifications ? !!notifications.doNotDisturb : false
  readonly property bool nightOn: nightlight ? !!nightlight.enabled : false
  readonly property var visibleControlKeys: {
    var hidden = String(host.settings.controlCenterHidden || "").split(",")
    var order = cc.editMode && cc.previewOrder.length ? cc.previewOrder : host.controlCenterKeys
    return order.filter(function(key) {
      return hidden.indexOf(key) === -1 && (cc.editMode || cc.controlPresent(key))
    })
  }
  function controlPresent(key) {
    if (key === "night") return !!nightlight
    if (key === "sound") return !!(sink && sink.audio)
    if (key === "display") return brightnessAvailable
    return true
  }
  function endDrag() { draggedKey = "" }
  function previewMoveAt(x, y) {
    if (x < 0 || y < 0 || x > cardArea.width || y > cardArea.height) return
    var slots = cardArea.positions
    for (var i = 0; i < visibleControlKeys.length; i++) {
      var key = visibleControlKeys[i]
      if (key === draggedKey) continue
      var slot = slots[key]
      if (!slot) continue
      var marginX = Math.min(30, slot.width * 0.2)
      var marginY = Math.min(18, slot.height * 0.2)
      if (x < slot.x + marginX || x > slot.x + slot.width - marginX ||
          y < slot.y + marginY || y > slot.y + slot.height - marginY) continue
      var order = previewOrder.slice()
      var from = order.indexOf(draggedKey)
      var to = order.indexOf(key)
      if (from < 0 || to < 0) return
      order.splice(from, 1)
      order.splice(to, 0, draggedKey)
      previewOrder = order
      return
    }
  }
  function controlIcon(key) {
    if (key === "wifi") return wifiDevice ? (Networking.wifiEnabled ? "󰖩" : "󰖪") : "󰈀"
    if (key === "bluetooth") return btAdapter && btAdapter.enabled ? "󰂯" : "󰂲"
    if (key === "focus") return "󰍶"
    if (key === "game") return "󰊗"
    return "󰖔"
  }
  function controlTitle(key) { return key === "wifi" ? (wifiDevice ? "Wi-Fi" : "Ethernet") : host.controlCenterTitle(key) }
  function controlSubtitle(key) {
    if (key === "wifi") return wifiDevice
      ? (!Networking.wifiEnabled ? "Off" : wifiNetwork ? wifiNetwork.name : "Not connected")
      : (wiredDevice && wiredDevice.connected ? "Connected" : "Disconnected")
    if (key === "bluetooth") return !btAdapter ? "Unavailable" : !btAdapter.enabled ? "Off" : btConnected ? String(btConnected.name || "Connected") : "On"
    if (key === "focus") return dnd ? "On" : "Off"
    if (key === "game") return gameMode ? "On" : "Off"
    return nightOn ? "On" : "Off"
  }
  function controlChecked(key) {
    if (key === "wifi") return wifiDevice ? Networking.wifiEnabled : !!(wiredDevice && wiredDevice.connected)
    if (key === "bluetooth") return !!(btAdapter && btAdapter.enabled)
    if (key === "focus") return dnd
    if (key === "game") return gameMode
    return nightOn
  }
  function controlAvailable(key) {
    if (key === "wifi") return wifiDevice ? Networking.wifiHardwareEnabled !== false : false
    if (key === "bluetooth") return !!btAdapter
    if (key === "focus") return !!notifications
    return true
  }
  function toggleControl(key) {
    if (key === "wifi" && wifiDevice) Networking.wifiEnabled = !Networking.wifiEnabled
    else if (key === "bluetooth" && btAdapter) btAdapter.enabled = !btAdapter.enabled
    else if (key === "focus" && notifications) notifications.setDoNotDisturb(!dnd)
    else if (key === "game") setGameMode(!gameMode)
    else if (key === "night" && nightlight) nightlight.setNightlight(!nightOn)
  }

  // --- Game Mode: Hyprland animations off (restored by a config reload) ---
  property bool gameMode: false
  Process {
    id: gameModeRead
    command: ["hyprctl", "getoption", "animations:enabled"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: cc.gameMode = /bool:\s*false/.test(String(text || ""))
    }
  }
  Process { id: gameModeWrite; onExited: gameModeRead.running = true }
  function setGameMode(on) {
    gameMode = on
    gameModeWrite.command = ["hyprctl", "eval", "hl.config({ animations = { enabled = " + (on ? "false" : "true") + " } })"]
    gameModeWrite.running = true
  }

  // --- Brightness (the Display card hides when the output has no control) ---
  property bool brightnessAvailable: false
  property int brightness: 0
  onActiveChanged: {
    if (!active) { outputsOpen = false; editMode = false; addPickerOpen = false; endDrag(); return }
    Qt.callLater(function() { cc.forceActiveFocus() })
    if (!brightnessRead.running) brightnessRead.running = true
    if (!gameModeRead.running) gameModeRead.running = true
  }
  Process {
    id: brightnessRead
    command: ["omarchy-brightness-display", "--monitor", cc.host.outputName]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = parseInt(String(text || "").trim(), 10)
        cc.brightnessAvailable = !isNaN(value)
        if (!isNaN(value)) cc.brightness = Math.max(0, Math.min(100, value))
      }
    }
    onExited: function(code) { if (code !== 0) cc.brightnessAvailable = false }
  }
  Process { id: brightnessWrite }
  Timer {
    id: brightnessDebounce
    interval: 120
    onTriggered: {
      if (brightnessWrite.running) { restart(); return }
      brightnessWrite.command = ["omarchy-brightness-display", "--no-osd", "--monitor", cc.host.outputName, cc.brightness + "%"]
      brightnessWrite.running = true
    }
  }

  spacing: 10

  // Esc closes the control center.
  Keys.onEscapePressed: {
    if (cc.editMode) { cc.editMode = false; cc.addPickerOpen = false; cc.endDrag() }
    else cc.host.view = "rest"
  }

  // ---------- Reusable pieces ----------

  // A switch row inside a grouped card.
  component CcTile: Rectangle {
    id: t
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool available: true
    // When set, the badge toggles and the rest of the tile opens details.
    property bool opens: false
    signal clicked()
    signal opened()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 72
    radius: 16
    color: tileMouse.containsMouse ? cc.tile : cc.card
    border.width: 1
    border.color: cc.edge
    opacity: available ? 1 : 0.5
    scale: tileMouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 120 * cc.host.motionScale; easing.type: Easing.OutCubic } }

    Rectangle {
      id: badge
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 42; height: 42; radius: 21
      color: t.checked ? cc.accent : cc.well
      Behavior on color { ColorAnimation { duration: cc.animDuration; easing.type: Easing.OutCubic } }
      Text {
        anchors.centerIn: parent
        text: t.icon
        color: t.checked ? cc.accentInk : cc.text
        font.family: cc.iconFont
        font.pixelSize: 19
      }
    }
    Column {
      anchors.left: badge.right
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      Text {
        width: parent.width
        text: t.title
        elide: Text.ElideRight
        color: cc.text
        font.family: "Adwaita Sans"
        font.pixelSize: 14
        font.weight: Font.DemiBold
        font.letterSpacing: -0.2
      }
      Text {
        width: parent.width
        visible: t.subtitle !== ""
        text: t.subtitle
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: cc.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: 12
      }
    }
    MouseArea {
      id: tileMouse
      anchors.fill: parent
      enabled: t.available
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: t.opens ? t.opened() : t.clicked()
    }
    MouseArea {
      visible: t.opens
      anchors.fill: badge
      enabled: t.available
      cursorShape: Qt.PointingHandCursor
      onClicked: t.clicked()
    }
  }

  // macOS Control Center slider: a capsule with a white fill that ends in a
  // round knob, and the icon inside on the left.
  component CcSlider: Item {
    id: s
    property string icon: ""
    property real value: 0
    signal moved(real value)
    readonly property real clamped: Math.max(0, Math.min(1, value))

    Layout.fillWidth: true
    Layout.preferredHeight: 38

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: sliderMouse.containsMouse ? cc.wellHover : cc.well
    }
    Rectangle {
      id: sliderFill
      height: parent.height
      radius: height / 2
      width: height + (parent.width - height) * s.clamped
      color: cc.text
      Behavior on width {
        enabled: !sliderMouse.pressed
        NumberAnimation { duration: 140 * cc.host.motionScale; easing.type: Easing.OutCubic }
      }
    }
    Rectangle {
      x: sliderFill.width - width
      width: parent.height
      height: parent.height
      radius: height / 2
      color: "#ffffff"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.14)
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      text: s.icon
      color: sliderFill.width - parent.height > x + width ? cc.host.colorBackground : cc.textMuted
      font.family: cc.iconFont
      font.pixelSize: 18
    }
    MouseArea {
      id: sliderMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      function apply(x) { s.moved(Math.max(0, Math.min(1, (x - height / 2) / (width - height)))) }
      onPressed: function(e) { apply(e.x) }
      onPositionChanged: function(e) { if (pressed) apply(e.x) }
      onWheel: function(e) { s.moved(Math.max(0, Math.min(1, s.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
  }

  // Section card with a title row (and an optional › button) over content.
  component CcSection: Rectangle {
    id: sec
    property string title: ""
    property string detail: ""
    property bool showChevron: false
    property bool chevronOpen: false
    signal chevronClicked()
    default property alias content: body.data

    Layout.fillWidth: true
    Layout.preferredHeight: body.implicitHeight + 54
    radius: 16
    color: cc.card
    border.width: 1
    border.color: cc.edge

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.top: parent.top
      anchors.topMargin: 14
      text: sec.title
      color: cc.text
      font.family: "Adwaita Sans"
      font.pixelSize: 14
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: sec.showChevron ? 44 : 16
      anchors.top: parent.top
      anchors.topMargin: 15
      text: sec.detail
      color: cc.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }
    Rectangle {
      id: chevron
      visible: sec.showChevron
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.top: parent.top
      anchors.topMargin: 10
      width: 24; height: 24; radius: 12
      color: chevronMouse.containsMouse ? cc.wellHover : cc.well
      Text {
        anchors.centerIn: parent
        text: "󰅂"
        rotation: sec.chevronOpen ? 90 : 0
        color: cc.textMuted
        font.family: cc.iconFont
        font.pixelSize: 15
        Behavior on rotation { NumberAnimation { duration: cc.animDuration; easing.type: Easing.OutCubic } }
      }
      MouseArea { id: chevronMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.chevronClicked() }
    }
    ColumnLayout {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: 42
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 6
    }
  }

  // ---------- Header and grouped controls ----------

  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    Text {
      text: "Control Center"
      color: cc.text
      font.family: "Adwaita Sans"
      font.pixelSize: 17
      font.weight: Font.DemiBold
    }
    Item { Layout.fillWidth: true }
    // Battery and power profile; clicking cycles the profile.
    Rectangle {
      visible: cc.hasBattery
      Layout.preferredWidth: batteryRow.implicitWidth + 24
      Layout.preferredHeight: 32
      radius: 16
      color: batteryMouse.containsMouse ? cc.well : cc.card
      Row {
        id: batteryRow
        anchors.centerIn: parent
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: cc.batteryIcon
          color: cc.charging ? cc.accent : cc.text
          font.family: cc.iconFont
          font.pixelSize: 16
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: cc.batteryPercent + "% · " + ({ "power-saver": "Saver", balanced: "Balanced", performance: "Performance" })[cc.profileName]
          color: cc.text
          font.family: "Adwaita Sans"
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }
      }
      MouseArea {
        id: batteryMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cc.cycleProfile()
      }
    }
    Rectangle {
      Layout.preferredWidth: cc.editMode ? 64 : 32
      Layout.preferredHeight: 32
      radius: 16
      color: editMouse.containsMouse || cc.editMode ? cc.well : cc.card
      Text {
        anchors.centerIn: parent
        text: cc.editMode ? "Done" : "󰏫"
        color: cc.text
        font.family: cc.editMode ? "Adwaita Sans" : cc.iconFont
        font.pixelSize: cc.editMode ? 12 : 17
        font.weight: Font.DemiBold
      }
      MouseArea {
        id: editMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { cc.editMode = !cc.editMode; cc.addPickerOpen = false; cc.endDrag(); cc.outputsOpen = false }
      }
    }
    Rectangle {
      Layout.preferredWidth: 32
      Layout.preferredHeight: 32
      radius: 16
      color: settingsMouse.containsMouse ? cc.well : cc.card
      Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: cc.text
        font.family: cc.iconFont
        font.pixelSize: 17
      }
      MouseArea {
        id: settingsMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cc.host.view = "settings"
      }
    }
  }

  ColumnLayout {
    visible: cc.editMode && cc.hiddenControlKeys.length > 0
    Layout.fillWidth: true
    spacing: 6
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 28
      radius: 7
      color: addMouse.containsMouse ? cc.wellHover : cc.well
      Text {
        anchors.centerIn: parent
        text: cc.addPickerOpen ? "Hide Add Controls" : "Add Controls…"
        color: cc.text
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.weight: Font.DemiBold
      }
      MouseArea {
        id: addMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cc.addPickerOpen = !cc.addPickerOpen
      }
    }
    Repeater {
      model: cc.addPickerOpen ? cc.hiddenControlKeys : []
      delegate: Rectangle {
        required property string modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 10
        color: addItemMouse.containsMouse ? cc.tile : cc.card
        border.width: 1
        border.color: cc.edge
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "+  " + cc.host.controlCenterTitle(modelData)
          color: cc.text
          font.family: "Adwaita Sans"
          font.pixelSize: 12
        }
        MouseArea {
          id: addItemMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: cc.host.setControlCenterShown(modelData, true)
        }
      }
    }
  }

  Item {
    id: cardArea
    Layout.fillWidth: true
    Layout.preferredHeight: positions.height
    readonly property var positions: {
      var result = {}
      var gap = 10
      var halfWidth = (width - gap) / 2
      var rowY = 0
      var halfUsed = false
      for (var i = 0; i < cc.visibleControlKeys.length; i++) {
        var key = cc.visibleControlKeys[i]
        var wide = key === "sound" || key === "display"
        var cardHeight = key === "sound" ? 100 + (cc.outputsOpen && !cc.editMode ? cc.outputs.length * 40 : 0) : wide ? 100 : 74
        if (wide) {
          if (halfUsed) { rowY += 74 + gap; halfUsed = false }
          result[key] = { x: 0, y: rowY, width: width, height: cardHeight }
          rowY += cardHeight + gap
        } else {
          result[key] = { x: halfUsed ? halfWidth + gap : 0, y: rowY, width: halfWidth, height: 74 }
          if (halfUsed) { rowY += 74 + gap; halfUsed = false }
          else halfUsed = true
        }
      }
      result.height = Math.max(0, rowY + (halfUsed ? 74 : -gap))
      return result
    }
    Repeater {
      model: ["wifi", "bluetooth", "focus", "game", "night", "sound", "display"]
      delegate: Item {
        id: controlCard
        required property string modelData
        readonly property var slot: cardArea.positions[modelData] || null
        visible: !!slot
        x: slot ? slot.x : 0
        y: slot ? slot.y : 0
        width: slot ? slot.width : 0
        height: slot ? slot.height : 0
        opacity: cc.draggedKey === modelData ? 0.25 : 1
        Behavior on x { enabled: cc.editMode; NumberAnimation { duration: 190 * cc.host.motionScale; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: cc.editMode; NumberAnimation { duration: 190 * cc.host.motionScale; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 * cc.host.motionScale } }

        Loader {
          anchors.fill: parent
          property string controlKey: controlCard.modelData
          sourceComponent: controlCard.modelData === "sound" ? soundCard
            : controlCard.modelData === "display" ? displayCard : quickCard
        }
        MouseArea {
          id: editDragMouse
          anchors.fill: parent
          visible: cc.editMode
          enabled: cc.editMode
          cursorShape: Qt.OpenHandCursor
          property real pressX: 0
          property real pressY: 0
          onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            if (cc.draggedKey === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
            if (cc.draggedKey === "") {
              cc.previewOrder = cc.host.controlCenterKeys.slice()
              cc.draggedKey = controlCard.modelData
              dragProxy.width = controlCard.width
              dragProxy.height = controlCard.height
            }
            var point = editDragMouse.mapToItem(dragLayer, mouse.x, mouse.y)
            dragProxy.x = point.x - dragProxy.width / 2
            dragProxy.y = point.y - dragProxy.height / 2
            point = editDragMouse.mapToItem(cardArea, mouse.x, mouse.y)
            cc.previewMoveAt(point.x, point.y)
          }
          onReleased: {
            if (cc.draggedKey === controlCard.modelData) cc.host.settings.controlCenterOrder = cc.previewOrder.join(",")
            cc.endDrag()
          }
          onCanceled: { cc.previewOrder = cc.host.controlCenterKeys.slice(); cc.endDrag() }
        }
        Rectangle {
          visible: cc.editMode
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.leftMargin: -4
          anchors.topMargin: -4
          z: 2
          width: 24; height: 24; radius: 12
          color: cc.wellHover
          border.width: 1
          border.color: cc.edge
          Text { anchors.centerIn: parent; text: "−"; color: cc.text; font.pixelSize: 18 }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { cc.host.setControlCenterShown(controlCard.modelData, false); cc.endDrag() }
          }
        }
      }
    }
  }

  Rectangle {
    visible: cc.visibleControlKeys.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 74
    radius: 16
    color: cc.card
    border.width: 1
    border.color: cc.edge
    Text {
      anchors.centerIn: parent
      text: cc.editMode ? "Use Add Controls to restore a card" : "Click the pencil to add controls"
      color: cc.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }
  }

  Item {
    id: dragLayer
    parent: cc.parent
    anchors.fill: cc
    z: 100
    Rectangle {
      id: dragProxy
      visible: cc.draggedKey !== ""
      radius: 16
      color: cc.card
      border.width: 1
      border.color: cc.accent
      opacity: 0.96
      scale: 1.04
      Loader {
        anchors.fill: parent
        enabled: false
        property string controlKey: cc.draggedKey
        sourceComponent: cc.draggedKey === "sound" ? soundCard
          : cc.draggedKey === "display" ? displayCard : quickCard
      }
    }
  }

  Component {
    id: quickCard
    CcTile {
      anchors.fill: parent
      icon: cc.controlIcon(parent.controlKey)
      title: cc.controlTitle(parent.controlKey)
      subtitle: cc.controlSubtitle(parent.controlKey)
      checked: cc.controlChecked(parent.controlKey)
      available: cc.controlAvailable(parent.controlKey)
      opens: parent.controlKey === "bluetooth"
      onClicked: cc.toggleControl(parent.controlKey)
      onOpened: cc.host.view = parent.controlKey
    }
  }

  // ---------- Sound / Display ----------

  Component {
    id: soundCard
    CcSection {
    anchors.fill: parent
    title: "Sound"
    detail: !cc.controlPresent("sound") ? "Unavailable" : cc.muted ? "Muted" : Math.round(cc.volume * 100) + "%"
    showChevron: !cc.editMode && cc.outputs.length > 1
    chevronOpen: cc.outputsOpen
    onChevronClicked: cc.outputsOpen = !cc.outputsOpen

    CcSlider {
      visible: cc.controlPresent("sound")
      icon: cc.muted || cc.volume <= 0 ? "󰖁" : cc.volume < 0.34 ? "󰕿" : cc.volume < 0.67 ? "󰖀" : "󰕾"
      value: cc.muted ? 0 : cc.volume
      onMoved: function(v) {
        cc.sink.audio.volume = v
        if (cc.sink.audio.muted && v > 0) cc.sink.audio.muted = false
      }
    }
    // Output picker, revealed by the › button.
    Repeater {
      model: cc.outputsOpen && !cc.editMode ? cc.outputs : []
      delegate: Rectangle {
        id: outputRow
        required property var modelData
        readonly property bool isDefault: modelData === cc.sink
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 7
        color: outputMouse.containsMouse ? cc.host.withAlpha(cc.text, 0.08) : "transparent"
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.right: outputCheck.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: String(outputRow.modelData.description || outputRow.modelData.nickname || outputRow.modelData.name || "")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: outputRow.isDefault ? cc.text : cc.textMuted
          font.family: "Adwaita Sans"
          font.pixelSize: 12
        }
        Text {
          id: outputCheck
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          visible: outputRow.isDefault
          text: "󰄬"
          color: cc.accent
          font.family: cc.iconFont
          font.pixelSize: 14
        }
        MouseArea {
          id: outputMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Pipewire.preferredDefaultAudioSink = outputRow.modelData
        }
      }
    }
    Text {
      visible: !cc.controlPresent("sound")
      text: "No audio output available"
      color: cc.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
      Layout.fillWidth: true
    }
    }
  }

  Component {
    id: displayCard
    CcSection {
    anchors.fill: parent
    title: "Display"
    detail: cc.brightnessAvailable ? cc.brightness + "%" : "Unavailable"
    CcSlider {
      visible: cc.brightnessAvailable
      icon: "󰃠"
      value: cc.brightness / 100
      onMoved: function(v) {
        cc.brightness = Math.round(v * 100)
        brightnessDebounce.restart()
      }
    }
    Text {
      visible: !cc.brightnessAvailable
      text: "No brightness control available"
      color: cc.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
      Layout.fillWidth: true
    }
    }
  }


  // ---------- Notifications ----------

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: notificationBody.implicitHeight + 20
    radius: 16
    color: cc.card
    border.width: 1
    border.color: cc.edge

    ColumnLayout {
      id: notificationBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 10
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Layout.topMargin: 2
        Text {
          text: "Notifications"
          color: cc.text
          font.family: "Adwaita Sans"
          font.pixelSize: 14
          font.weight: Font.DemiBold
          font.letterSpacing: -0.2
        }
        Item { Layout.fillWidth: true }
        // macOS push button.
        Rectangle {
          visible: cc.host.history.length > 0
          implicitWidth: clearLabel.implicitWidth + 20
          implicitHeight: 22
          radius: 6
          color: clearMouse.containsMouse ? cc.wellHover : cc.well
          Behavior on color { ColorAnimation { duration: cc.animDuration } }
          Text {
            id: clearLabel
            anchors.centerIn: parent
            text: "Clear All"
            color: cc.text
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.Medium
          }
          MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cc.host.clearAllNotifications()
          }
        }
      }

      Text {
        visible: cc.host.history.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 8
        horizontalAlignment: Text.AlignHCenter
        text: "No notifications"
        color: cc.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: 12
      }

      ListView {
        visible: cc.host.history.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 240)
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: cc.host.history
        delegate: Rectangle {
          id: note
          required property var modelData
          readonly property string appName: String(modelData.app || modelData.summary || "?")
          width: ListView.view.width
          height: noteBody.implicitHeight + 22
          radius: 14
          color: noteMouse.containsMouse && modelData.isActive ? cc.wellHover : cc.tile

          MouseArea {
            id: noteMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !!note.modelData.isActive
            onClicked: cc.host.notificationCommand("invokeKey", note.modelData)
          }
          // The notification's image or app icon; a letter avatar when
          // there's none (or it fails to load).
          ClippingRectangle {
            id: avatar
            // A live image handle dies with the shell; fall back to the app
            // icon (then the letter) when it no longer loads.
            property bool imageFailed: false
            readonly property string source: cc.host.notificationIconSource(note.modelData, imageFailed)
            readonly property var brand: cc.host.notificationBrand(note.modelData)
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 12
            width: 32; height: 32; radius: 8
            color: brand ? brand.tile
              : noteIcon.status === Image.Ready ? "transparent" : cc.host.withAlpha(cc.accent, 0.18)
            Image {
              id: noteIcon
              anchors.fill: parent
              source: avatar.source
              sourceSize.width: 60
              sourceSize.height: 60
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              visible: status === Image.Ready
              onStatusChanged: if (status === Image.Error) avatar.imageFailed = true
            }
            Text {
              anchors.centerIn: parent
              visible: noteIcon.status !== Image.Ready
              text: avatar.brand ? avatar.brand.glyph : note.appName.charAt(0).toUpperCase()
              color: avatar.brand ? avatar.brand.ink : cc.accent
              font.family: avatar.brand ? "JetBrainsMono Nerd Font" : "Adwaita Sans"
              font.pixelSize: avatar.brand ? 20 : 14
              font.weight: Font.DemiBold
            }
          }
          Column {
            id: noteBody
            anchors.left: avatar.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.top: parent.top
            anchors.topMargin: 12
            spacing: 2
            // Like iOS's Notification Center: the title with the time on the
            // same line (the icon already says which app).
            Item {
              width: parent.width
              height: noteTitle.height
              Text {
                id: noteTitle
                anchors.left: parent.left
                anchors.right: noteAge.left
                anchors.rightMargin: 8
                text: cc.host.notificationTitle(note.modelData)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: cc.text
                font.family: "Adwaita Sans"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: -0.2
              }
              Text {
                id: noteAge
                anchors.right: parent.right
                anchors.baseline: noteTitle.baseline
                text: cc.host.notificationAge(note.modelData.timestamp)
                textFormat: Text.PlainText
                color: cc.textMuted
                font.family: "Adwaita Sans"
                font.pixelSize: 12
              }
            }
            Text {
              width: parent.width
              text: String(note.modelData.body || "")
              visible: text !== ""
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
              color: cc.host.withAlpha(cc.text, 0.72)
              font.family: "Adwaita Sans"
              font.pixelSize: 13
            }
          }
          Text {
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.top: parent.top
            anchors.topMargin: 12
            text: "󰅖"
            color: closeMouse.containsMouse ? cc.text : cc.textMuted
            font.family: cc.iconFont
            font.pixelSize: 13
            MouseArea { id: closeMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: cc.host.dismissNotification(note.modelData) }
          }
        }
      }
    }
  }
}
