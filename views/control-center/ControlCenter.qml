import QtQuick
import QtQuick.Layouts
import "../../components"
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
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
  readonly property int animDuration: 180 * host.theme.motionScale
  property bool editMode: false
  property string draggedKey: ""
  property bool dragFromGallery: false
  property bool dropActive: false
  property bool removeDropActive: false
  property point dragPoint: Qt.point(0, 0)
  property var previewOrder: []
  onEditModeChanged: {
    endDrag()
    previewOrder = host.controlCenterKeys.slice()
    outputsOpen = false
    inputsOpen = false
    controlLayoutScroll.contentY = 0
    if (editMode) controlGallery.resetScroll()
    cc.forceActiveFocus()
  }

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
  readonly property var microphoneSource: Pipewire.defaultAudioSource
  readonly property bool microphoneReady: !!(microphoneSource && microphoneSource.ready && microphoneSource.audio)
  readonly property bool microphoneMuted: !!(microphoneSource && microphoneSource.audio && microphoneSource.audio.muted)
  readonly property real microphoneVolume: microphoneSource && microphoneSource.audio ? microphoneSource.audio.volume : 0
  readonly property var inputs: {
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    return nodes.filter(function(n) { return n && !n.isSink && !n.isStream && n.audio })
  }
  property bool inputsOpen: false
  PwObjectTracker { objects: [cc.microphoneSource] }
  function toggleMicrophoneMute() {
    if (microphoneReady) microphoneSource.audio.muted = !microphoneMuted
  }

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
  readonly property var profileLabels: ({ "power-saver": "Power Saver", balanced: "Balanced", performance: "Performance" })
  readonly property var profileIcons: ({ "power-saver": "󰾆", balanced: "󰾅", performance: "󰓅" })
  // Through Omarchy so the choice is remembered per AC/battery, as in its menu.
  function cycleProfile() {
    var usable = PowerProfiles.hasPerformanceProfile ? profileNames : profileNames.slice(0, 2)
    var next = usable[(usable.indexOf(profileName) + 1) % usable.length]
    Quickshell.execDetached(["omarchy-powerprofiles-set", "autodetect", next])
  }

  // --- Keyboard layout: the main keyboard's, from Hyprland ---
  property string keyboardLayout: ""
  property int keyboardLayoutCount: 1
  readonly property string keyboardLabel: keyboardLayout || "Unknown"
  Process {
    id: keyboardRead
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var boards = JSON.parse(text).keyboards || []
          var main = boards.filter(function(k) { return k.main })[0] || boards[0]
          if (!main) return
          cc.keyboardLayout = String(main.active_keymap || "")
          cc.keyboardLayoutCount = String(main.layout || "").split(",").filter(function(l) { return l !== "" }).length || 1
        } catch (e) {}
      }
    }
  }
  // "activelayout>>keyboard,layout" arrives whenever any keyboard switches.
  Connections {
    target: Hyprland
    function onRawEvent(event) { if (event.name === "activelayout" && !keyboardRead.running) keyboardRead.running = true }
  }
  Process { id: keyboardSwitch; command: ["hyprctl", "switchxkblayout", "all", "next"] }
  function nextKeyboardLayout() {
    if (keyboardLayoutCount > 1) keyboardSwitch.running = true
  }

  // --- Shell services ---
  readonly property var notifications: host.shell ? host.shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var nightlight: host.shell ? host.shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property bool dnd: notifications ? !!notifications.doNotDisturb : false
  readonly property bool nightOn: nightlight ? !!nightlight.enabled : false
  readonly property var visibleControlKeys: {
    var order = cc.editMode && cc.previewOrder.length ? cc.previewOrder : host.controlCenterKeys
    return order.filter(function(key) {
      return (host.controlCenterIsShown(key) || (cc.dragFromGallery && cc.dropActive && key === cc.draggedKey))
        && (!cc.isMicrophoneControl(key) || cc.controlPresent(key))
        && (cc.editMode || cc.controlPresent(key))
    })
  }
  function controlPresent(key) {
    if (key === "night") return !!nightlight
    if (isMicrophoneControl(key)) return !!(microphoneSource && microphoneSource.audio)
    if (key === "sound") return !!(sink && sink.audio)
    if (key === "display") return brightnessAvailable
    return true
  }
  function isMicrophoneControl(key) { return key === "microphone" || key === "microphoneMute" }
  function controlWide(key) { return key === "sound" || key === "microphone" || key === "display" }
  function controlComponent(key) {
    if (key === "sound") return soundCard
    if (key === "microphone") return microphoneCard
    if (key === "display") return displayCard
    return quickCard
  }
  function endDrag() {
    draggedKey = ""
    dragFromGallery = false
    dropActive = false
    removeDropActive = false
    previewOrder = host.controlCenterKeys.slice()
  }
  function beginDrag(key, fromGallery, width, height) {
    previewOrder = host.controlCenterKeys.slice()
    dragFromGallery = fromGallery
    draggedKey = key
    dragProxy.width = width
    dragProxy.height = height
  }
  function moveDrag(source, x, y) {
    var point = source.mapToItem(dragLayer, x, y)
    dragProxy.x = point.x - dragProxy.width / 2
    dragProxy.y = point.y - dragProxy.height / 2
    dragPoint = source.mapToItem(controlLayoutScroll, x, y)
    var galleryPoint = source.mapToItem(controlGallery, x, y)
    removeDropActive = !dragFromGallery && controlGallery.visible
      && galleryPoint.x >= 0 && galleryPoint.x <= controlGallery.width
      && galleryPoint.y >= 0 && galleryPoint.y <= controlGallery.height
    updateDropPosition()
  }
  function updateDropPosition() {
    dropActive = !removeDropActive && dragPoint.x >= 0 && dragPoint.x <= controlLayoutScroll.width
      && dragPoint.y >= 0 && dragPoint.y <= controlLayoutScroll.height
    if (!dropActive) return
    var y = dragPoint.y + controlLayoutScroll.contentY
    if (dragFromGallery) previewInsertAt(dragPoint.x, y)
    else previewMoveAt(dragPoint.x, y)
  }
  function previewInsertAt(x, y) {
    var slots = cardArea.positions
    var own = slots[draggedKey]
    // Keep the insertion stable while the pointer is over its placeholder.
    if (own && x >= own.x && x <= own.x + own.width && y >= own.y && y <= own.y + own.height) return
    var keys = visibleControlKeys.filter(function(key) { return key !== cc.draggedKey })
    var target = ""
    for (var i = 0; i < keys.length; i++) {
      var slot = slots[keys[i]]
      if (!slot) continue
      var wide = controlWide(keys[i])
      if (y < slot.y || (y < slot.y + slot.height && (wide
          ? y < slot.y + slot.height / 2 : x < slot.x + slot.width / 2))) {
        target = keys[i]
        break
      }
    }
    var order = previewOrder.filter(function(key) { return key !== cc.draggedKey })
    var index = target ? order.indexOf(target) : keys.length ? order.indexOf(keys[keys.length - 1]) + 1 : order.length
    order.splice(index, 0, draggedKey)
    previewOrder = order
  }
  function finishDrag() {
    if (draggedKey !== "" && removeDropActive) {
      host.setControlCenterShown(draggedKey, false)
    } else if (draggedKey !== "" && dropActive) {
      host.settings.controlCenterOrder = previewOrder.join(",")
      if (dragFromGallery) host.setControlCenterShown(draggedKey, true)
    }
    endDrag()
  }
  Timer {
    interval: 25
    repeat: true
    running: cc.draggedKey !== "" && cc.dropActive
    onTriggered: {
      var step = cc.dragPoint.y < 32 ? -8 : cc.dragPoint.y > controlLayoutScroll.height - 32 ? 8 : 0
      var limit = Math.max(0, controlLayoutScroll.contentHeight - controlLayoutScroll.height)
      var next = Math.max(0, Math.min(limit, controlLayoutScroll.contentY + step))
      if (next !== controlLayoutScroll.contentY) {
        controlLayoutScroll.contentY = next
        cc.updateDropPosition()
      }
    }
  }
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
    if (key === "microphoneMute") return microphoneMuted ? "󰍭" : "󰍬"
    if (key === "wifi") return wifiDevice ? (Networking.wifiEnabled ? "\uf1eb" : "󰖪") : "󰈀"
    if (key === "bluetooth") return btAdapter && btAdapter.enabled ? "󰂯" : "󰂲"
    if (key === "focus") return "󰍶"
    if (key === "game") return "󰊗"
    if (key === "power") return profileIcons[profileName] || "󰾅"
    if (key === "keyboard") return "󰌌"
    return "󰖔"
  }
  function controlTitle(key) { return key === "wifi" ? (wifiDevice ? "Wi-Fi" : "Ethernet") : host.controlCenterTitle(key) }
  function controlSubtitle(key) {
    if (key === "microphoneMute") return microphoneMuted ? "Muted" : "Unmuted"
    if (key === "wifi") return wifiDevice
      ? (!Networking.wifiEnabled ? "Off" : wifiNetwork ? wifiNetwork.name : "Not connected")
      : (wiredDevice && wiredDevice.connected ? "Connected" : "Disconnected")
    if (key === "bluetooth") return !btAdapter ? "Unavailable" : !btAdapter.enabled ? "Off" : btConnected ? String(btConnected.name || "Connected") : "On"
    if (key === "focus") return dnd ? "On" : "Off"
    if (key === "game") return gameMode ? "On" : "Off"
    if (key === "power") return profileLabels[profileName] || "Balanced"
    if (key === "keyboard") return keyboardLabel
    return nightOn ? "On" : "Off"
  }
  function controlChecked(key) {
    if (key === "microphoneMute") return microphoneMuted
    if (key === "wifi") return wifiDevice ? Networking.wifiEnabled : !!(wiredDevice && wiredDevice.connected)
    if (key === "bluetooth") return !!(btAdapter && btAdapter.enabled)
    if (key === "focus") return dnd
    if (key === "game") return gameMode
    if (key === "power") return profileName !== "balanced"
    if (key === "keyboard") return false
    return nightOn
  }
  function controlAvailable(key) {
    if (key === "microphoneMute") return microphoneReady
    if (key === "wifi") return wifiDevice ? Networking.wifiHardwareEnabled !== false : false
    if (key === "bluetooth") return !!btAdapter
    if (key === "focus") return !!notifications
    return true
  }
  function toggleControl(key) {
    if (key === "microphoneMute") { toggleMicrophoneMute(); return }
    if (key === "wifi" && wifiDevice) Networking.wifiEnabled = !Networking.wifiEnabled
    else if (key === "bluetooth" && btAdapter) btAdapter.enabled = !btAdapter.enabled
    else if (key === "focus" && notifications) notifications.setDoNotDisturb(!dnd)
    else if (key === "game") setGameMode(!gameMode)
    else if (key === "power") cycleProfile()
    else if (key === "keyboard") nextKeyboardLayout()
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
    if (!active) { outputsOpen = false; inputsOpen = false; editMode = false; endDrag(); return }
    Qt.callLater(function() { cc.forceActiveFocus() })
    if (!brightnessRead.running) brightnessRead.running = true
    if (!gameModeRead.running) gameModeRead.running = true
    if (!keyboardRead.running) keyboardRead.running = true
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
    if (cc.editMode) { cc.editMode = false; cc.endDrag() }
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
    Behavior on scale { NumberAnimation { duration: 120 * cc.host.theme.motionScale; easing.type: Easing.OutCubic } }

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
        NumberAnimation { duration: 140 * cc.host.theme.motionScale; easing.type: Easing.OutCubic }
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
      color: sliderFill.width - parent.height > x + width ? cc.host.theme.background : cc.textMuted
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
    property string chevronLabel: "Sound Output"
    property string chevronHideLabel: "Hide Outputs"
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
      Tooltip { text: sec.chevronOpen ? sec.chevronHideLabel : sec.chevronLabel }
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
    Rectangle {
      Layout.preferredWidth: cc.editMode ? 64 : 32
      Layout.preferredHeight: 32
      radius: 16
      color: editMouse.containsMouse || cc.editMode ? cc.well : cc.card
      Tooltip { text: cc.editMode ? "" : "Edit Controls" }
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
        onClicked: cc.editMode = !cc.editMode
      }
    }
    Rectangle {
      Layout.preferredWidth: 32
      Layout.preferredHeight: 32
      radius: 16
      color: settingsMouse.containsMouse ? cc.well : cc.card
      Tooltip { text: "Island Settings" }
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
    // Battery, as macOS's menu bar shows it: the percentage, then a battery
    // filled to the level (green while charging, red when low), with a bolt
    // while charging.
    Row {
      visible: cc.hasBattery
      Layout.leftMargin: 6
      Layout.rightMargin: 6
      spacing: 6
      readonly property bool low: cc.batteryPercent <= 20 && !cc.charging
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: cc.batteryPercent + "%"
        color: parent.low ? "#ff453a" : cc.text
        font.family: "Adwaita Sans"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
      }
      BatteryIcon {
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 14
        level: cc.batteryPercent
        charging: cc.charging
        low: parent.low
        color: cc.text
      }
    }
  }

  Flickable {
    id: controlLayoutScroll
    Layout.fillWidth: true
    Layout.preferredHeight: cc.editMode ? 300 : cardArea.positions.height
    contentWidth: width
    contentHeight: cardArea.height
    interactive: cc.editMode
    clip: cc.editMode
    boundsBehavior: Flickable.StopAtBounds
    Text {
      parent: controlLayoutScroll
      anchors.centerIn: parent
      visible: cc.editMode && cc.visibleControlKeys.length === 0
      text: "Drag a control here"
      color: cc.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
    Item {
      id: cardArea
      width: controlLayoutScroll.width
      height: positions.height
      readonly property var positions: {
        var result = {}
        var gap = 10
        var halfWidth = (width - gap) / 2
        var rowY = 0
        var halfUsed = false
        for (var i = 0; i < cc.visibleControlKeys.length; i++) {
          var key = cc.visibleControlKeys[i]
          var wide = cc.controlWide(key)
          var cardHeight = wide ? 100 : 74
          if (key === "sound" && cc.outputsOpen && !cc.editMode) cardHeight += cc.outputs.length * 40
          if (key === "microphone" && cc.inputsOpen && !cc.editMode) cardHeight += cc.inputs.length * 40
          if (wide) {
            if (halfUsed) { rowY += 74 + gap; halfUsed = false }
            result[key] = { x: 0, y: rowY, width: width, height: cardHeight }
            rowY += cardHeight + gap
          } else if (halfUsed) {
            result[key] = { x: halfWidth + gap, y: rowY, width: halfWidth, height: 74 }
            rowY += 74 + gap
            halfUsed = false
          } else {
            var nextKey = i + 1 < cc.visibleControlKeys.length ? cc.visibleControlKeys[i + 1] : ""
            var nextIsSmall = nextKey !== "" && !cc.controlWide(nextKey)
            result[key] = { x: 0, y: rowY, width: nextIsSmall ? halfWidth : width, height: 74 }
            if (nextIsSmall) halfUsed = true
            else rowY += 74 + gap
          }
        }
        result.height = Math.max(0, rowY + (halfUsed ? 74 : -gap))
        return result
      }
      Repeater {
        model: ["wifi", "bluetooth", "focus", "game", "night", "power", "keyboard", "sound", "microphone", "microphoneMute", "display"]
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
          Behavior on x { enabled: cc.editMode; NumberAnimation { duration: 190 * cc.host.theme.motionScale; easing.type: Easing.OutCubic } }
          Behavior on y { enabled: cc.editMode; NumberAnimation { duration: 190 * cc.host.theme.motionScale; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 120 * cc.host.theme.motionScale } }

          Loader {
            anchors.fill: parent
            property string controlKey: controlCard.modelData
            property bool galleryPreview: false
            sourceComponent: cc.controlComponent(controlCard.modelData)
          }
          MouseArea {
            id: editDragMouse
            anchors.fill: parent
            visible: cc.editMode
            enabled: cc.editMode
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            property real pressX: 0
            property real pressY: 0
            onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
            onPositionChanged: function(mouse) {
              if (!pressed) return
              if (cc.draggedKey === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
              if (cc.draggedKey === "") cc.beginDrag(controlCard.modelData, false, controlCard.width, controlCard.height)
              cc.moveDrag(editDragMouse, mouse.x, mouse.y)
            }
            onReleased: function(mouse) {
              if (cc.draggedKey !== "") {
                cc.moveDrag(editDragMouse, mouse.x, mouse.y)
                cc.finishDrag()
              }
            }
            onCanceled: cc.endDrag()
          }
          Rectangle {
            visible: cc.editMode
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 0
            anchors.topMargin: 0
            z: 2
            width: 24; height: 24; radius: 12
            color: cc.wellHover
            border.width: 1
            border.color: cc.edge
            Text { anchors.centerIn: parent; text: "−"; color: cc.text; font.pixelSize: 18 }
            Tooltip { text: "Remove" }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { cc.host.setControlCenterShown(controlCard.modelData, false); cc.endDrag() }
            }
          }
        }
      }
    }
  }

  Rectangle {
    visible: !cc.editMode && cc.visibleControlKeys.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 74
    radius: 16
    color: cc.card
    border.width: 1
    border.color: cc.edge
    Text {
      anchors.centerIn: parent
      text: "Click the pencil to add controls"
      color: cc.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
    }
  }

  ControlGallery {
    id: controlGallery
    visible: cc.editMode
    Layout.fillWidth: true
    controlCenter: cc
    quickControl: quickCard
    soundControl: soundCard
    microphoneControl: microphoneCard
    displayControl: displayCard
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
        property bool galleryPreview: cc.dragFromGallery
        sourceComponent: cc.controlComponent(cc.draggedKey)
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
      available: parent.galleryPreview || cc.controlAvailable(parent.controlKey)
      opens: (parent.controlKey === "bluetooth" && !!cc.btAdapter) || (parent.controlKey === "wifi" && !!cc.wifiDevice)
      onClicked: cc.toggleControl(parent.controlKey)
      onOpened: cc.host.view = parent.controlKey
    }
  }

  // ---------- Sound / Display ----------

  Component {
    id: soundCard
    CcSection {
    readonly property bool galleryPreview: parent.galleryPreview
    anchors.fill: parent
    title: "Sound"
    detail: !cc.controlPresent("sound") ? "Unavailable" : cc.muted ? "Muted" : Math.round(cc.volume * 100) + "%"
    showChevron: !galleryPreview && !cc.editMode && cc.outputs.length > 1
    chevronOpen: cc.outputsOpen
    onChevronClicked: { cc.outputsOpen = !cc.outputsOpen; cc.inputsOpen = false }

    CcSlider {
      visible: galleryPreview || cc.controlPresent("sound")
      icon: cc.muted || cc.volume <= 0 ? "󰖁" : cc.volume < 0.34 ? "󰕿" : cc.volume < 0.67 ? "󰖀" : "󰕾"
      value: cc.muted ? 0 : cc.volume
      onMoved: function(v) {
        cc.sink.audio.volume = v
        if (cc.sink.audio.muted && v > 0) cc.sink.audio.muted = false
      }
    }
    // Output picker, revealed by the › button.
    Repeater {
      model: !galleryPreview && cc.outputsOpen && !cc.editMode ? cc.outputs : []
      delegate: Rectangle {
        id: outputRow
        required property var modelData
        readonly property bool isDefault: modelData === cc.sink
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 7
        color: outputMouse.containsMouse ? cc.host.theme.withAlpha(cc.text, 0.08) : "transparent"
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
      visible: !galleryPreview && !cc.controlPresent("sound")
      text: "No audio output available"
      color: cc.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 12
      Layout.fillWidth: true
    }
    }
  }

  Component {
    id: microphoneCard
    CcSection {
      readonly property bool galleryPreview: parent.galleryPreview
      anchors.fill: parent
      title: "Microphone"
      detail: !cc.controlPresent("microphone") ? "Unavailable" : cc.microphoneMuted ? "Muted" : Math.round(cc.microphoneVolume * 100) + "%"
      showChevron: !galleryPreview && !cc.editMode && cc.inputs.length > 1
      chevronOpen: cc.inputsOpen
      chevronLabel: "Microphone Input"
      chevronHideLabel: "Hide Inputs"
      onChevronClicked: { cc.inputsOpen = !cc.inputsOpen; cc.outputsOpen = false }

      CcSlider {
        enabled: cc.microphoneReady
        icon: "󰍬"
        value: cc.microphoneVolume
        onMoved: function(v) {
          if (cc.microphoneReady) cc.microphoneSource.audio.volume = v
        }
        Tooltip { text: "Microphone Input Volume" }
      }
      Repeater {
        model: !galleryPreview && cc.inputsOpen && !cc.editMode ? cc.inputs : []
        delegate: Rectangle {
          id: inputRow
          required property var modelData
          readonly property bool isDefault: modelData === cc.microphoneSource
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 7
          color: inputMouse.containsMouse ? cc.host.theme.withAlpha(cc.text, 0.08) : "transparent"
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: inputCheck.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: String(inputRow.modelData.description || inputRow.modelData.nickname || inputRow.modelData.name || "")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: inputRow.isDefault ? cc.text : cc.textMuted
            font.family: "Adwaita Sans"
            font.pixelSize: 12
          }
          Text {
            id: inputCheck
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: inputRow.isDefault
            text: "󰄬"
            color: cc.accent
            font.family: cc.iconFont
            font.pixelSize: 14
          }
          MouseArea {
            id: inputMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Pipewire.preferredDefaultAudioSource = inputRow.modelData
          }
        }
      }
    }
  }

  Component {
    id: displayCard
    CcSection {
    readonly property bool galleryPreview: parent.galleryPreview
    anchors.fill: parent
    title: "Display"
    detail: cc.brightnessAvailable ? cc.brightness + "%" : "Unavailable"
    CcSlider {
      visible: galleryPreview || cc.brightnessAvailable
      icon: "󰃠"
      value: cc.brightness / 100
      onMoved: function(v) {
        cc.brightness = Math.round(v * 100)
        brightnessDebounce.restart()
      }
    }
    Text {
      visible: !galleryPreview && !cc.brightnessAvailable
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
    visible: !cc.editMode
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
          visible: cc.host.notifications.history.length > 0
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
            onClicked: cc.host.notifications.clearAll()
          }
        }
      }

      Text {
        visible: cc.host.notifications.history.length === 0
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
        visible: cc.host.notifications.history.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 240)
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: cc.host.notifications.history
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
            onClicked: cc.host.notifications.command("invokeKey", note.modelData)
          }
          // The notification's image or app icon; a letter avatar when
          // there's none (or it fails to load).
          ClippingRectangle {
            id: avatar
            // A live image handle dies with the shell; fall back to the app
            // icon (then the letter) when it no longer loads.
            property bool imageFailed: false
            readonly property string source: cc.host.notifications.iconSource(note.modelData, imageFailed)
            readonly property var brand: cc.host.notifications.brand(note.modelData)
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 12
            width: 32; height: 32; radius: 8
            color: brand ? brand.tile
              : noteIcon.status === Image.Ready ? "transparent" : cc.host.theme.withAlpha(cc.accent, 0.18)
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
                text: cc.host.notifications.title(note.modelData)
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
                text: cc.host.notifications.age(note.modelData.timestamp)
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
              color: cc.host.theme.withAlpha(cc.text, 0.72)
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
            MouseArea { id: closeMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: cc.host.notifications.dismiss(note.modelData) }
            Tooltip { text: "Dismiss" }
          }
        }
      }
    }
  }
}
