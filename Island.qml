import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Commons

Item {
  id: root
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property var barConfig: ({})
  property string omarchyPath: ""

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
  readonly property string feedPath: home + "/.local/state/omarchy/island-feed.json"
  readonly property string historyDir: home + "/.local/state/omarchy/notifications/history/"
  // Active theme's folder name; shared by the theme and wallpaper switchers.
  property string themeName: ""

  readonly property var clockDate: clock.date
  property string view: "rest"
  // Notification arrivals use the Dynamic Island layout: app icon tile,
  // title, and one line of body.
  readonly property bool notificationPill: view === "feedback" && feedbackKind === "notification"
  // Volume changes use an icon + level bar + percentage layout.
  readonly property bool volumePill: view === "feedback" && feedbackKind === "volume"

  property bool surfaceContentReady: false
  property string feedback: ""
  property string feedbackKind: ""
  property var activeNotifications: []
  // Latest notification snapshot, shown by the notification pill.
  property var lastNotification: null
  // Keyboard-driven surfaces: the switchers (Picker.qml), the launcher, and
  // the power menu.
  readonly property bool pickerOpen: view === "themes" || view === "wallpapers" || view === "apps" || view === "power"
  readonly property bool surfaceOpen: view === "controls" || pickerOpen
  property var history: []
  property string lastNotificationKey: ""
  property bool initialized: false
  property bool barHidden: false
  readonly property int barSize: 0
  readonly property string position: "top"
  readonly property string fontFamily: "monospace"
  // Palette. The island itself is always black; text and accents come from
  // the current Omarchy theme, and Color reloads on theme switches, so
  // everything bound to these follows along live. Light themes have dark
  // foregrounds, so their (light) background color is used as text instead.
  readonly property color colorBackground: "#000000"
  readonly property bool themeTextIsLight: luminance(Color.foreground) > 0.5
  readonly property color colorText: themeTextIsLight ? Color.foreground : Color.background
  readonly property color colorMuted: themeTextIsLight ? Color.muted : withAlpha(colorText, 0.6)
  readonly property color colorAccent: Color.accent
  readonly property color colorAccentText: contrastOn(Color.accent)
  readonly property color colorUrgent: Color.urgent
  // Raised surfaces (tiles, cards) and their hover state: the text color
  // washed faintly over the background.
  readonly property color colorSurface: Qt.tint(colorBackground, withAlpha(colorText, 0.07))
  readonly property color colorSurfaceHover: Qt.tint(colorBackground, withAlpha(colorText, 0.12))

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  // Background or text color, whichever reads better on top of `c`.
  function luminance(x) { return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b }
  function contrastOn(c) {
    var l = luminance(c)
    return Math.abs(l - luminance(colorBackground)) > Math.abs(l - luminance(colorText)) ? colorBackground : colorText
  }

  // Multiplies every animation duration below; raise to slow the island down.
  readonly property real motionScale: 2

  // The notification's own image, else its app icon. `appIconOnly` skips
  // the image: a live image handle dies with the shell, so a notification
  // restored after a restart falls back to its app icon.
  function notificationIconSource(row, appIconOnly) {
    if (!row) return ""
    var value = String((appIconOnly ? "" : row.image) || row.appIcon || "")
    if (value === "") return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return "file://" + value
    return Quickshell.iconPath(value, true)
  }

  // surfaceOpen itself may not have re-evaluated yet inside onViewChanged.
  function surfaceOpenFor(v) { return v === "controls" || v === "themes" || v === "wallpapers" || v === "apps" || v === "power" }

  FileView {
    path: root.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeName = text().trim()
    onFileChanged: reload()
  }

  onViewChanged: {
    surfaceContentReady = false
    if (surfaceOpenFor(view)) surfaceRevealTimer.restart()
    else surfaceRevealTimer.stop()
    if (view === "controls") refreshHistory()
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

  onVolumeChanged: {
    if (initialized && volume >= 0) showFeedback("", 1800, "volume")
  }
  onMutedChanged: {
    if (initialized && volume >= 0) showFeedback("", 1800, "volume")
  }
  Component.onCompleted: {
    initialized = true
    companionCheck.running = true
  }

  // The notification server lives in the separate guilhermerisu.notifications
  // companion (see README). Check it on load; the resting pill turns into a
  // one-click installer when it's missing, stale, or not enabled.
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string companionDir: pluginDir + "/companion"
  property string companionStatus: ""
  property bool companionInstalling: false
  readonly property bool companionNeedsSetup: companionStatus !== "" && companionStatus !== "ok"
  readonly property string companionWarning: companionInstalling ? "Installing notifications…"
    : companionStatus === "missing" ? "Set up notifications"
    : companionStatus === "outdated" ? "Update notifications"
    : companionStatus === "not-enabled" ? "Enable notifications"
    : companionStatus === "menu" ? "Set up switchers"
    : "Notifications need setup"

  Process {
    id: companionCheck
    command: ["bash", root.companionDir + "/check.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.companionStatus = String(text || "").trim()
    }
  }

  function installCompanion() {
    if (companionInstall.running) return
    companionInstalling = true
    companionInstall.command = ["bash", companionDir + "/install.sh"]
    companionInstall.running = true
  }
  Process {
    id: companionInstall
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text) console.warn("island: companion install:", text) }
    // On success the shell restarts; on failure recheck so the pill stays honest.
    onExited: function(code) {
      root.companionInstalling = false
      companionCheck.running = true
    }
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
    interval: 90 * root.motionScale
    repeat: false
    onTriggered: root.surfaceContentReady = true
  }

  FileView {
    id: feedFile
    path: root.feedPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadFeed(text())
    onFileChanged: reload()
  }

  function loadFeed(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      var rows = Array.isArray(parsed.active) ? parsed.active : []
      activeNotifications = rows
      if (view === "controls") refreshHistory()
      if (!rows.length) return
      var current = rows[0]
      var key = String(current.timestamp) + ":" + String(current.originalId)
      if (key === lastNotificationKey) return
      lastNotificationKey = key
      lastNotification = current
      if (!surfaceOpen) showFeedback(String(current.summary || current.app || "Notification"), 5000, "notification")
    } catch (e) {
      console.warn("island: notification feed parse failed", e)
    }
  }

  Process {
    id: historyProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadHistory(text)
    }
  }

  function refreshHistory() {
    if (historyProc.running) return
    historyProc.command = ["bash", "-c", "awk 1 \"$1\"/*.json 2>/dev/null || true", "--", historyDir]
    historyProc.running = true
  }

  function loadHistory(raw) {
    var rows = []
    for (var j = 0; j < activeNotifications.length; j++) {
      var active = Object.assign({}, activeNotifications[j])
      active.isActive = true
      rows.push(active)
    }
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].trim()) continue
      try { rows.push(JSON.parse(lines[i])) } catch (e) { }
    }
    rows.sort(function(a, b) { return Number(b.timestamp || 0) - Number(a.timestamp || 0) })
    history = rows.slice(0, 10)
  }

  function notificationKey(row) {
    return String(row.timestamp) + ":" + String(row.originalId)
  }

  function notificationCommand(method, row) {
    notificationProc.command = ["omarchy-shell", "notifications", method, notificationKey(row)]
    notificationProc.running = true
  }
  Process { id: notificationProc; running: false; onExited: root.refreshHistory() }

  function dismissPillNotification() {
    var row = lastNotification
    feedbackKind = ""
    view = "rest"
    if (row) notificationCommand("dismissKey", row)
  }

  function clearAllNotifications() {
    history = []
    notificationProc.command = ["bash", "-c", "omarchy-shell notifications dismissAll; omarchy-shell notifications clear"]
    notificationProc.running = true
  }

  // Active rows go through the service; archived rows are plain files in the
  // history dir, named <timestamp>-<originalId>.json like their image copies.
  function dismissNotification(row) {
    var key = notificationKey(row)
    history = history.filter(function(r) { return notificationKey(r) !== key })
    if (row.isActive) {
      notificationProc.command = ["omarchy-shell", "notifications", "dismissKey", key]
    } else {
      var stem = String(row.timestamp) + "-" + String(row.originalId)
      notificationProc.command = ["bash", "-c", "rm -f \"$1/$2.json\" \"$1/../images/$2\"-*", "--", historyDir, stem]
    }
    notificationProc.running = true
  }

  function toggleView(name) {
    view = view === name ? "rest" : name
    return view
  }

  IpcHandler {
    target: "guilhermerisu.island"
    function toggle(): string { return root.toggleView("controls") }
    function themes(): string { return root.toggleView("themes") }
    function wallpapers(): string { return root.toggleView("wallpapers") }
    function apps(): string { return root.toggleView("apps") }
    function power(): string { return root.toggleView("power") }
    function companionStatus(): string { return root.companionStatus }
    function installCompanion(): string {
      root.installCompanion()
      return "installing"
    }
    // Kept for existing bindings; notifications now live in the control center.
    function showHistory(): string {
      root.view = "controls"
      return root.view
    }
    function close(): string {
      root.view = "rest"
      return "rest"
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: window
        required property var modelData
        screen: modelData
        visible: !root.barHidden && modelData.name === root.outputName
        color: "transparent"
        surfaceFormat.opaque: false
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true }
        implicitHeight: 800
        WlrLayershell.namespace: "omarchy-island"
        WlrLayershell.layer: WlrLayer.Overlay
        // Only the switchers type; everything else stays click-only.
        // The switchers, launcher, power menu, and control center (Esc) take
        // the keyboard while open; the resting island stays click-only.
        WlrLayershell.keyboardFocus: root.pickerOpen || root.view === "controls"
          ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { item: island }

        // Clicking anywhere outside the island clears the grab and closes it.
        HyprlandFocusGrab {
          id: focusGrab
          windows: [window]
          // Armed a beat after the surface opens: the theme switcher switches
          // the layer to exclusive keyboard focus, and a grab taken in the same
          // frame is cleared by that focus change.
          property bool armed: false
          active: window.visible && root.surfaceOpen && armed
          onCleared: if (root.surfaceOpen) root.view = "rest"
        }
        Timer {
          interval: 120
          running: root.surfaceOpen
          onTriggered: focusGrab.armed = true
        }
        Connections {
          target: root
          function onSurfaceOpenChanged() { if (!root.surfaceOpen) focusGrab.armed = false }
        }

        Rectangle {
          id: island
          x: (parent.width - width) / 2
          y: 8
          readonly property Item picker: root.view === "themes" ? themeSwitcher
            : root.view === "wallpapers" ? wallpaperSwitcher : null
          width: root.view === "apps" ? 600
            : root.view === "power" ? powerMenu.implicitWidth + 36
            : picker ? 820
            : root.view === "controls" ? 470
            : root.notificationPill ? 440
            : root.volumePill ? 240
            : root.view === "feedback" ? 280
            : root.companionNeedsSetup ? 250
            : 100
          height: root.view === "apps" ? appLauncher.implicitHeight + 32
            : root.view === "power" ? powerMenu.implicitHeight + 36
            : picker ? picker.implicitHeight + 40
            : root.view === "controls" ? Math.min(controlCenter.implicitHeight + 32, 780)
            : root.notificationPill ? 84
            : root.volumePill ? 56
            : root.view === "rest" ? 40 : 52
          // Pills stay fully round at every frame of the morph because the
          // radius tracks the animated height; only the cap for the large
          // surfaces animates, and its target changes once per view switch.
          // The volume slider uses iOS's squircle-ish corners, not a pill.
          property real radiusCap: root.volumePill ? 20 : root.surfaceOpen ? 30 : 38
          Behavior on radiusCap {
            NumberAnimation { duration: 390 * root.motionScale; easing.type: Easing.OutQuint }
          }
          radius: Math.min(height / 2, radiusCap)
          // Hovering the resting clock pill gives it a small springy lift.
          scale: root.view === "rest" && clockHover.hovered ? 1.07 : 1
          Behavior on scale { NumberAnimation { duration: 240 * root.motionScale; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
          HoverHandler { id: clockHover; enabled: root.view === "rest" }
          color: root.colorBackground
          clip: true
          Behavior on width {
            NumberAnimation {
              duration: 390 * root.motionScale
              easing.type: Easing.OutQuint
            }
          }
          Behavior on height {
            NumberAnimation {
              duration: 390 * root.motionScale
              easing.type: Easing.OutQuint
            }
          }
          Behavior on color { ColorAnimation { duration: 240 * root.motionScale; easing.type: Easing.InOutQuad } }

          MouseArea {
            anchors.fill: parent
            enabled: root.view === "rest" || root.view === "feedback"
            onClicked: {
              feedbackTimer.stop()
              if (root.notificationPill) root.dismissPillNotification()
              else if (root.view === "rest" && root.companionNeedsSetup) root.installCompanion()
              else root.view = "controls"
            }
          }

          NotificationPill { host: root; shape: island; anchors.fill: parent }

          VolumeSlider { host: root; shape: island; anchors.fill: parent }

          IslandLabel { host: root; anchors.centerIn: parent }

          ThemeSwitcher {
            id: themeSwitcher
            host: root
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
          }

          AppLauncher {
            id: appLauncher
            host: root
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
          }

          WallpaperSwitcher {
            id: wallpaperSwitcher
            host: root
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
          }

          PowerMenu {
            id: powerMenu
            host: root
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
          }

          ControlCenter {
            id: controlCenter
            host: root
            active: root.view === "controls"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            visible: root.view === "controls" || opacity > 0.01
            enabled: root.view === "controls" && root.surfaceContentReady
            opacity: root.view === "controls" && root.surfaceContentReady ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: (root.surfaceContentReady ? 190 : 110) * root.motionScale; easing.type: Easing.InOutQuad } }
          }
        }
      }
    }
  }
}
