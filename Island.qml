import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
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
  // The switchers (Picker.qml) are keyboard-driven surfaces.
  readonly property bool pickerOpen: view === "themes" || view === "wallpapers"
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

  function notificationIconSource(row) {
    if (!row) return ""
    var value = String(row.image || row.appIcon || "")
    if (value === "") return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return "file://" + value
    return Quickshell.iconPath(value, true)
  }

  // surfaceOpen itself may not have re-evaluated yet inside onViewChanged.
  function surfaceOpenFor(v) { return v === "controls" || v === "themes" || v === "wallpapers" }

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
        WlrLayershell.keyboardFocus: root.pickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
          width: picker ? 820
            : root.view === "controls" ? 470
            : root.notificationPill ? 400
            : root.volumePill ? 230
            : root.view === "feedback" ? 280
            : root.companionNeedsSetup ? 250
            : 110
          height: picker ? picker.implicitHeight + 40
            : root.view === "controls" ? Math.min(controlCenter.implicitHeight + 32, 780)
            : root.notificationPill ? 76
            : root.volumePill ? 44
            : root.view === "rest" ? 40 : 52
          // Pills stay fully round at every frame of the morph because the
          // radius tracks the animated height; only the cap for the large
          // surfaces animates, and its target changes once per view switch.
          property real radiusCap: root.surfaceOpen ? 30 : 38
          Behavior on radiusCap {
            NumberAnimation { duration: 390 * root.motionScale; easing.type: Easing.OutQuint }
          }
          radius: Math.min(height / 2, radiusCap)
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

          Item {
            id: notificationPillContent
            readonly property var row: root.lastNotification || ({})
            readonly property string iconSource: root.notificationIconSource(root.lastNotification)
            anchors.fill: parent
            opacity: root.notificationPill ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * root.motionScale; easing.type: Easing.InOutQuad } }

            ClippingRectangle {
              id: appTile
              anchors.left: parent.left
              anchors.leftMargin: 13
              anchors.verticalCenter: parent.verticalCenter
              // Grows with the pill so it never pokes past the rounded ends.
              width: height
              height: Math.max(0, Math.min(50, island.height - 26))
              radius: height * 0.28
              color: "transparent"
              Rectangle {
                anchors.fill: parent
                visible: appTileImage.status !== Image.Ready
                gradient: Gradient {
                  GradientStop { position: 0; color: Qt.lighter(root.colorAccent, 1.25) }
                  GradientStop { position: 1; color: root.colorAccent }
                }
              }
              Image {
                id: appTileImage
                anchors.fill: parent
                source: notificationPillContent.iconSource
                sourceSize.width: 100
                sourceSize.height: 100
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
              }
              Text {
                anchors.centerIn: parent
                visible: appTileImage.status !== Image.Ready
                text: String(notificationPillContent.row.glyph || "") || "󰂚"
                color: root.colorAccentText
                font.family: root.fontFamily
                font.pixelSize: 24
              }
            }

            Column {
              anchors.left: appTile.right
              anchors.leftMargin: 14
              anchors.right: parent.right
              anchors.rightMargin: 26
              anchors.verticalCenter: parent.verticalCenter
              spacing: 3
              Text {
                width: parent.width
                text: String(notificationPillContent.row.summary || notificationPillContent.row.app || "Notification")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.colorText
                font.pixelSize: 16
                font.weight: Font.DemiBold
              }
              Text {
                width: parent.width
                text: String(notificationPillContent.row.body || notificationPillContent.row.app || "")
                visible: text !== ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.colorMuted
                font.pixelSize: 13
              }
            }
          }

          // Apple-style volume HUD: speaker glyph and a thick level bar, no
          // numbers. The glyph pops on every change and the bar springs to
          // the new level.
          Item {
            id: volumePillContent
            readonly property real level: root.muted ? 0 : Math.max(0, Math.min(1, root.volume))
            // Animate the level, not the pixel width, so the bar doesn't
            // restart its spring every frame while the pill itself morphs.
            property real shownLevel: level
            Behavior on shownLevel {
              NumberAnimation { duration: 260 * root.motionScale; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 18
            opacity: root.volumePill ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * root.motionScale; easing.type: Easing.InOutQuad } }

            Connections {
              target: root
              function onVolumeChanged() { if (root.volumePill) volumePop.restart() }
              function onMutedChanged() { if (root.volumePill) volumePop.restart() }
            }

            Text {
              id: volumeIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: 22
              horizontalAlignment: Text.AlignHCenter
              text: root.muted || volumePillContent.level <= 0 ? "󰖁" : volumePillContent.level < 0.34 ? "󰕿" : volumePillContent.level < 0.67 ? "󰖀" : "󰕾"
              color: root.colorText
              opacity: root.muted ? 0.6 : 1
              font.family: root.fontFamily
              font.pixelSize: 19
              SequentialAnimation {
                id: volumePop
                NumberAnimation { target: volumeIcon; property: "scale"; to: 1.18; duration: 70; easing.type: Easing.OutQuad }
                NumberAnimation { target: volumeIcon; property: "scale"; to: 1; duration: 220 * root.motionScale; easing.type: Easing.OutBack }
              }
            }
            Rectangle {
              anchors.left: volumeIcon.right
              anchors.leftMargin: 12
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: 8
              radius: 4
              color: root.withAlpha(root.colorText, 0.2)
              Rectangle {
                height: parent.height
                radius: parent.radius
                width: Math.max(root.muted ? 0 : height, parent.width * Math.max(0, Math.min(1, volumePillContent.shownLevel)))
                color: root.colorText
              }
            }
          }

          Text {
            anchors.centerIn: parent
            opacity: !root.notificationPill && !root.volumePill && (root.view === "rest" || root.view === "feedback") ? 1 : 0
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            // Notifications have their own layout; don't flash their text in
            // this label while it fades out.
            text: root.view === "feedback" && !root.notificationPill && !root.volumePill ? root.feedback
              : root.companionNeedsSetup ? "󰀦  " + root.companionWarning
              : Qt.formatDateTime(clock.date, "HH:mm")
            color: root.view === "rest" && root.companionNeedsSetup ? root.colorUrgent : root.colorText
            // Adwaita Sans (Inter-based) at semibold, like the iOS status
            // clock; tabular figures keep the digits from shifting as the
            // time changes.
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            // Get out of the way fast, fade back in gently.
            Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * root.motionScale; easing.type: Easing.InOutQuad } }
          }

          ThemeSwitcher {
            id: themeSwitcher
            host: root
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
          }

          WallpaperSwitcher {
            id: wallpaperSwitcher
            host: root
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
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
