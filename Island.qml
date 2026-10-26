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

  // The resting island's pills, highest first: a screen recording, an
  // addon's ongoing activity (see addonPill), a download or system update,
  // then the media playing. None shows while the companion needs setting up.
  readonly property bool resting: view === "rest" && !setup.needsSetup
  readonly property bool recordingPill: resting && settings.screenRecordingActivity && recorder.active
  readonly property bool restingFree: resting && !recordingPill && !addons.ongoing
  readonly property bool downloadDone: restingFree
    && (downloads.finishedName !== "" || packages.finishedTitle !== "")
  readonly property bool downloadActive: restingFree && (downloads.active || packages.active) && !downloadDone
  readonly property bool downloadPill: downloadDone || downloadActive
  readonly property bool mediaPill: restingFree && !downloadPill && nowPlaying.playing && settings.mediaPill
  // The live-activity pills' height, and the resting clock's.
  readonly property real pillHeight: settings.notch ? 40 : 44
  readonly property real clockHeight: clockStacked ? (settings.notch ? 40 : 42) : (settings.notch ? 36 : 40)

  readonly property var nowPlaying: nowPlayingData
  NowPlaying { id: nowPlayingData; shell: root.shell; theme: root.theme }
  readonly property var recorder: screenRecorder
  ScreenRecorder { id: screenRecorder }
  readonly property var downloads: downloadTracker
  DownloadTracker { id: downloadTracker; enabled: root.settings.downloads }
  readonly property var packages: packageTracker
  PackageUpdateTracker { id: packageTracker; enabled: root.settings.systemUpdates }
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
  readonly property var clockFormats: [
    "time", "stackedDay", "stackedDate", "stackedFull",
    "day", "date", "short", "weekday", "full", "numeric"
  ]
  function isStackedClock(format) {
    return format === "stackedDay" || format === "stackedDate" || format === "stackedFull"
  }
  readonly property bool clockStacked: isStackedClock(settings.clockFormat)
  function formatClockTime(date) {
    var en = Qt.locale("en_US")
    return settings.clock24h ? en.toString(date, "HH:mm")
      : settings.clockAmPm ? en.toString(date, "h:mm AP")
      : en.toString(date, "h:mm AP").replace(/\s*[AP]M$/i, "")
  }
  function formatClockSub(date, format) {
    var en = Qt.locale("en_US")
    switch (format) {
    case "stackedDay": return en.toString(date, "dddd")
    case "stackedDate": return en.toString(date, "d MMM")
    case "stackedFull": return en.toString(date, "ddd d MMM")
    default: return ""
    }
  }
  readonly property string clockTimeText: formatClockTime(clockDate)
  readonly property string clockSubText: formatClockSub(clockDate, settings.clockFormat)
  readonly property string clockWidestText: clockTimeText.length > clockSubText.length ? clockTimeText : clockSubText
  readonly property string clockText: formatClock(clockDate, settings.clockFormat)
  function formatClock(date, format) {
    var en = Qt.locale("en_US")
    var time = formatClockTime(date)
    switch (format) {
    case "stackedDay":
    case "stackedDate":
    case "stackedFull":
      return time + "\n" + formatClockSub(date, format)
    case "day": return en.toString(date, "ddd") + " " + time
    case "date": return en.toString(date, "d MMM") + " " + time
    case "short": return en.toString(date, "ddd d MMM") + " " + time
    case "weekday": return en.toString(date, "dddd") + " " + time
    case "full": return en.toString(date, "ddd d MMM yyyy") + " " + time
    case "numeric": return en.toString(date, "dd/MM/yyyy") + " " + time
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
    : resting && !recordingPill ? addons.ongoing : null

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

  readonly property var keyboard: keyboardLayout
  KeyboardLayout { id: keyboardLayout }

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

  function dismissFeedback() {
    feedbackTimer.stop()
    feedbackKind = ""
    view = "rest"
  }
  function dismissPillNotification() {
    var row = notifications.last
    dismissFeedback()
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
        // The tight one is the squircle itself, blurred: a rounded-rect
        // shadow would peek out where the squircle's corners ease in.
        Item {
          x: island.x
          y: island.y + 2
          width: island.width
          height: island.height
          scale: island.scale
          transformOrigin: island.transformOrigin
          opacity: root.surfaceOpen ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { MotionAnimation { theme: root.theme; pace: root.surfaceOpen ? "morph" : "exit"; curve: "fade" } }
          layer.enabled: visible
          layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: 1 }
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeWidth: -1
              fillColor: Qt.rgba(0, 0, 0, 0.4)
              PathSvg { path: island.outline }
            }
          }
        }
        IslandShadow { shape: island; offset.y: 14; blur: 48; spread: -4; color: Qt.rgba(0, 0, 0, 0.6) }

        NotchEar { shape: island }
        NotchEar { shape: island; mirrored: true }

        Rectangle {
          id: island
          x: (parent.width - width) / 2
          // On a spring like the shape, so hiding and showing again quickly
          // turns around smoothly.
          MotionSpring { id: ySpring; theme: root.theme; pace: "standard"; target: window.islandHidden ? -island.height - 20 : root.settings.notch ? 0 : 8 }
          y: ySpring.value
          readonly property Item activeSurface: views.surfaceFor(root.view)
          readonly property Item activePill: pills.active
          readonly property bool glanceHovered: clockHover.hovered || islandPointerHover.hovered
          property bool glanceActive: false
          Timer {
            id: glanceLeaveTimer
            interval: 180
            onTriggered: island.glanceActive = false
          }
          onGlanceHoveredChanged: {
            if (glanceHovered) {
              glanceLeaveTimer.stop()
              if (root.settings.hoverExpand && root.restingFree && !root.downloadPill) island.glanceActive = true
            } else {
              glanceLeaveTimer.restart()
            }
          }
          Connections {
            target: root
            function onViewChanged() {
              if (root.view !== "rest") {
                island.glanceActive = false
                glanceLeaveTimer.stop()
              }
            }
          }
          readonly property bool isGlanceExpanded: island.glanceActive && root.settings.hoverExpand && root.restingFree && !root.downloadPill
          // How much wider than a bare time the chosen clock format is; the
          // resting pill and the pills that keep the clock in the middle grow by it.
          readonly property real clockExtra: Math.max(0, Math.ceil(clockLabel.advanceWidth || clockMetrics.advanceWidth) + 56 - 100)
          readonly property real baseGlanceWidth: root.settings.notch ? 420 : 440
          readonly property real glanceWidth: baseGlanceWidth + clockExtra
          readonly property real targetWidth: activeSurface ? activeSurface.islandWidth
            : island.isGlanceExpanded ? island.glanceWidth
            : activePill ? activePill.pillWidth + (activePill.keepsClock ? clockExtra : 0)
            : root.view === "feedback" ? 280
            : root.setup.needsSetup ? (root.setup.warning.length > 24 ? 320 : 250)
            : 100 + clockExtra
          readonly property real targetHeight: activeSurface ? activeSurface.islandHeight
            : activePill ? activePill.pillHeight
            : root.view === "rest" ? root.clockHeight : 52
          readonly property real targetRadius: activeSurface && activeSurface.cornerRadius > 0 ? activeSurface.cornerRadius
            : activePill && activePill.pillRadius > 0 ? activePill.pillRadius
            : root.surfaceOpen ? 30 : 38
          readonly property real radiusCap: radiusSpring.value
          radius: Math.min(height / 2, root.settings.notch && !root.surfaceOpen ? Math.min(radiusCap, 16) : radiusCap)
          topLeftRadius: root.settings.notch ? 0 : radius
          topRightRadius: root.settings.notch ? 0 : radius
          readonly property bool lifted: root.view === "rest" && clockHover.hovered && !root.settings.notch && !island.isGlanceExpanded
          // Lifts a touch under the pointer and squishes while pressed, then
          // springs back past its size on release, like the iPhone's island.
          // The springs run in hundredths, as they settle to a tenth of a unit.
          readonly property bool squished: islandTap.pressed || squishHold.running
          Timer { id: squishHold; interval: root.theme.motionDuration("press") }
          MotionSpring { id: liftSpring; theme: root.theme; pace: "quick"; target: island.lifted ? 100 : 0 }
          MotionSpring {
            id: pressSpring
            theme: root.theme
            pace: island.squished ? "press" : "standard"
            bounce: island.squished ? 0 : 0.35
            target: island.squished ? 100 : 0
          }
          scale: 1 + liftSpring.value * 0.00018 - pressSpring.value * 0.0003
          // With the notch the island hangs from the top edge, so it scales from there.
          transformOrigin: root.settings.notch ? Item.Top : Item.Center
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
          // inside the shape. Only built while the edge shows, so a resting
          // pill's morphs redraw one outline, not two.
          readonly property string edgeOutline: !islandEdge.visible ? "" : Squircle.path(width - 1, height - 1, ({
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
          // height follows a beat later, each swinging a touch past its size
          // as the Dynamic Island does; shrinking, the height goes first. A
          // pill shrinking back (an activity ending) dips a little under its
          // size before it settles, a shrug; closing a view lands flat.
          readonly property string morphPace: root.surfaceOpen ? "morph" : "collapse"
          MotionSpring { id: widthSpring; theme: root.theme; pace: island.morphPace }
          MotionSpring { id: heightSpring; theme: root.theme; pace: island.morphPace }
          MotionSpring { id: radiusSpring; theme: root.theme; pace: island.morphPace; target: island.targetRadius }
          Timer { id: widthLag; interval: root.theme.morphLag; onTriggered: widthSpring.target = island.targetWidth }
          Timer { id: heightLag; interval: root.theme.morphLag; onTriggered: heightSpring.target = island.targetHeight }
          // A view settles its height over a few frames as it lays out; a
          // lag already counting keeps counting and lands on the latest
          // size, so the height still trails the width by one beat.
          readonly property bool shrugs: !root.surfaceOpen && heightSpring.value <= 120
          onTargetWidthChanged: {
            widthSpring.bounce = targetWidth > widthSpring.value ? root.theme.morphBounce : shrugs ? root.theme.shrugBounce : 0
            if (targetWidth < widthSpring.value) { if (!widthLag.running) widthLag.start(); return }
            widthLag.stop()
            widthSpring.target = targetWidth
          }
          onTargetHeightChanged: {
            heightSpring.bounce = targetHeight > heightSpring.value ? root.theme.morphBounce : shrugs ? root.theme.shrugBounce : 0
            if (targetHeight > heightSpring.value) { if (!heightLag.running) heightLag.start(); return }
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
            id: islandTap
            anchors.fill: parent
            enabled: root.view === "rest" || root.view === "feedback"
            onPressed: squishHold.restart()
            onClicked: function(mouse) {
              feedbackTimer.stop()
              if (island.activePill) island.activePill.clicked(mouse)
              else if (root.view === "rest" && root.setup.needsSetup) root.setup.pillClicked()
              else root.view = "controls"
            }
          }

          // The live activities (see IslandPill); at most one is shown at a time.
          Item {
            id: pills
            anchors.fill: parent
            readonly property Item active: {
              for (var i = 0; i < children.length; i++) if (children[i].shown) return children[i]
              return null
            }
            NotificationPill { host: root; shape: island; anchors.fill: parent }
            VolumeSlider { host: root; anchors.fill: parent }
            OsdPill { host: root; anchors.fill: parent }
            ClipboardPill { host: root; anchors.fill: parent }
            DevicePill { host: root; anchors.fill: parent }
            WorkspacePill { host: root; anchors.fill: parent }
            AddonPills { host: root; anchors.fill: parent }
            RecordingPill { host: root; anchors.fill: parent }
            MediaPill { host: root; shape: island; anchors.fill: parent }
            DownloadPill { host: root; anchors.fill: parent }
          }

          GlanceBar {
            id: glanceBar
            host: root
            shown: island.isGlanceExpanded
            clockWidth: Math.max(clockLabel.width, clockLabel.advanceWidth || clockMetrics.advanceWidth)
            anchors.fill: parent
          }
          IslandLabel { id: clockLabel; host: root; pill: island.activePill; anchors.centerIn: parent }
          TextMetrics { id: clockMetrics; font: clockLabel.font; text: root.clockStacked ? root.clockWidestText : root.clockText }

          Views { id: views; host: root; anchors.fill: parent }
        }
        // A faint light edge around the open island, so its black still
        // reads against a dark wallpaper; fainter on the resting pill while
        // it's lifted under the pointer.
        Item {
          id: islandEdge
          x: island.x
          y: island.y
          width: island.width
          height: island.height
          scale: island.scale
          transformOrigin: island.transformOrigin
          opacity: root.surfaceOpen ? 1 : (island.lifted || island.isGlanceExpanded) ? 0.6 : 0
          visible: opacity > 0.01
          Behavior on opacity { MotionAnimation { theme: root.theme; pace: root.surfaceOpen || island.lifted || island.isGlanceExpanded ? "morph" : "exit"; curve: "fade" } }
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

  // A shadow under the island, there while a view is open.
  component IslandShadow: RectangularShadow {
    required property Item shape
    x: shape.x
    y: shape.y
    width: shape.width
    height: shape.height
    radius: shape.radius
    opacity: root.surfaceOpen ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: root.theme; pace: root.surfaceOpen ? "morph" : "exit"; curve: "fade" } }
  }

  // With the notch, a concave corner either side of the island where it
  // meets the top edge; `mirrored` is the right one.
  component NotchEar: Shape {
    id: ear
    required property Item shape
    property bool mirrored: false
    readonly property real r: 10
    visible: root.settings.notch && shape.y > -r
    x: mirrored ? shape.x + shape.width : shape.x - r
    y: shape.y
    width: r
    height: r
    // Drawn as the island is, so the two edges antialias alike where they meet.
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: -1
      fillColor: root.theme.background
      PathSvg {
        readonly property real r: ear.r
        path: ear.mirrored ? "M 0 0 L 0 " + r + " A " + r + " " + r + " 0 0 1 " + r + " 0 Z"
          : "M " + r + " 0 L " + r + " " + r + " A " + r + " " + r + " 0 0 0 0 0 Z"
      }
    }
  }
}
