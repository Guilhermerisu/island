import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../views/control-center"
import "../addons/weather"

// Hovering the resting island splits what a bar shows into black capsules
// beside it. Out from the island, the next event, tray apps with pending
// Omarchy updates, and workspaces on the left; the weather, notifications,
// and Bluetooth, network, sound and battery on the right. Each can be turned
// off in Settings, and one with nothing to show stays away. The connections,
// sound and battery come from the control center's Controls, so both agree.
Item {
  id: capsules
  required property var host
  // The island the capsules flank and follow.
  required property Item island
  property bool shown: false
  readonly property bool hovered: leftHover.hovered || rightHover.hovered
  // For the window's input mask.
  readonly property Item leftGroup: leftRow
  readonly property Item rightGroup: rightRow

  readonly property var theme: host.theme
  readonly property var settings: host.settings
  readonly property real gap: 6
  // The island's height, up to a live activity's, so they match the clock
  // and those pills and stay capsules beside the taller ones.
  readonly property real capsuleHeight: Math.min(island.height, host.pillHeight)
  readonly property bool notch: settings.notch
  // Centred on the island, or hanging from the top edge with the notch.
  readonly property real capsuleY: notch ? island.y : island.y + (island.height - capsuleHeight) / 2
  // One size for every icon and one for every label, across all capsules.
  readonly property int glyphSize: theme.px(18)
  readonly property int traySize: 16
  readonly property int textSize: theme.px(13)
  readonly property color ink: "#e2e6de"
  readonly property color faint: Qt.rgba(0.89, 0.90, 0.87, 0.4)

  Controls { id: controls; host: capsules.host }
  // The history is only read while it's on screen; the count needs it fresh.
  onShownChanged: if (shown) host.notifications.refreshHistory()

  // --- Next event: today's, from an hour before it starts until it ends ---
  readonly property var calendar: host.addons.isEnabled("calendar") ? host.addons.root("calendar") : null
  readonly property var nextEvent: calendar ? calendar.nextToday : null
  readonly property real eventIn: nextEvent ? nextEvent.start - host.clockDate.getTime() : 0
  readonly property string eventWhen: eventIn <= 0 ? "now"
    : "in " + Math.max(1, Math.round(eventIn / 60000)) + " min"
  readonly property bool showEvent: settings.capsuleEvent && !!nextEvent && eventIn <= 60 * 60000

  // --- Tray apps, straight from the system tray, and pending updates ---
  readonly property var trayItems: settings.capsuleTray
    ? SystemTray.items.values.filter(function(item) { return item.status !== Status.Passive })
    : []
  property bool updateAvailable: false
  readonly property bool showUpdate: settings.capsuleTray && updateAvailable
  readonly property bool showTray: trayItems.length > 0 || showUpdate
  // Checked like Omarchy's bar does: on start and every six hours.
  Process {
    id: updateCheck
    command: ["omarchy-update-available"]
    onExited: function(code) { capsules.updateAvailable = code === 0 }
  }
  Timer {
    interval: 6 * 3600 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!updateCheck.running) updateCheck.running = true
  }
  // A tray app's own menu in the tray view, or the whole tray when it has none.
  function openTrayMenu(item) {
    host.trayMenuFor = item.hasMenu && item.menu ? item : null
    host.view = "trayMenu"
  }

  // --- Workspaces ---
  readonly property bool showWorkspaces: settings.capsuleWorkspaces
  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) if (values[i].id === id) return values[i]
    return null
  }
  function focusWorkspace(id) {
    Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
  }

  // --- Weather: the weather addon's current conditions ---
  readonly property var weather: host.addons.isEnabled("weather") ? host.addons.root("weather") : null
  readonly property bool weatherReady: !!(weather && weather.status === "ready" && weather.current)
  readonly property bool showWeather: settings.capsuleWeather && weatherReady

  // --- Notifications: how many the history holds (Clear All empties it) ---
  readonly property int notificationCount: host.notifications.history.length
  readonly property bool showNotifications: settings.capsuleNotifications && notificationCount > 0

  // --- System: Bluetooth and battery only where there are any ---
  readonly property bool showSystem: settings.capsuleSystem
  readonly property bool bluetoothOn: !!(controls.btAdapter && controls.btAdapter.enabled)
  readonly property bool wired: !!(controls.wiredDevice && controls.wiredDevice.connected)

  // A black capsule that splits off the island like the iPhone's: it starts
  // tucked under the island's side, squashed, and springs out to its place
  // with a little overshoot, its content fading in once there's room. Each
  // one further out leaves a beat later, from under the ones before it.
  // Hiding springs them all back under the island without the bounce.
  component Capsule: Rectangle {
    id: capsule
    property bool present: true
    property real side: -1
    // The capsules between it and the island; it starts under them, and
    // leaves after them.
    property var before: []
    readonly property var ahead: before.filter(function(c) { return c.present })
    readonly property real lead: ahead.reduce(function(sum, c) { return sum + c.width + capsules.gap }, 0)
    default property alias content: row.data
    // Space either side of the content, and between its items.
    property real padding: 12
    property real spacing: 11
    property bool open: false
    readonly property real travel: capsules.gap + width / 2 + lead
    readonly property real progress: spring.value / 100
    readonly property real settled: Math.max(0, Math.min(1, progress))

    Timer {
      id: stagger
      interval: capsules.theme.scaled(40) * capsule.ahead.length
      onTriggered: capsule.open = capsules.shown
    }
    Component.onCompleted: open = capsules.shown
    Connections {
      target: capsules
      function onShownChanged() {
        if (!capsules.shown) { stagger.stop(); capsule.open = false }
        else if (capsule.ahead.length > 0) stagger.restart()
        else capsule.open = true
      }
    }
    MotionSpring {
      id: spring
      theme: capsules.theme
      pace: capsule.open ? "morph" : "standard"
      bounce: capsule.open ? 0.3 : 0
      target: capsule.open ? 100 : 0
    }

    visible: present
    width: row.implicitWidth + padding * 2
    height: capsules.capsuleHeight
    radius: height / 2
    topLeftRadius: capsules.notch ? 0 : radius
    topRightRadius: capsules.notch ? 0 : radius
    color: "#000000"
    opacity: Math.min(1, settled * 3)
    transform: [
      Scale {
        origin.x: capsule.side < 0 ? capsule.width : 0
        origin.y: capsules.notch ? 0 : capsule.height / 2
        xScale: 0.3 + 0.7 * capsule.progress
        yScale: Math.min(1.03, 0.62 + 0.38 * capsule.progress)
      },
      Translate { x: -capsule.side * (1 - capsule.progress) * capsule.travel }
    ]
    Row {
      id: row
      anchors.centerIn: parent
      spacing: capsule.spacing
      opacity: Math.max(0, Math.min(1, (capsule.progress - 0.45) / 0.4))
      scale: 0.82 + 0.18 * capsule.settled
    }
  }

  // A bar glyph: one size for all, dimmed while its thing is off.
  component Glyph: Text {
    id: glyph
    property bool on: true
    property color tint: capsules.ink
    signal clicked()
    signal rightClicked()
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: on ? tint : capsules.faint
    font.family: capsules.theme.fontFamily
    font.pixelSize: capsules.glyphSize
    MouseArea {
      anchors.fill: parent
      anchors.margins: -5
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) glyph.rightClicked()
        else glyph.clicked()
      }
    }
  }

  // A capsule's text: one size and weight for all, with steady digits.
  component Label: Text {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: capsules.ink
    font.family: capsules.theme.textFontFamily
    font.pixelSize: capsules.textSize
    font.weight: Font.DemiBold
    font.features: { "tnum": 1 }
  }

  // ---------- Left: next event, tray apps and updates, workspaces ----------

  Row {
    id: leftRow
    layoutDirection: Qt.RightToLeft
    spacing: capsules.gap
    x: capsules.island.x - capsules.gap - width
    y: capsules.capsuleY
    HoverHandler { id: leftHover }

    // Laid right to left: the one by the island first.
    Capsule {
      id: eventCapsule
      present: capsules.showEvent
      side: -1
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 16
        radius: 1.5
        color: capsules.nextEvent ? capsules.nextEvent.color || capsules.theme.accent : "transparent"
      }
      Label {
        width: Math.min(implicitWidth, 160)
        elide: Text.ElideRight
        text: capsules.nextEvent ? capsules.nextEvent.title : ""
      }
      Label {
        text: capsules.eventWhen
        color: capsules.faint
      }
      TapHandler {
        onTapped: {
          capsules.calendar.selectToday()
          capsules.host.view = "calendar"
        }
      }
    }

    Capsule {
      id: trayCapsule
      present: capsules.showTray
      side: -1
      before: [eventCapsule]
      Repeater {
        model: capsules.trayItems
        delegate: IconImage {
          id: trayIcon
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          implicitSize: capsules.traySize
          source: String(modelData.icon || "")
          // Left opens the app (or its menu, for menu-only apps), right its
          // menu in the tray view, middle its secondary action; scrolling
          // goes to the app.
          MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: function(mouse) {
              var item = trayIcon.modelData
              if (mouse.button === Qt.MiddleButton) item.secondaryActivate()
              else if (mouse.button === Qt.RightButton || (item.onlyMenu && item.hasMenu)) capsules.openTrayMenu(item)
              else item.activate()
            }
            onWheel: function(wheel) {
              var horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
              trayIcon.modelData.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal)
            }
          }
        }
      }
      Glyph {
        visible: capsules.showUpdate
        text: "\uf021"
        onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
      }
    }

    Capsule {
      present: capsules.showWorkspaces
      side: -1
      before: [eventCapsule, trayCapsule]
      padding: 14
      // A number per workspace on a grey tile for the current one, faint
      // when empty.
      Row {
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: capsules.host.workspaceIds
          delegate: Rectangle {
            id: tile
            required property int modelData
            readonly property bool current: modelData === capsules.host.focusedWorkspaceId
            readonly property var workspace: capsules.workspaceById(modelData)
            readonly property bool occupied: !!workspace && workspace.toplevels.values.length > 0
            width: capsules.capsuleHeight - 16
            height: width
            radius: 8
            color: current ? "#5c5c5e" : "transparent"
            Behavior on color { MotionColorAnimation { theme: capsules.theme } }
            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: tile.modelData
              color: tile.current || tile.occupied ? "#ffffff" : capsules.faint
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: capsules.focusWorkspace(tile.modelData)
            }
          }
        }
      }
    }
  }

  // ---------- Right: weather, notifications, connections and power ----------

  Row {
    id: rightRow
    spacing: capsules.gap
    x: capsules.island.x + capsules.island.width + capsules.gap
    y: capsules.capsuleY
    HoverHandler { id: rightHover }

    Capsule {
      id: weatherCapsule
      present: capsules.showWeather
      side: 1
      spacing: 6
      WeatherIcon {
        anchors.verticalCenter: parent.verticalCenter
        size: 22
        fontFamily: capsules.theme.fontFamily
        code: capsules.weatherReady ? capsules.weather.current.code : 0
        day: capsules.weatherReady ? capsules.weather.current.day : true
      }
      Label { text: (capsules.weatherReady ? Math.round(capsules.weather.current.temperature) : "--") + "°" }
      TapHandler { onTapped: capsules.host.view = "weather" }
    }

    Capsule {
      id: notificationCapsule
      present: capsules.showNotifications
      side: 1
      before: [weatherCapsule]
      spacing: 6
      Glyph { text: "󰂚" }
      // The history keeps the newest ten.
      Label { text: capsules.notificationCount >= 10 ? "9+" : capsules.notificationCount }
      TapHandler { onTapped: capsules.host.view = "controls" }
    }

    Capsule {
      present: capsules.showSystem
      side: 1
      before: [weatherCapsule, notificationCapsule]
      Glyph {
        visible: !!controls.btAdapter
        text: capsules.bluetoothOn ? "󰂯" : "󰂲"
        on: capsules.bluetoothOn
        onClicked: capsules.host.view = "bluetooth"
        onRightClicked: controls.toggleControl("bluetooth")
      }
      Glyph {
        text: controls.wifiNetwork ? "󰤨" : capsules.wired ? "󰈀" : "󰤮"
        on: !!controls.wifiNetwork || capsules.wired
        onClicked: capsules.host.view = "wifi"
      }
      Glyph {
        text: controls.muted || controls.volume <= 0 ? "󰖁" : controls.volume < 0.34 ? "󰕿" : controls.volume < 0.67 ? "󰖀" : "󰕾"
        tint: controls.muted ? capsules.theme.system.orange : capsules.ink
        onClicked: capsules.host.view = "controls"
        onRightClicked: if (controls.sink && controls.sink.audio) controls.sink.audio.muted = !controls.muted
        WheelHandler {
          onWheel: function(event) {
            if (!controls.sink || !controls.sink.audio) return
            var step = event.angleDelta.y > 0 ? 0.05 : -0.05
            controls.sink.audio.volume = Math.max(0, Math.min(1, controls.volume + step))
          }
        }
      }
      Row {
        visible: controls.hasBattery
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter
        Label { text: controls.batteryPercent + "%" }
        BatteryIcon {
          anchors.verticalCenter: parent.verticalCenter
          level: controls.batteryPercent
          charging: controls.charging
          low: controls.batteryPercent <= 20
          color: capsules.ink
          implicitWidth: 25
          implicitHeight: 12
        }
        TapHandler { onTapped: capsules.host.view = "controls" }
      }
    }
  }
}
