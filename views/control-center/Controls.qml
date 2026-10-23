import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// What the control center's controls show and do: network, sound,
// microphone, Bluetooth, battery and power profile, keyboard layout, Focus,
// Night Shift, Game Mode, Stay Awake, Screensaver, Screenshot, Screen Recording,
// Dictate, reminders and brightness, plus which controls are shown and in
// what order (saved in the island's settings), enabled addons' tiles among
// them (see addons/Addon.qml). Nothing here is drawn.
Item {
  id: controls
  required property var host
  readonly property var settings: host.settings

  // --- Which controls, in what order ---

  readonly property var known: ["wifi", "bluetooth", "focus", "game", "night", "power", "keyboard", "sound", "microphone", "microphoneMute", "awake", "screensaver", "screenshot", "screenrecord", "dictate", "reminder", "display"]
    .concat(host.addons.tiles.map(function(tile) { return tile.key }))
  readonly property var keys: {
    var known = controls.known
    var saved = String(settings.controlCenterOrder || "").split(",")
    var result = []
    for (var i = 0; i < saved.length; i++)
      if (known.indexOf(saved[i]) !== -1 && result.indexOf(saved[i]) === -1) result.push(saved[i])
    for (var j = 0; j < known.length; j++)
      if (result.indexOf(known[j]) === -1) result.push(known[j])
    return result
  }
  // A disabled addon's tiles keep their place for when it's back.
  function saveOrder(order) {
    var saved = String(settings.controlCenterOrder || "").split(",").filter(function(key) { return key !== "" })
    var result = order.slice()
    for (var i = 0; i < saved.length; i++)
      if (result.indexOf(saved[i]) === -1) result.splice(Math.min(i, result.length), 0, saved[i])
    settings.controlCenterOrder = result.join(",")
  }
  function title(key) {
    var tile = host.addons.tileFor(key)
    if (tile) return String(tile.title || key)
    var names = { wifi: "Wi-Fi / Ethernet", bluetooth: "Bluetooth", focus: "Focus", game: "Game Mode", night: "Night Shift", power: "Power Mode", keyboard: "Keyboard", awake: "Stay Awake", screensaver: "Screensaver", screenshot: "Screenshot", screenrecord: "Screen Recording", dictate: "Dictate", reminder: "Set Reminder", sound: "Sound", microphone: "Microphone", microphoneMute: "Microphone", display: "Display" }
    return names[key] || key
  }
  // Controls that stay out of the layout until added from the gallery, even
  // for settings saved before they existed.
  readonly property var optIn: ({ microphoneMute: "microphoneMuteControl", awake: "stayAwakeControl", screensaver: "screensaverControl", screenshot: "screenshotControl", screenrecord: "screenRecordControl", dictate: "dictateControl", reminder: "reminderControl" })
  function isShown(key) {
    if (optIn[key] && !settings[optIn[key]]) return false
    return String(settings.controlCenterHidden || "").split(",").indexOf(key) === -1
  }
  function setShown(key, shown) {
    if (optIn[key]) settings[optIn[key]] = shown
    var hidden = String(settings.controlCenterHidden || "").split(",").filter(function(item) { return item !== "" && item !== key })
    if (!shown) hidden.push(key)
    settings.controlCenterHidden = hidden.join(",")
  }
  // Reads what Quickshell doesn't report on its own, each time the control
  // center opens.
  function refresh() {
    if (!brightnessRead.running) brightnessRead.running = true
    if (!gameModeRead.running) gameModeRead.running = true
    host.keyboard.refresh()
    if (!screensaverRead.running) screensaverRead.running = true
    if (!reminderRead.running) reminderRead.running = true
    if (!voxtypeCheck.running) voxtypeCheck.running = true
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
  readonly property var microphoneSource: Pipewire.defaultAudioSource
  readonly property bool microphoneReady: !!(microphoneSource && microphoneSource.ready && microphoneSource.audio)
  readonly property bool microphoneMuted: !!(microphoneSource && microphoneSource.audio && microphoneSource.audio.muted)
  readonly property real microphoneVolume: microphoneSource && microphoneSource.audio ? microphoneSource.audio.volume : 0
  readonly property var inputs: {
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    return nodes.filter(function(n) { return n && !n.isSink && !n.isStream && n.audio })
  }
  PwObjectTracker { objects: [controls.microphoneSource] }
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

  // --- Keyboard layout: the main keyboard's (see KeyboardLayout) ---
  readonly property string keyboardLabel: host.keyboard.name || "Unknown"

  // --- Shell services ---
  readonly property var notifications: host.shell ? host.shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var nightlight: host.shell ? host.shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property var idle: host.shell ? host.shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property bool dnd: notifications ? !!notifications.doNotDisturb : false
  readonly property bool nightOn: nightlight ? !!nightlight.enabled : false
  readonly property bool stayAwake: idle ? !!idle.stayAwake : false
  function controlPresent(key) {
    var tile = host.addons.tileFor(key)
    if (tile) return tile.present !== false
    if (key === "night") return !!nightlight
    if (key === "awake") return !!idle
    if (isMicrophoneControl(key)) return !!(microphoneSource && microphoneSource.audio)
    if (key === "sound") return !!(sink && sink.audio)
    if (key === "display") return brightnessAvailable
    return true
  }
  function isMicrophoneControl(key) { return key === "microphone" || key === "microphoneMute" }
  function controlWide(key) {
    var tile = host.addons.tileFor(key)
    return tile ? !!tile.wide : key === "sound" || key === "microphone" || key === "display"
  }
  function controlIcon(key) {
    if (key === "microphoneMute") return microphoneMuted ? "󰍭" : "󰍬"
    if (key === "wifi") return wifiDevice ? (Networking.wifiEnabled ? "\uf1eb" : "󰖪") : "󰈀"
    if (key === "bluetooth") return btAdapter && btAdapter.enabled ? "󰂯" : "󰂲"
    if (key === "focus") return "󰍶"
    if (key === "game") return "󰊗"
    if (key === "awake") return stayAwake ? "󰅶" : "󰛊"
    if (key === "screensaver") return screensaverOn ? "󱄄" : "󰶐"
    if (key === "screenshot") return "󰹑"
    if (key === "screenrecord") return "󰻃"
    if (key === "dictate") return dictation === "transcribing" ? "󰔟" : ""
    if (key === "reminder") return "󰢌"
    if (key === "power") return profileIcons[profileName] || "󰾅"
    if (key === "keyboard") return "󰌌"
    return "󰖔"
  }
  function controlTitle(key) { return key === "wifi" ? (wifiDevice ? "Wi-Fi" : "Ethernet") : title(key) }
  function controlSubtitle(key) {
    if (key === "microphoneMute") return microphoneMuted ? "Muted" : "Unmuted"
    if (key === "wifi") return wifiDevice
      ? (!Networking.wifiEnabled ? "Off" : wifiNetwork ? wifiNetwork.name : "Not connected")
      : (wiredDevice && wiredDevice.connected ? "Connected" : "Disconnected")
    if (key === "bluetooth") return !btAdapter ? "Unavailable" : !btAdapter.enabled ? "Off" : btConnected ? String(btConnected.name || "Connected") : "On"
    if (key === "focus") return dnd ? "On" : "Off"
    if (key === "game") return gameMode ? "On" : "Off"
    if (key === "awake") return stayAwake ? "On" : "Off"
    if (key === "screensaver") return screensaverOn ? "On" : "Off"
    if (key === "screenshot") return "Region or window"
    if (key === "screenrecord") return recorder.recording ? recorder.timeText(recorder.elapsed) : recorder.active ? "Saving…" : "Off"
    if (key === "dictate") return !voxtypeInstalled ? "Not installed" : dictation === "recording" ? "Listening…" : dictation === "transcribing" ? "Transcribing…" : "Off"
    if (key === "reminder") return reminderCount === 0 ? "None set" : reminderCount === 1 ? "1 active" : reminderCount + " active"
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
    if (key === "awake") return stayAwake
    if (key === "screensaver") return screensaverOn
    if (key === "screenrecord") return recorder.active
    if (key === "dictate") return dictation !== "idle"
    if (key === "reminder") return reminderCount > 0
    if (key === "power") return profileName !== "balanced"
    if (key === "keyboard" || key === "screenshot") return false
    return nightOn
  }
  function controlAvailable(key) {
    if (key === "microphoneMute") return microphoneReady
    if (key === "wifi") return wifiDevice ? Networking.wifiHardwareEnabled !== false : !!wiredDevice
    if (key === "bluetooth") return !!btAdapter
    if (key === "focus") return !!notifications
    return true
  }
  // Ethernet only reports; there's nothing to switch.
  function controlClickable(key) { return key !== "wifi" || !!wifiDevice }
  function toggleControl(key) {
    if (key === "microphoneMute") { toggleMicrophoneMute(); return }
    if (key === "wifi" && wifiDevice) Networking.wifiEnabled = !Networking.wifiEnabled
    else if (key === "bluetooth" && btAdapter) btAdapter.enabled = !btAdapter.enabled
    else if (key === "focus" && notifications) notifications.setDoNotDisturb(!dnd)
    else if (key === "game") setGameMode(!gameMode)
    else if (key === "awake" && idle) idle.setIdleEnabled(stayAwake)
    else if (key === "screensaver") setScreensaver(!screensaverOn)
    else if (key === "screenshot") takeScreenshot()
    else if (key === "screenrecord") toggleRecording()
    else if (key === "dictate") toggleDictation()
    else if (key === "reminder") setReminder()
    else if (key === "power") cycleProfile()
    else if (key === "keyboard") host.keyboard.next()
    else if (key === "night" && nightlight) nightlight.setNightlight(!nightOn)
  }

  // --- Game Mode: Hyprland animations off (restored by a config reload) ---
  property bool gameMode: false
  Process {
    id: gameModeRead
    command: ["hyprctl", "getoption", "animations:enabled"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: controls.gameMode = /bool:\s*false/.test(String(text || ""))
    }
  }
  Process { id: gameModeWrite; onExited: gameModeRead.running = true }
  function setGameMode(on) {
    gameMode = on
    gameModeWrite.command = ["hyprctl", "eval", "hl.config({ animations = { enabled = " + (on ? "false" : "true") + " } })"]
    gameModeWrite.running = true
  }

  // --- Screensaver: Omarchy's "screensaver-off" toggle, as in its menu but
  // without the notification ---
  property bool screensaverOn: true
  Process {
    id: screensaverRead
    command: ["omarchy-toggle-enabled", "screensaver-off"]
    onExited: function(code) { controls.screensaverOn = code !== 0 }
  }
  Process { id: screensaverWrite; onExited: screensaverRead.running = true }
  function setScreensaver(on) {
    screensaverOn = on
    screensaverWrite.command = ["omarchy-toggle", "screensaver-off", on ? "off" : "on"]
    screensaverWrite.running = true
  }

  // --- Screenshot: Omarchy's, as on Print, once the island has closed so it
  // isn't in the shot ---
  Timer {
    id: screenshotDelay
    interval: 300
    onTriggered: Quickshell.execDetached(["omarchy-capture-screenshot"])
  }
  function takeScreenshot() {
    host.view = "rest"
    screenshotDelay.restart()
  }

  // --- Screen recording: stops one, or opens Omarchy's recording options
  // (audio, webcam) in the island's menu, as Alt+Print does ---
  readonly property var recorder: host.recorder
  function toggleRecording() {
    if (recorder.recording) recorder.stop()
    else if (!recorder.active) {
      host.menuRoute = "trigger.capture.screenrecord"
      host.view = "menu"
    }
  }

  // --- Dictate: Omarchy's voxtype dictation, as on Super+Ctrl+X, once the
  // island has closed so the text lands in the focused window; offers
  // Omarchy's installer when voxtype isn't there ---
  property bool voxtypeInstalled: false
  // "idle", "recording" or "transcribing", followed only while the control
  // is in the control center.
  property string dictation: "idle"
  Process {
    id: voxtypeCheck
    command: ["omarchy-cmd-present", "voxtype"]
    onExited: function(code) { controls.voxtypeInstalled = code === 0 }
  }
  Process {
    command: ["omarchy-voxtype-status"]
    running: controls.voxtypeInstalled && !!controls.settings.dictateControl
    onRunningChanged: if (!running) controls.dictation = "idle"
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(line)
          var state = String(data.alt || data.class || "idle")
          controls.dictation = state === "recording" || state === "transcribing" ? state : "idle"
        } catch (e) {}
      }
    }
  }
  Timer {
    id: dictationDelay
    interval: 300
    onTriggered: Quickshell.execDetached(["voxtype", "record", "toggle"])
  }
  function toggleDictation() {
    if (!voxtypeInstalled) {
      host.view = "rest"
      Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-voxtype-install"])
      return
    }
    host.view = "rest"
    dictationDelay.restart()
  }

  // --- Reminders: Omarchy's set-a-reminder flow, as on Super+Ctrl+R, with
  // how many are pending ---
  property int reminderCount: 0
  Process {
    id: reminderRead
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { controls.reminderCount = Number(JSON.parse(text).count) || 0 } catch (e) {}
      }
    }
  }
  function setReminder() {
    host.view = "rest"
    Quickshell.execDetached(["omarchy-reminder", "-i"])
  }

  // --- Brightness (the Display card hides when the output has no control) ---
  property bool brightnessAvailable: false
  property int brightness: 0
  Process {
    id: brightnessRead
    command: ["omarchy-brightness-display", "--monitor", controls.host.outputName]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = parseInt(String(text || "").trim(), 10)
        controls.brightnessAvailable = !isNaN(value)
        if (!isNaN(value)) controls.brightness = Math.max(0, Math.min(100, value))
      }
    }
    onExited: function(code) { if (code !== 0) controls.brightnessAvailable = false }
  }
  Process { id: brightnessWrite }
  Timer {
    id: brightnessDebounce
    interval: 120
    onTriggered: {
      if (brightnessWrite.running) { restart(); return }
      brightnessWrite.command = ["omarchy-brightness-display", "--no-osd", "--monitor", controls.host.outputName, controls.brightness + "%"]
      brightnessWrite.running = true
    }
  }
  function setBrightness(value) {
    brightness = value
    brightnessDebounce.restart()
  }
}
