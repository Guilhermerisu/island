import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets

Item {
  id: root
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property var barConfig: ({})
  property string omarchyPath: ""

  readonly property var media: shell ? shell.firstPartyServiceFor("omarchy.media") : null
  readonly property var player: media ? media.activePlayer : null
  readonly property string title: player ? String(player.trackTitle || "") : ""
  readonly property string artist: player ? String(player.trackArtist || "") : ""
  readonly property real volume: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
    ? Pipewire.defaultAudioSink.audio.volume : -1
  readonly property string wantedOutput: String(barConfig.output || "DP-1")
  readonly property string outputName: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === wantedOutput) return wantedOutput
    var focused = Hyprland.focusedMonitor
    if (focused && focused.name) return String(focused.name)
    return screens.length ? String(screens[0].name) : ""
  }
  readonly property string feedPath: Quickshell.env("HOME") + "/.local/state/omarchy/island-feed.json"
  readonly property string historyDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history/"

  readonly property var clockDate: clock.date
  property string view: "rest"
  // Notification arrivals use the Dynamic Island layout: app icon tile,
  // title, and one line of body.
  readonly property bool notificationPill: view === "feedback" && feedbackKind === "notification"

  property bool surfaceContentReady: false
  property string feedback: ""
  property string feedbackKind: ""
  property var activeNotifications: []
  // Latest notification snapshot, shown by the notification pill.
  property var lastNotification: null
  readonly property bool surfaceOpen: view === "controls"
  property var history: []
  property string lastNotificationKey: ""
  property bool initialized: false
  property bool barHidden: false
  readonly property int barSize: 0
  readonly property string position: "top"
  readonly property string fontFamily: "monospace"
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

  onViewChanged: {
    surfaceContentReady = false
    if (view === "controls") {
      surfaceRevealTimer.restart()
      refreshHistory()
    } else surfaceRevealTimer.stop()
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
    if (initialized && volume >= 0) showFeedback("Volume  " + Math.round(volume * 100) + "%", 1800, "volume")
  }
  Component.onCompleted: {
    initialized = true
    companionCheck.running = true
  }

  // The notification server lives in the separate guilhermerisu.notifications
  // companion (see README). Check it on load; the resting pill turns into a
  // one-click installer when it's missing, stale, or not enabled.
  readonly property string companionDir: String(Qt.resolvedUrl("companion")).replace(/^file:\/\//, "")
  property string companionStatus: ""
  property bool companionInstalling: false
  readonly property bool companionNeedsSetup: companionStatus !== "" && companionStatus !== "ok"
  readonly property string companionWarning: companionInstalling ? "Installing notifications…"
    : companionStatus === "missing" ? "Set up notifications"
    : companionStatus === "outdated" ? "Update notifications"
    : companionStatus === "not-enabled" ? "Enable notifications"
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

  IpcHandler {
    target: "guilhermerisu.island"
    function toggle(): string {
      root.view = root.view === "controls" ? "rest" : "controls"
      return root.view
    }
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: island }

        // Clicking anywhere outside the island clears the grab and closes it.
        HyprlandFocusGrab {
          windows: [window]
          active: window.visible && root.surfaceOpen
          onCleared: if (root.surfaceOpen) root.view = "rest"
        }

        Rectangle {
          id: island
          x: (parent.width - width) / 2
          y: 8
          width: root.view === "controls" ? 470
            : root.notificationPill ? 400
            : root.view === "feedback" ? 280
            : root.companionNeedsSetup ? 250
            : 110
          height: root.view === "controls" ? Math.min(controlCenter.implicitHeight + 32, 780)
            : root.notificationPill ? 76
            : root.view === "rest" ? 40 : 52
          // Pills stay fully round at every frame of the morph because the
          // radius tracks the animated height; only the cap for the large
          // surfaces animates, and its target changes once per view switch.
          property real radiusCap: root.view === "controls" ? 30 : 38
          Behavior on radiusCap {
            NumberAnimation { duration: 390 * root.motionScale; easing.type: Easing.OutQuint }
          }
          radius: Math.min(height / 2, radiusCap)
          color: "#000000"
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
                  GradientStop { position: 0; color: "#8f8cf5" }
                  GradientStop { position: 1; color: "#5b57d9" }
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
                color: "#ffffff"
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
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.DemiBold
              }
              Text {
                width: parent.width
                text: String(notificationPillContent.row.body || notificationPillContent.row.app || "")
                visible: text !== ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: "#9b9ba3"
                font.pixelSize: 13
              }
            }
          }

          Text {
            anchors.centerIn: parent
            opacity: !root.notificationPill && (root.view === "rest" || root.view === "feedback") ? 1 : 0
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            // Notifications have their own layout; don't flash their text in
            // this label while it fades out.
            text: root.view === "feedback" && !root.notificationPill ? root.feedback
              : root.companionNeedsSetup ? "󰀦  " + root.companionWarning
              : Qt.formatDateTime(clock.date, "HH:mm")
            color: root.view === "rest" && root.companionNeedsSetup ? "#f5c26b" : "#f2f2f4"
            font.family: root.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            // Get out of the way fast, fade back in gently.
            Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * root.motionScale; easing.type: Easing.InOutQuad } }
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
