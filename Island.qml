import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import "components"
import "services"
import "views"

Item {
  id: root
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property var barConfig: ({})
  property string omarchyPath: ""

  readonly property var nowPlaying: nowPlayingData
  NowPlaying { id: nowPlayingData; shell: root.shell; theme: root.theme }
  readonly property bool mediaPill: view === "rest" && nowPlaying.playing && !setup.needsSetup && settings.mediaPill && !downloadPill

  property string askQuestion: ""
  readonly property var askProviders: ({
    claude: { name: "Claude", cli: "claude", glyph: "\uec82", tile: "#d97757", ink: "#ffffff" },
    chatgpt: { name: "Codex", cli: "codex", glyph: "\uec81", tile: "#f2f2f2", ink: "#000000" }
  })
  readonly property var askProvider: settings.askAi === "none" ? null : askProviders[settings.askAi] || askProviders.chatgpt
  function ask(question) {
    question = String(question || "").trim()
    if (!question || !askProvider) return
    askQuestion = question
    view = "answer"
  }

  readonly property var downloads: downloadTracker
  DownloadTracker { id: downloadTracker; enabled: root.settings.downloads }
  readonly property var packages: packageTracker
  PackageUpdateTracker { id: packageTracker; enabled: root.settings.systemUpdates }
  readonly property bool downloadDone: view === "rest" && !setup.needsSetup
    && (downloads.finishedName !== "" || packages.finishedTitle !== "")
  readonly property bool downloadActive: view === "rest" && !setup.needsSetup
    && (downloads.active || packages.active) && !downloadDone
  readonly property bool downloadPill: downloadDone || downloadActive
  Process { id: downloadOpener }
  function openDownloads() {
    if (!downloads.active && downloads.finishedName === "") {
      packages.dismissFinished()
      return
    }
    var path = downloadDone ? downloads.finishedPath : downloads.folder
    downloads.dismissFinished()
    downloadOpener.command = ["sh", "-c", '[ -e "$1" ] && exec xdg-open "$1"; exec xdg-open "$(dirname "$1")"', "sh", path]
    downloadOpener.startDetached()
  }

  readonly property real volume: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
    ? Pipewire.defaultAudioSink.audio.volume : -1
  readonly property bool muted: !!(Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
    && Pipewire.defaultAudioSink.audio.muted)
  readonly property string wantedOutput: String(barConfig.output || "DP-1")
  readonly property string outputName: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === wantedOutput) return wantedOutput
    var focused = Hyprland.focusedMonitor
    if (focused && focused.name) return String(focused.name)
    return screens.length ? String(screens[0].name) : ""
  }
  readonly property string home: Quickshell.env("HOME")

  readonly property var theme: themeData
  Theme { id: themeData; settings: root.settings; home: root.home }
  readonly property QtObject settings: islandSettings.values
  IslandSettings { id: islandSettings; home: root.home }
  readonly property var controlCenterKeys: {
    var known = ["wifi", "bluetooth", "focus", "game", "night", "power", "keyboard", "sound", "microphone", "microphoneMute", "display"]
    var saved = String(settings.controlCenterOrder || "").split(",")
    var result = []
    for (var i = 0; i < saved.length; i++)
      if (known.indexOf(saved[i]) !== -1 && result.indexOf(saved[i]) === -1) result.push(saved[i])
    for (var j = 0; j < known.length; j++)
      if (result.indexOf(known[j]) === -1) result.push(known[j])
    return result
  }
  function controlCenterTitle(key) {
    var names = { wifi: "Wi-Fi / Ethernet", bluetooth: "Bluetooth", focus: "Focus", game: "Game Mode", night: "Night Shift", power: "Power Mode", keyboard: "Keyboard", sound: "Sound", microphone: "Microphone", microphoneMute: "Microphone", display: "Display" }
    return names[key] || key
  }
  function controlCenterIsShown(key) {
    if (key === "microphoneMute" && !settings.microphoneMuteControl) return false
    return String(settings.controlCenterHidden || "").split(",").indexOf(key) === -1
  }
  function setControlCenterShown(key, shown) {
    if (key === "microphoneMute") settings.microphoneMuteControl = shown
    var hidden = String(settings.controlCenterHidden || "").split(",").filter(function(item) { return item !== "" && item !== key })
    if (!shown) hidden.push(key)
    settings.controlCenterHidden = hidden.join(",")
  }

  readonly property var clockDate: clock.date
  property string view: "rest"
  readonly property bool notificationPill: view === "feedback" && feedbackKind === "notification"
  readonly property bool volumePill: view === "feedback" && feedbackKind === "volume"
  readonly property bool clipboardPill: view === "feedback" && feedbackKind === "clipboard"
  readonly property bool activityPill: view === "feedback" && feedbackKind === "activity"
  readonly property bool workspacesPill: view === "feedback" && feedbackKind === "workspaces"

  // ---------- Workspace switches ----------

  // Omarchy's bar's workspaces: 1–5 always, and any other up to 10 that
  // exists. Switching shows them for a moment (see WorkspacePill).
  readonly property var workspaceIds: {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    return ids.sort(function(a, b) { return a - b })
  }
  readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  onFocusedWorkspaceIdChanged: {
    if (activitiesReady && settings.workspaceHud && focusedWorkspaceId > 0) showFeedback("", 1200, "workspaces")
  }

  // ---------- Device live activities: battery, Bluetooth ----------

  // The last one shown by the DevicePill; see its header for the fields.
  property var activity: ({})
  function showActivity(a) {
    activity = a
    showFeedback("", 3200, "activity")
  }
  // For a few seconds after the shell starts, everything is only recorded:
  // devices reporting in aren't news.
  property bool activitiesReady: false
  Timer {
    interval: 3000
    running: true
    onTriggered: {
      root.batteryWarned = root.batteryLevel <= 10 ? 10 : root.batteryLevel <= 20 ? 20 : 101
      root.btKnown = root.btConnected
      root.activitiesReady = true
    }
  }

  // Battery: charging started, and the level falling to 20% and to 10%, each
  // once per discharge.
  readonly property var batteryDevice: UPower.displayDevice
  readonly property bool hasBattery: !!(batteryDevice && batteryDevice.isLaptopBattery)
  readonly property int batteryLevel: hasBattery ? Math.round(batteryDevice.percentage * 100) : -1
  readonly property bool onPower: hasBattery && !UPower.onBattery
  property int batteryWarned: 101
  onOnPowerChanged: {
    if (onPower) batteryWarned = 101
    if (!activitiesReady || !onPower || !hasBattery || !settings.batteryActivity) return
    showActivity({ kind: "charging", title: "Charging", status: batteryLevel + "%", battery: batteryLevel, connected: true })
  }
  onBatteryLevelChanged: {
    if (!activitiesReady || !hasBattery || onPower || batteryLevel < 0) return
    var threshold = batteryLevel <= 10 ? 10 : batteryLevel <= 20 ? 20 : 101
    if (threshold >= batteryWarned) return
    batteryWarned = threshold
    if (settings.batteryActivity)
      showActivity({ kind: "lowBattery", title: "Low Battery", status: batteryLevel + "%", battery: batteryLevel, connected: true })
  }

  // Bluetooth: a device connecting or disconnecting.
  readonly property var btConnected: {
    var devs = Bluetooth.devices ? Bluetooth.devices.values : []
    return devs.filter(function(d) { return d && d.connected }).map(function(d) {
      return { key: String(d.address), name: String(d.deviceName || d.name || d.address), icon: String(d.icon || ""),
        battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1 }
    })
  }
  property var btKnown: []
  onBtConnectedChanged: {
    if (!activitiesReady) return
    var known = btKnown, now = btConnected
    function has(list, key) { return list.some(function(d) { return d.key === key }) }
    btKnown = now
    if (!settings.bluetoothActivity) return
    var joined = now.filter(function(d) { return !has(known, d.key) })
    var left = known.filter(function(d) { return !has(now, d.key) })
    if (joined.length) {
      var d = joined[joined.length - 1]
      showActivity({ kind: "bluetooth", title: d.name, status: "Connected", battery: d.battery, connected: true, icon: d.icon })
    } else if (left.length) {
      showActivity({ kind: "bluetooth", title: left[left.length - 1].name, status: "Disconnected", battery: -1, connected: false, icon: left[left.length - 1].icon })
    }
  }


  readonly property var clipboard: clipboardWatcher
  ClipboardWatcher {
    id: clipboardWatcher
    home: root.home
    settings: root.settings
    onCopied: root.showFeedback("", 2200, "clipboard")
  }

  property bool surfaceContentReady: false
  property string feedback: ""
  property string feedbackKind: ""
  property var surfaceNames: []
  function registerSurface(name) {
    if (surfaceNames.indexOf(name) === -1) surfaceNames = surfaceNames.concat([name])
  }
  readonly property bool surfaceOpen: surfaceNames.indexOf(view) !== -1
  property bool initialized: false
  readonly property bool barHidden: barOffFlag.count > 0
  FolderListModel {
    id: barOffFlag
    folder: "file://" + root.home + "/.local/state/omarchy/toggles"
    nameFilters: ["bar-off"]
    showDirs: false
    showHidden: true
  }
  readonly property int barSize: 0
  readonly property string position: "top"

  function surfaceOpenFor(v) { return surfaceNames.indexOf(v) !== -1 }

  onViewChanged: {
    if (view === "rest" && updateAnnouncePending) Qt.callLater(announceUpdate)
    surfaceContentReady = false
    if (surfaceOpenFor(view)) surfaceRevealTimer.restart()
    else surfaceRevealTimer.stop()
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

  function showFeedback(message, duration, kind) {
    if (surfaceOpen) return
    if (feedbackKind === "notification" && kind !== "notification" && feedbackTimer.running) return
    feedback = String(message || "")
    feedbackKind = String(kind || "system")
    view = "feedback"
    feedbackTimer.interval = duration || 2800
    feedbackTimer.restart()
  }

  // The HUD shows when the volume or mute state differs from the last one seen
  // on the same output. An output's first reading (at startup, or after
  // switching outputs) is it reporting in, so it's only remembered.
  property var hudSink: null
  property real hudVolume: -1
  property bool hudMuted: false
  function volumeFeedback() {
    var sink = Pipewire.defaultAudioSink
    if (!initialized || !sink || !sink.ready || volume < 0) return
    var changed = hudSink === sink && (volume !== hudVolume || muted !== hudMuted)
    hudSink = sink
    hudVolume = volume
    hudMuted = muted
    if (changed && settings.volumeHud) showFeedback("", 1800, "volume")
  }
  readonly property bool sinkReady: !!(Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.ready)
  onVolumeChanged: volumeFeedback()
  onMutedChanged: volumeFeedback()
  onSinkReadyChanged: volumeFeedback()
  Component.onCompleted: initialized = true

  readonly property var setup: companionSetup
  CompanionSetup {
    id: companionSetup
    home: root.home
    onFailureBanner: function(row) { root.showBanner(row, 10000) }
  }

  readonly property var updater: islandUpdater
  IslandUpdater {
    id: islandUpdater
    pluginDir: root.setup.pluginDir
    onAvailable: root.announceUpdate()
  }
  // The banner waits until nothing else is on the island.
  property bool updateAnnouncePending: false
  function announceUpdate() {
    if (surfaceOpen || view === "feedback") { updateAnnouncePending = true; return }
    updateAnnouncePending = false
    showBanner(updater.bannerRow("A new version is ready. Click to update."), 10000)
  }
  function updateIsland() {
    if (updater.status === "updating") return
    showBanner(updater.bannerRow("Updating Island…"), 120000)
    updater.update()
  }

  Timer {
    id: feedbackTimer
    repeat: false
    onTriggered: {
      if (root.view === "feedback") root.view = "rest"
      root.feedbackKind = ""
    }
  }

  Timer {
    id: surfaceRevealTimer
    interval: 90 * root.theme.motionScale
    repeat: false
    onTriggered: root.surfaceContentReady = true
  }

  readonly property var notifications: notificationClient
  NotificationClient {
    id: notificationClient
    home: root.home
    historyVisible: root.view === "controls"
    onArrived: function(row) {
      if (!root.surfaceOpen) root.showFeedback(String(row.summary || row.app || "Notification"), root.settings.bannerSeconds * 1000, "notification")
    }
  }
  // The island's own banners (setup, updates) in the notification pill.
  function showBanner(row, duration) {
    notifications.last = row
    showFeedback("", duration, "notification")
  }

  function dismissPillNotification() {
    var row = notifications.last
    feedbackKind = ""
    view = "rest"
    if (row) notifications.command("dismissKey", row)
  }

  property string menuRoute: "root"

  function toggleView(name) {
    view = view === name ? "rest" : name
    return view
  }

  IpcHandler {
    target: "guilhermerisu.island"
    function show(name: string): string {
      if (name === "menu") root.menuRoute = "root"
      return root.toggleView(name)
    }
    function openMenu(route: string): string {
      root.menuRoute = String(route || "root")
      root.view = "menu"
      return root.view
    }
    function toggle(): string { return root.toggleView("controls") }
    function themes(): string { return root.toggleView("themes") }
    function wallpapers(): string { return root.toggleView("wallpapers") }
    function apps(): string { return root.toggleView("apps") }
    function power(): string { return root.toggleView("power") }
    function ask(question: string): string {
      root.ask(question)
      return root.view
    }
    function companionStatus(): string { return root.setup.status }
    function installCompanion(): string {
      root.setup.install()
      return "installing"
    }
    function showHistory(): string {
      root.view = "controls"
      return root.view
    }
    function close(): string {
      root.view = "rest"
      return "rest"
    }
  }

  // An open view closes on a click outside the island (see outsideArea),
  // armed a moment after it opens so the click that opened it can't count.
  property bool outsideClickArmed: false
  readonly property bool closesOnOutsideClick: surfaceOpen && outsideClickArmed
  Timer {
    interval: 120
    running: root.surfaceOpen && !root.outsideClickArmed
    onTriggered: root.outsideClickArmed = true
  }
  onSurfaceOpenChanged: if (!surfaceOpen) outsideClickArmed = false
  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: window
        required property var modelData
        screen: modelData
        visible: modelData.name === root.outputName
        color: "transparent"
        surfaceFormat.opaque: false
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "omarchy-island"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: island.activeSurface && island.activeSurface.wantsKeyboard
          ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Only the island takes input, except while a view is open: then the
        // whole screen does, so outsideArea can close it. The island holds the
        // keyboard exclusively then, and Hyprland sends no pointer input to
        // any other surface, so a focus grab or a separate layer never sees
        // the click. The click that closes the view goes no further.
        mask: Region { item: root.closesOnOutsideClick ? outsideArea : island }
        MouseArea {
          id: outsideArea
          anchors.fill: parent
          enabled: root.closesOnOutsideClick
          acceptedButtons: Qt.AllButtons
          // Clicks on the island's blank space fall through to here too.
          onPressed: function(mouse) {
            if (!island.contains(mapToItem(island, mouse.x, mouse.y))) root.view = "rest"
          }
        }


        Canvas {
          id: leftEar
          readonly property real r: 10
          visible: root.settings.notch
          x: island.x - r
          y: island.y
          width: r
          height: r
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.theme.background
            ctx.beginPath()
            ctx.moveTo(r, 0)
            ctx.lineTo(r, r)
            ctx.arc(0, r, r, 0, -Math.PI / 2, true)
            ctx.closePath()
            ctx.fill()
          }
        }
        Canvas {
          id: rightEar
          readonly property real r: 10
          visible: root.settings.notch
          x: island.x + island.width
          y: island.y
          width: r
          height: r
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.theme.background
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(0, r)
            ctx.arc(r, r, r, Math.PI, 1.5 * Math.PI, false)
            ctx.closePath()
            ctx.fill()
          }
        }

        Rectangle {
          id: island
          x: (parent.width - width) / 2
          y: root.barHidden && root.view === "rest" ? -height - 12 : root.settings.notch ? 0 : 8
          Behavior on y { NumberAnimation { duration: 300 * root.theme.motionScale; easing.type: Easing.OutCubic } }
          readonly property Item activeSurface: views.surfaceFor(root.view)
          readonly property real targetWidth: activeSurface ? activeSurface.islandWidth
            : root.notificationPill ? 440
            : root.volumePill ? 240
            : root.activityPill && root.activity.kind === "bluetooth" ? 360
            : root.clipboardPill || root.activityPill ? 320
            : root.workspacesPill ? root.workspaceIds.length * 24 + 42
            : root.view === "feedback" ? 280
            : root.setup.needsSetup ? (root.setup.warning.length > 24 ? 320 : 250)
            : root.downloadDone ? 360
            : root.downloadActive ? (root.downloads.active ? 240 : 280)
            : root.mediaPill ? 240
            : 100
          readonly property real targetHeight: activeSurface ? activeSurface.islandHeight
            : root.notificationPill ? 84
            : root.activityPill && root.activity.kind === "bluetooth" ? 64
            : root.clipboardPill || root.activityPill ? (root.settings.notch ? 40 : 44)
            : root.workspacesPill ? (root.settings.notch ? 36 : 40)
            : root.downloadDone ? 64
            : root.mediaPill || root.downloadPill ? (root.settings.notch ? 40 : 44)
            : root.volumePill ? 56
            : root.view === "rest" ? (root.settings.notch ? 36 : 40) : 52
          property real radiusCap: root.volumePill ? 20 : root.view === "answer" ? 44 : root.surfaceOpen ? 30 : 38
          Behavior on radiusCap {
            NumberAnimation { duration: 390 * root.theme.motionScale; easing.type: Easing.OutQuint }
          }
          radius: Math.min(height / 2, root.settings.notch && !root.surfaceOpen ? Math.min(radiusCap, 16) : radiusCap)
          topLeftRadius: root.settings.notch ? 0 : radius
          topRightRadius: root.settings.notch ? 0 : radius
          scale: root.view === "rest" && clockHover.hovered && root.settings.hoverLift && !root.settings.notch ? 1.07 : 1
          Behavior on scale { NumberAnimation { duration: 240 * root.theme.motionScale; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
          HoverHandler { id: clockHover; enabled: root.view === "rest" }
          color: root.theme.background
          clip: true
          readonly property real springStiffness: 6.5 / root.theme.motionScale
          property real springWidth: targetWidth
          property real springHeight: targetHeight
          Behavior on springWidth {
            SpringAnimation { spring: island.springStiffness; damping: 0.4; mass: 1; epsilon: 0.2 }
          }
          Behavior on springHeight {
            SpringAnimation { spring: island.springStiffness; damping: 0.4; mass: 1; epsilon: 0.2 }
          }
          width: Math.max(40, springWidth)
          height: Math.max(28, springHeight)
          Behavior on color { ColorAnimation { duration: 240 * root.theme.motionScale; easing.type: Easing.InOutQuad } }

          MouseArea {
            anchors.fill: parent
            enabled: root.view === "rest" || root.view === "feedback"
            onClicked: function(mouse) {
              feedbackTimer.stop()
              if (root.notificationPill && root.notifications.last && root.notifications.last.islandUpdate) root.updateIsland()
              else if (root.notificationPill && root.notifications.last && root.notifications.last.islandSetupRetry) { root.feedbackKind = ""; root.view = "rest"; root.setup.install() }
              else if (root.notificationPill) root.dismissPillNotification()
              else if (root.clipboardPill) root.view = "clipboard"
              else if (root.activityPill) root.view = root.activity.kind === "bluetooth" ? "bluetooth" : "controls"
              else if (root.view === "rest" && root.setup.needsSetup) root.setup.pillClicked()
              else if (root.downloadDone || (root.downloadActive && (mouse.x < 56 || mouse.x > width - 90))) root.openDownloads()
              else if (root.mediaPill && (mouse.x < 56 || mouse.x > width - 72)) root.view = "player"
              else root.view = "controls"
            }
          }

          NotificationPill { host: root; shape: island; anchors.fill: parent }

          VolumeSlider { host: root; shape: island; anchors.fill: parent }

          ClipboardPill { host: root; anchors.fill: parent }

          DevicePill { host: root; anchors.fill: parent }

          WorkspacePill { host: root; anchors.fill: parent }

          MediaPill { host: root; anchors.fill: parent }

          DownloadPill { host: root; anchors.fill: parent }

          IslandLabel { host: root; anchors.centerIn: parent }

          Views { id: views; host: root; anchors.fill: parent }
        }
      }
    }
  }
}
