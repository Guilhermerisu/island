import QtQuick
import Qt.labs.folderlistmodel
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "addons"
import "components"
import "services"
import "views"
import "components/Squircle.js" as Squircle
// Omarchy's own OSD payload model, so what the island shows matches it.
import "file:///usr/share/omarchy/shell/plugins/osd/OsdModel.js" as OsdModel

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
  readonly property bool mediaPill: view === "rest" && nowPlaying.playing && !setup.needsSetup && settings.mediaPill && !downloadPill && !addons.ongoing && !recordingPill

  // A screen recording holds the resting island over every other pill.
  readonly property var recorder: screenRecorder
  ScreenRecorder { id: screenRecorder }
  readonly property bool recordingPill: view === "rest" && !setup.needsSetup && settings.screenRecordingActivity && recorder.active

  readonly property var downloads: downloadTracker
  DownloadTracker { id: downloadTracker; enabled: root.settings.downloads }
  readonly property var packages: packageTracker
  PackageUpdateTracker { id: packageTracker; enabled: root.settings.systemUpdates }
  readonly property bool downloadDone: view === "rest" && !setup.needsSetup && !addons.ongoing && !recordingPill
    && (downloads.finishedName !== "" || packages.finishedTitle !== "")
  readonly property bool downloadActive: view === "rest" && !setup.needsSetup && !addons.ongoing && !recordingPill
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

  readonly property var clockDate: clock.date
  // The resting pill's text in the chosen Settings → Clock Format (one of
  // clockFormats), following the 24-hour and AM/PM switches.
  readonly property var clockFormats: ["time", "day", "date", "short", "weekday"]
  readonly property string clockText: formatClock(clockDate, settings.clockFormat)
  function formatClock(date, format) {
    var en = Qt.locale("en_US")
    // Qt only counts hours to 12 when there's an AM/PM marker; iOS drops it.
    var time = settings.clock24h ? en.toString(date, "HH:mm")
      : settings.clockAmPm ? en.toString(date, "h:mm AP")
      : en.toString(date, "h:mm AP").replace(/\s*[AP]M$/i, "")
    switch (format) {
    case "day": return en.toString(date, "ddd") + " " + time
    case "date": return en.toString(date, "d MMM") + " " + time
    case "short": return en.toString(date, "ddd d MMM") + " " + time
    case "weekday": return en.toString(date, "dddd") + " " + time
    default: return time
    }
  }
  property string view: "rest"
  // Settings opens on settingsPage (and, on Addons, with settingsAddon's
  // options out) the next time it's shown; both are cleared once taken.
  property string settingsPage: ""
  property string settingsAddon: ""
  function openSettings(page, addonId) {
    settingsPage = page || ""
    settingsAddon = addonId || ""
    view = "settings"
  }
  readonly property bool notificationPill: view === "feedback" && feedbackKind === "notification"
  readonly property bool volumePill: view === "feedback" && feedbackKind === "volume"
  readonly property bool osdPill: view === "feedback" && feedbackKind === "osd"
  readonly property bool clipboardPill: view === "feedback" && feedbackKind === "clipboard"
  readonly property bool activityPill: view === "feedback" && feedbackKind === "activity"
  readonly property bool workspacesPill: view === "feedback" && feedbackKind === "workspaces"
  // The addon whose pill is on the island, if any (see addons/Addon.qml):
  // the one shown for a moment, or at rest an ongoing one's.
  readonly property var addonPill: view === "feedback" ? addons.pillFor(feedbackKind)
    : view === "rest" && !setup.needsSetup && !recordingPill ? addons.ongoing : null

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
    if (activities.ready && settings.workspaceHud && focusedWorkspaceId > 0) showFeedback("", 1200, "workspaces")
  }

  // ---------- Device live activities: battery, Bluetooth ----------

  readonly property var activities: deviceActivities
  DeviceActivities {
    id: deviceActivities
    settings: root.settings
    onShow: root.showFeedback("", 3200, "activity")
  }


  readonly property var addons: addonHost
  Addons { id: addonHost; host: root; settings: root.settings }

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
  // Once per screen's copy of a view; it stops counting as one when the last
  // copy goes (an addon switched off, a screen unplugged).
  function registerSurface(name) {
    surfaceNames = surfaceNames.concat([name])
  }
  function unregisterSurface(name) {
    var i = surfaceNames.indexOf(name)
    if (i === -1) return
    var next = surfaceNames.slice()
    next.splice(i, 1)
    surfaceNames = next
    if (view === name && next.indexOf(name) === -1) view = "rest"
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

  // Auto-hide. The screensaver and fullscreen come live from Wayland and
  // Quickshell's own tracking; only "floating" lives in Hyprland's client
  // list, which Quickshell refetches on request. So while Hide on Tiling is
  // on, a burst of window events asks for it once.
  readonly property bool screensaverActive: ToplevelManager.toplevels.values
    .some(function(t) { return t.appId === "org.omarchy.screensaver" })
  readonly property bool autoHideTiling: settings.autoHideTiling
  onAutoHideTilingChanged: if (autoHideTiling) tilingRefreshTimer.restart()
  Connections {
    target: Hyprland
    enabled: root.autoHideTiling
    function onRawEvent(event) {
      var n = String((event && event.name) || "")
      if (["changefloatingmode", "openwindow", "closewindow", "movewindowv2"].indexOf(n) >= 0)
        tilingRefreshTimer.restart()
    }
  }
  Timer {
    id: tilingRefreshTimer
    interval: 60
    onTriggered: Hyprland.refreshToplevels()
  }

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
  Component.onCompleted: {
    initialized = true
    if (autoHideTiling) tilingRefreshTimer.restart()
  }

  // The media service handles the media keys and summons the stock OSD, which
  // is off, so the island watches every player instead: the one that paused,
  // resumed or changed track is the one shown, whichever the service calls
  // active. The pill waits a beat so a skip (title and state changing
  // together) shows once, and a player that is closing (stopping, then
  // vanishing) shows nothing.
  Instantiator {
    model: Mpris.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.mediaFeedback(modelData) }
      function onTrackTitleChanged() { root.mediaFeedback(modelData) }
    }
  }
  function mediaFeedback(player) {
    if (!initialized || !settings.playbackOsd) return
    mediaFeedbackTimer.player = player
    mediaFeedbackTimer.restart()
  }
  Timer {
    id: mediaFeedbackTimer
    interval: 250
    property var player: null
    onTriggered: {
      var players = Mpris.players ? Mpris.players.values : []
      if (!player || players.indexOf(player) < 0 || !root.settings.playbackOsd) return
      var title = String(player.trackTitle || "")
      if (title === "") return
      var artist = String(player.trackArtist || "")
      root.showOsd(JSON.stringify({
        icon: player.isPlaying ? "media-play" : "media-pause",
        message: title + (artist ? " - " + artist : ""),
        duration: "1500"
      }))
    }
  }

  // ---------- Omarchy OSD ----------
  //
  // Payloads from the `osd` IPC target (omarchy-osd and Omarchy's scripts)
  // and from the backlight watch, shown in the island's own pill. Volume and
  // mute payloads are skipped while the sink watcher above covers them.
  property string osdIcon: ""
  property string osdMessage: ""
  property bool osdProgress: false
  property real osdValue: 0
  property real osdMaxValue: 100
  function showOsd(payloadJson) {
    var p
    try { p = JSON.parse(String(payloadJson || "{}")) } catch (e) { return }
    var state = OsdModel.stateForShow(p.icon || "", p.message || "",
      p.value === undefined ? "" : String(p.value),
      p.max === undefined ? "100" : String(p.max),
      p.progressText || "",
      p.duration === undefined ? "" : String(p.duration))
    if (settings.volumeHud && /^(volume|mute)/.test(state.iconKey)) return
    if (!settings.brightnessHud && /^(brightness|display)$/.test(state.iconKey)) return
    osdIcon = state.icon
    osdMessage = state.message
    osdProgress = state.hasProgress
    osdValue = state.value
    osdMaxValue = state.maxValue
    showFeedback("", state.duration > 0 ? state.duration : 1200, "osd")
  }

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
  OsdBridge { id: osdBridge; host: root }
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
    interval: root.theme.contentRevealDelay
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
      // A view that isn't there (a disabled addon's) leaves the island alone.
      if (!root.surfaceOpenFor(name)) return root.view
      if (name === "menu") root.menuRoute = "root"
      return root.toggleView(name)
    }
    function openMenu(route: string): string {
      root.menuRoute = String(route || "root")
      root.view = "menu"
      return root.view
    }
    // An addon's pane in Settings (System Stats, Agents, Displays); again, while it's
    // showing, closes Settings (see SettingsView).
    function addonSettings(id: string): string {
      var addon = root.addons.root(id)
      var pages = addon ? addon.settingsPages || [] : []
      if (!pages.length) return root.view
      // Already open: SettingsView takes the page itself (or closes).
      if (root.view === "settings") root.settingsPage = pages[0].title
      else root.openSettings(pages[0].title)
      return root.view
    }
    function toggle(): string { return root.toggleView("controls") }
    function themes(): string { return root.toggleView("themes") }
    function wallpapers(): string { return root.toggleView("wallpapers") }
    function apps(): string { return root.toggleView("apps") }
    function power(): string { return root.toggleView("power") }
    // Ask AI's, while that addon is enabled (see addons/ask).
    function ask(question: string): string {
      var ask = root.addons.root("ask")
      if (ask) ask.ask(question)
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

        readonly property var monitor: Hyprland.monitorFor(screen)
        readonly property var activeWorkspace: (monitor && monitor.activeWorkspace) ? monitor.activeWorkspace : Hyprland.focusedWorkspace

        readonly property bool hasFullscreen: {
          var ws = activeWorkspace
          if (!ws) return false
          if (ws.hasFullscreen) return true
          var tl = ws.toplevels.values
          for (var i = 0; i < tl.length; i++)
            if (tl[i].wayland && tl[i].wayland.fullscreen) return true
          return false
        }
        readonly property bool hasScreensaver: root.screensaverActive

        readonly property bool hasTiled: {
          var ws = activeWorkspace
          var tl = ws ? ws.toplevels.values : []
          for (var i = 0; i < tl.length; i++) {
            var ipc = tl[i].lastIpcObject
            if (ipc && ipc.mapped !== false && !ipc.hidden && !ipc.floating) return true
          }
          return false
        }

        readonly property bool autoHideCondition: (
          (root.settings.autoHideFullscreen && hasFullscreen) ||
          hasScreensaver ||
          (root.settings.autoHideTiling && hasTiled)
        )

        property bool edgeRevealed: false
        Timer {
          id: edgeLeaveTimer
          interval: 400
          onTriggered: window.edgeRevealed = false
        }

        readonly property bool isEffectivelyHidden: (root.barHidden || autoHideCondition)
          && (root.view === "rest" || hasScreensaver)

        // Hover at the top edge can bring a hidden island back.
        readonly property bool revealArmed: isEffectivelyHidden && !hasScreensaver

        readonly property bool islandHidden: isEffectivelyHidden
          && !(revealArmed && edgeRevealed)

        // Only the island takes input, except while a view is open: then the
        // whole screen does, so outsideArea can close it. While the island can
        // auto-hide, revealStrip takes hover input at the edge to slide it back.
        mask: Region {
          item: root.closesOnOutsideClick ? outsideArea : window.islandHidden ? null : island
          regions: [
            Region { item: window.revealArmed ? revealStrip : null }
          ]
        }
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

        Item {
          id: revealStrip
          anchors.top: parent.top
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.max(island.width + 80, 260)
          // Once revealed it reaches down past the island, so the gap above
          // the floating pill still counts as hovering and doesn't hide it.
          height: !window.revealArmed ? 0
            : window.edgeRevealed ? (root.settings.notch ? 0 : 8) + island.height : 4
          visible: height > 0

          HoverHandler {
            id: revealHover
            onHoveredChanged: {
              if (hovered) {
                edgeLeaveTimer.stop()
                window.edgeRevealed = true
              } else {
                if (!islandPointerHover.hovered) edgeLeaveTimer.restart()
              }
            }
          }
        }

        // While a view is open the island floats over the windows: a soft,
        // wide shadow for depth plus a tight, darker one where it meets them
        // (the resting pill stays flat, like hardware).
        RectangularShadow {
          x: island.x
          y: island.y
          width: island.width
          height: island.height
          radius: island.radius
          offset.y: 2
          blur: 8
          color: Qt.rgba(0, 0, 0, 0.4)
          opacity: root.surfaceOpen ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { MotionAnimation { theme: root.theme; pace: root.surfaceOpen ? "morph" : "exit"; curve: "fade" } }
        }
        RectangularShadow {
          x: island.x
          y: island.y
          width: island.width
          height: island.height
          radius: island.radius
          offset.y: 14
          blur: 48
          spread: -4
          color: Qt.rgba(0, 0, 0, 0.6)
          opacity: root.surfaceOpen ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { MotionAnimation { theme: root.theme; pace: root.surfaceOpen ? "morph" : "exit"; curve: "fade" } }
        }

        Canvas {
          id: leftEar
          readonly property real r: 10
          visible: root.settings.notch && island.y > -r
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
          visible: root.settings.notch && island.y > -r
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
          y: window.islandHidden ? -height - 20 : root.settings.notch ? 0 : 8
          Behavior on y { MotionAnimation { theme: root.theme; pace: "standard" } }
          readonly property Item activeSurface: views.surfaceFor(root.view)
          // How much wider than a bare time the chosen clock format is; the
          // resting pill and the pills that keep the clock in the middle grow by it.
          readonly property real clockExtra: Math.max(0, Math.ceil(clockMetrics.advanceWidth) + 56 - 100)
          readonly property real targetWidth: activeSurface ? activeSurface.islandWidth
            : root.notificationPill ? 440
            : root.volumePill ? 240
            : root.osdPill ? (root.osdProgress ? 240 : (root.osdMessage.length > 26 ? 340 : 280))
            : root.activityPill && root.activities.current.kind === "bluetooth" ? 360
            : root.clipboardPill || root.activityPill ? 320
            : root.workspacesPill ? root.workspaceIds.length * 24 + 42
            : root.recordingPill ? 240 + clockExtra
            : root.addonPill ? root.addonPill.pillWidth + (root.view === "feedback" || root.addonPill.pillAsks ? 0 : clockExtra)
            : root.view === "feedback" ? 280
            : root.setup.needsSetup ? (root.setup.warning.length > 24 ? 320 : 250)
            : root.downloadDone ? 380
            : root.downloadActive ? (root.downloads.active ? 240 : 280) + clockExtra
            : root.mediaPill ? 240 + clockExtra
            : 100 + clockExtra
          readonly property real targetHeight: activeSurface ? activeSurface.islandHeight
            : root.notificationPill ? 84
            : root.activityPill && root.activities.current.kind === "bluetooth" ? 64
            : root.clipboardPill || root.activityPill ? (root.settings.notch ? 40 : 44)
            : root.addonPill ? root.addonPill.pillHeight
            : root.workspacesPill ? (root.settings.notch ? 36 : 40)
            : root.downloadDone ? 76
            : root.mediaPill || root.downloadPill || root.recordingPill ? (root.settings.notch ? 40 : 44)
            : root.volumePill ? (root.settings.notch ? 40 : 44)
            : root.osdPill ? (root.settings.notch ? 40 : 44)
            : root.view === "rest" ? (root.settings.notch ? 36 : 40) : 52
          readonly property real targetRadius: activeSurface && activeSurface.cornerRadius > 0 ? activeSurface.cornerRadius
            : root.addonPill && root.addonPill.pillRadius > 0 ? root.addonPill.pillRadius
            : root.surfaceOpen ? 30 : 38
          readonly property real radiusCap: radiusSpring.value
          radius: Math.min(height / 2, root.settings.notch && !root.surfaceOpen ? Math.min(radiusCap, 16) : radiusCap)
          topLeftRadius: root.settings.notch ? 0 : radius
          topRightRadius: root.settings.notch ? 0 : radius
          scale: root.view === "rest" && clockHover.hovered && root.settings.hoverLift && !root.settings.notch ? 1.018 : 1
          Behavior on scale { MotionAnimation { theme: root.theme; pace: "quick" } }
          HoverHandler { id: clockHover; enabled: root.view === "rest" }
          HoverHandler {
            id: islandPointerHover
            onHoveredChanged: {
              if (hovered) {
                edgeLeaveTimer.stop()
              } else {
                if (window.edgeRevealed && !revealHover.hovered) edgeLeaveTimer.restart()
              }
            }
          }
          // The black itself is the squircle below; the Rectangle only keeps
          // the radius and clipping the pills and views rely on.
          color: "transparent"
          clip: true
          readonly property var cornerRadii: ({ topLeft: topLeftRadius, topRight: topRightRadius, bottomLeft: radius, bottomRight: radius })
          readonly property string outline: Squircle.path(width, height, cornerRadii, 0.6)
          // The same outline inset half a pixel, so a 1px edge stroke lands
          // inside the shape.
          readonly property string edgeOutline: Squircle.path(width - 1, height - 1, ({
            topLeft: Math.max(0, topLeftRadius - 0.5), topRight: Math.max(0, topRightRadius - 0.5),
            bottomLeft: Math.max(0, radius - 0.5), bottomRight: Math.max(0, radius - 0.5) }), 0.6)
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeWidth: -1
              fillColor: root.theme.background
              Behavior on fillColor { MotionColorAnimation { theme: root.theme } }
              PathSvg { path: island.outline }
            }
          }
          // Width, height and corners ride springs, so a change of mind
          // mid-morph keeps its momentum. Growing, the width leads and the
          // height follows a beat later; shrinking, the height goes first.
          readonly property string morphPace: root.surfaceOpen ? "morph" : "collapse"
          MotionSpring { id: widthSpring; theme: root.theme; pace: island.morphPace }
          MotionSpring { id: heightSpring; theme: root.theme; pace: island.morphPace }
          MotionSpring { id: radiusSpring; theme: root.theme; pace: island.morphPace; target: island.targetRadius }
          Timer { id: widthLag; interval: root.theme.morphLag; onTriggered: widthSpring.target = island.targetWidth }
          Timer { id: heightLag; interval: root.theme.morphLag; onTriggered: heightSpring.target = island.targetHeight }
          onTargetWidthChanged: {
            if (targetWidth < widthSpring.value) { widthLag.restart(); return }
            widthLag.stop()
            widthSpring.target = targetWidth
          }
          onTargetHeightChanged: {
            if (targetHeight > heightSpring.value) { heightLag.restart(); return }
            heightLag.stop()
            heightSpring.target = targetHeight
          }
          Component.onCompleted: {
            widthSpring.target = widthSpring.value = targetWidth
            heightSpring.target = heightSpring.value = targetHeight
          }
          width: Math.max(40, widthSpring.value)
          height: Math.max(28, heightSpring.value)

          MouseArea {
            anchors.fill: parent
            enabled: root.view === "rest" || root.view === "feedback"
            onClicked: function(mouse) {
              feedbackTimer.stop()
              if (root.notificationPill && root.notifications.last && root.notifications.last.islandUpdate) root.updateIsland()
              else if (root.notificationPill && root.notifications.last && root.notifications.last.islandSetupRetry) { root.feedbackKind = ""; root.view = "rest"; root.setup.install() }
              else if (root.notificationPill) root.dismissPillNotification()
              else if (root.clipboardPill) root.view = "clipboard"
              else if (root.activityPill) root.view = root.activities.current.kind === "bluetooth" ? "bluetooth"
                : root.activities.current.kind === "network" && !root.activities.current.wired ? "wifi" : "controls"
              else if (root.addonPill) root.addonPill.pillClicked()
              else if (root.recordingPill) root.recorder.stop()
              else if (root.view === "rest" && root.setup.needsSetup) root.setup.pillClicked()
              else if (root.downloadDone || (root.downloadActive && (mouse.x < 56 || mouse.x > width - 90))) root.openDownloads()
              else if (root.mediaPill && (mouse.x < 56 || mouse.x > width - 72)) root.view = "player"
              else if (root.osdPill) { root.feedbackTimer.stop(); root.feedbackKind = ""; root.view = "rest" }
              else root.view = "controls"
            }
          }

          NotificationPill { host: root; shape: island; anchors.fill: parent }

          VolumeSlider { host: root; anchors.fill: parent }

          OsdPill { host: root; anchors.fill: parent }

          ClipboardPill { host: root; anchors.fill: parent }

          DevicePill { host: root; anchors.fill: parent }

          WorkspacePill { host: root; anchors.fill: parent }

          AddonPills { host: root; anchors.fill: parent }

          RecordingPill { host: root; anchors.fill: parent }

          MediaPill { host: root; anchors.fill: parent }

          DownloadPill { host: root; anchors.fill: parent }

          IslandLabel { id: clockLabel; host: root; anchors.centerIn: parent }
          TextMetrics { id: clockMetrics; font: clockLabel.font; text: root.clockText }

          Views { id: views; host: root; anchors.fill: parent }
        }
        // A faint light edge around the open island, so its black still
        // reads against a dark wallpaper.
        Item {
          x: island.x
          y: island.y
          width: island.width
          height: island.height
          scale: island.scale
          opacity: root.surfaceOpen ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { MotionAnimation { theme: root.theme; pace: root.surfaceOpen ? "morph" : "exit"; curve: "fade" } }
          Shape {
            anchors.fill: parent
            anchors.margins: 0.5
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeWidth: 1
              strokeColor: root.theme.fill("raised")
              fillColor: "transparent"
              PathSvg { path: island.edgeOutline }
            }
          }
        }
      }
    }
  }
}
