import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// The expanded "controls" surface: quick toggles, sliders, now playing, and
// notifications. Reads its state from the island root passed in as `host`.
ColumnLayout {
  id: cc
  required property var host
  property bool active: false

  readonly property color accent: "#5ccfb6"
  readonly property color accentInk: "#0b201c"
  readonly property color accentInkMuted: "#1f4d44"
  readonly property color tile: "#202027"
  readonly property color text: "#f2f2f4"
  readonly property color textMuted: "#a4a4ad"
  readonly property string iconFont: host.fontFamily

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

  // --- Bluetooth ---
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property var btConnected: {
    var devs = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < devs.length; i++) if (devs[i] && devs[i].connected) return devs[i]
    return null
  }

  // --- Shell services ---
  readonly property var notifications: host.shell ? host.shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var nightlight: host.shell ? host.shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property bool dnd: notifications ? !!notifications.doNotDisturb : false
  readonly property bool nightOn: nightlight ? !!nightlight.enabled : false

  // --- Brightness (hidden when the display has no DDC/backlight control) ---
  property bool brightnessAvailable: false
  property int brightness: 0
  onActiveChanged: if (active && !brightnessRead.running) brightnessRead.running = true

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

  // ---------- Reusable pieces ----------

  component CcTile: Rectangle {
    id: t
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool available: true
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 56
    radius: 28
    color: checked ? cc.accent : cc.tile
    opacity: available ? 1 : 0.55
    scale: tileMouse.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: 180 * cc.host.motionScale; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 120 * cc.host.motionScale; easing.type: Easing.OutCubic } }

    Rectangle {
      id: badge
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      width: 36; height: 36; radius: 18
      color: t.checked ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.06)
      Text {
        anchors.centerIn: parent
        text: t.icon
        color: t.checked ? cc.accentInk : cc.text
        font.family: cc.iconFont
        font.pixelSize: 17
      }
    }
    Column {
      anchors.left: badge.right
      anchors.leftMargin: 9
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      Text {
        width: parent.width
        text: t.title
        elide: Text.ElideRight
        color: t.checked ? cc.accentInk : cc.text
        font.pixelSize: 13
        font.weight: Font.DemiBold
      }
      Text {
        width: parent.width
        visible: t.subtitle !== ""
        text: t.subtitle
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: t.checked ? cc.accentInkMuted : cc.textMuted
        font.pixelSize: 11
      }
    }
    MouseArea {
      id: tileMouse
      anchors.fill: parent
      enabled: t.available
      cursorShape: Qt.PointingHandCursor
      onClicked: t.clicked()
    }
  }

  component CcSlider: Rectangle {
    id: s
    property string icon: ""
    property real value: 0
    signal moved(real value)

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: 20
    color: cc.tile
    clip: true

    Rectangle {
      height: parent.height
      radius: parent.radius
      width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, s.value)))
      color: cc.accent
      Behavior on width {
        enabled: !sliderMouse.pressed
        NumberAnimation { duration: 140 * cc.host.motionScale; easing.type: Easing.OutCubic }
      }
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      text: s.icon
      color: cc.accentInk
      font.family: cc.iconFont
      font.pixelSize: 15
    }
    MouseArea {
      id: sliderMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      function apply(x) { s.moved(Math.max(0, Math.min(1, x / width))) }
      onPressed: function(e) { apply(e.x) }
      onPositionChanged: function(e) { if (pressed) apply(e.x) }
      onWheel: function(e) { s.moved(Math.max(0, Math.min(1, s.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
  }

  // ---------- Header ----------

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: 2
    spacing: 8
    Rectangle {
      Layout.preferredWidth: 34
      Layout.preferredHeight: 34
      radius: 17
      color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
      Text { anchors.centerIn: parent; text: "󰁍"; color: cc.text; font.family: cc.iconFont; font.pixelSize: 18 }
      MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; onClicked: cc.host.view = "rest" }
    }
    Text { text: "Control Center"; color: cc.text; font.pixelSize: 18; font.weight: Font.DemiBold }
    Item { Layout.fillWidth: true }
    Text {
      text: Qt.formatDateTime(cc.host.clockDate, "HH:mm")
      color: cc.textMuted
      font.pixelSize: 13
      Layout.rightMargin: 4
    }
  }

  // ---------- Toggles ----------

  RowLayout {
    Layout.fillWidth: true
    spacing: 10
    CcTile {
      Layout.preferredWidth: 4
      readonly property bool wifi: !!cc.wifiDevice
      icon: wifi ? (Networking.wifiEnabled ? "󰖩" : "󰖪") : "󰈀"
      title: wifi ? "Wi-Fi" : "Ethernet"
      subtitle: wifi
        ? (!Networking.wifiEnabled ? "Off" : cc.wifiNetwork ? cc.wifiNetwork.name : "Not connected")
        : (cc.wiredDevice && cc.wiredDevice.connected ? "Connected" : "Disconnected")
      checked: wifi ? Networking.wifiEnabled : !!(cc.wiredDevice && cc.wiredDevice.connected)
      available: wifi ? Networking.wifiHardwareEnabled !== false : false
      opacity: 1
      onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
    }
    CcTile {
      Layout.preferredWidth: 6
      icon: cc.muted ? "󰖁" : "󰕾"
      title: "Audio"
      subtitle: cc.sink ? String(cc.sink.description || cc.sink.nickname || cc.sink.name || "") : "No output"
      checked: !!cc.sink && !cc.muted
      available: !!(cc.sink && cc.sink.audio)
      onClicked: cc.sink.audio.muted = !cc.sink.audio.muted
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 10
    CcTile {
      Layout.preferredWidth: 1
      icon: cc.btAdapter && cc.btAdapter.enabled ? "󰂯" : "󰂲"
      title: "Bluetooth"
      subtitle: !cc.btAdapter ? "Unavailable" : !cc.btAdapter.enabled ? "Off" : cc.btConnected ? String(cc.btConnected.name || "Connected") : "On"
      checked: !!(cc.btAdapter && cc.btAdapter.enabled)
      available: !!cc.btAdapter
      onClicked: cc.btAdapter.enabled = !cc.btAdapter.enabled
    }
    CcTile {
      Layout.preferredWidth: 1
      icon: "󰂛"
      title: "Peace"
      subtitle: cc.dnd ? "On" : "Off"
      checked: cc.dnd
      available: !!cc.notifications
      onClicked: cc.notifications.setDoNotDisturb(!cc.dnd)
    }
    CcTile {
      Layout.preferredWidth: 1
      icon: "󰔎"
      title: "Night Light"
      subtitle: cc.nightOn ? "On" : "Off"
      checked: cc.nightOn
      available: !!cc.nightlight
      onClicked: cc.nightlight.setNightlight(!cc.nightOn)
    }
  }

  // ---------- Sliders ----------

  CcSlider {
    Layout.topMargin: 2
    visible: !!(cc.sink && cc.sink.audio)
    icon: cc.muted || cc.volume <= 0 ? "󰖁" : cc.volume < 0.5 ? "󰖀" : "󰕾"
    value: cc.volume
    onMoved: function(v) {
      cc.sink.audio.volume = v
      if (cc.sink.audio.muted && v > 0) cc.sink.audio.muted = false
    }
  }
  CcSlider {
    visible: cc.brightnessAvailable
    icon: "󰃠"
    value: cc.brightness / 100
    onMoved: function(v) {
      cc.brightness = Math.round(v * 100)
      brightnessDebounce.restart()
    }
  }

  // ---------- Now playing ----------

  ClippingRectangle {
    id: mediaCard
    readonly property var player: cc.host.player
    readonly property real length: player && player.lengthSupported ? player.length : 0
    property real position: 0

    visible: !!player
    Layout.fillWidth: true
    Layout.topMargin: 2
    Layout.preferredHeight: 128
    radius: 22
    color: "#1b1b22"

    // Mpris only publishes position on seeks; re-read it every frame while
    // the card is on screen so the progress bar glides at display rate.
    FrameAnimation {
      running: cc.active && mediaCard.visible && !!mediaCard.player && mediaCard.player.isPlaying
      onTriggered: mediaCard.position = mediaCard.player.position
    }
    onPlayerChanged: position = player ? player.position : 0
    Connections {
      target: mediaCard.player
      function onPositionChanged() { if (!seekMouse.pressed) mediaCard.position = mediaCard.player.position }
      function onTrackTitleChanged() { mediaCard.position = mediaCard.player.position }
    }

    Image {
      id: art
      anchors.fill: parent
      source: mediaCard.player && mediaCard.player.trackArtUrl ? mediaCard.player.trackArtUrl : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      visible: false
    }
    MultiEffect {
      anchors.fill: parent
      source: art
      visible: art.status === Image.Ready
      blurEnabled: true
      blur: 1.0
      blurMax: 48
      saturation: 0.15
      autoPaddingEnabled: false
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, art.status === Image.Ready ? 0.62 : 0) }
        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, art.status === Image.Ready ? 0.30 : 0) }
      }
    }

    Row {
      id: sourceLabel
      anchors.left: parent.left
      anchors.right: playButton.left
      anchors.top: parent.top
      anchors.margins: 14
      spacing: 6
      Text { id: sourceIcon; text: "󰕾"; color: Qt.rgba(1, 1, 1, 0.7); font.family: cc.iconFont; font.pixelSize: 11 }
      Text {
        width: parent.width - sourceIcon.width - parent.spacing
        text: cc.sink ? String(cc.sink.description || cc.sink.nickname || "") : String(mediaCard.player ? mediaCard.player.identity || "" : "")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 11
      }
    }
    Column {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: playButton.left
      anchors.rightMargin: 12
      anchors.top: sourceLabel.bottom
      anchors.topMargin: 12
      spacing: 2
      Text {
        width: parent.width
        text: cc.host.title || "Unknown track"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: cc.text
        font.pixelSize: 17
        font.weight: Font.DemiBold
      }
      Text {
        width: parent.width
        text: cc.host.artist
        visible: text !== ""
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Qt.rgba(1, 1, 1, 0.72)
        font.pixelSize: 12
      }
    }
    Rectangle {
      id: playButton
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.top: parent.top
      anchors.topMargin: 26
      width: 46; height: 46; radius: 23
      color: "#f2f2f4"
      scale: playMouse.pressed ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: 120 * cc.host.motionScale; easing.type: Easing.OutCubic } }
      Text {
        anchors.centerIn: parent
        text: mediaCard.player && mediaCard.player.isPlaying ? "󰏤" : "󰐊"
        color: "#101014"
        font.family: cc.iconFont
        font.pixelSize: 20
      }
      MouseArea { id: playMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.host.media.runAction("playPause", false, "") }
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 12
      spacing: 10
      Text {
        text: "󰒮"
        color: mediaCard.player && mediaCard.player.canGoPrevious ? cc.text : Qt.rgba(1, 1, 1, 0.35)
        font.family: cc.iconFont
        font.pixelSize: 15
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cc.host.media.runAction("previous", false, "") }
      }
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 16
        Rectangle {
          id: track
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 4
          radius: 2
          color: Qt.rgba(1, 1, 1, 0.22)
          Rectangle {
            height: parent.height
            radius: parent.radius
            width: mediaCard.length > 0 ? parent.width * Math.max(0, Math.min(1, mediaCard.position / mediaCard.length)) : 0
            color: "#f2f2f4"
          }
        }
        MouseArea {
          id: seekMouse
          anchors.fill: parent
          enabled: !!mediaCard.player && mediaCard.player.canSeek && mediaCard.length > 0
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          function target(x) { return Math.max(0, Math.min(1, x / width)) * mediaCard.length }
          onPressed: function(e) { mediaCard.position = target(e.x) }
          onPositionChanged: function(e) { if (pressed) mediaCard.position = target(e.x) }
          onReleased: function(e) { mediaCard.player.position = target(e.x) }
        }
      }
      Text {
        text: "󰒭"
        color: mediaCard.player && mediaCard.player.canGoNext ? cc.text : Qt.rgba(1, 1, 1, 0.35)
        font.family: cc.iconFont
        font.pixelSize: 15
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cc.host.media.runAction("next", false, "") }
      }
    }
  }

  // ---------- Notifications ----------

  Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

  RowLayout {
    Layout.fillWidth: true
    Text { text: "Notifications"; color: cc.textMuted; font.pixelSize: 12 }
    Item { Layout.fillWidth: true }
    Text {
      visible: cc.host.history.length > 0
      text: "Clear all"
      color: cc.accent
      font.pixelSize: 12
      font.weight: Font.DemiBold
      MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: cc.host.clearAllNotifications() }
    }
  }

  Text {
    visible: cc.host.history.length === 0
    Layout.fillWidth: true
    Layout.topMargin: 6
    Layout.bottomMargin: 6
    horizontalAlignment: Text.AlignHCenter
    text: "No notifications"
    color: cc.textMuted
    font.pixelSize: 12
  }

  ListView {
    id: notificationList
    visible: cc.host.history.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(contentHeight, 250)
    clip: true
    spacing: 8
    boundsBehavior: Flickable.StopAtBounds
    model: cc.host.history
    delegate: Rectangle {
      id: card
      required property var modelData
      readonly property string iconPath: modelData.appIcon ? Quickshell.iconPath(String(modelData.appIcon), true) : ""
      width: ListView.view.width
      height: cardBody.implicitHeight + 22
      radius: 16
      color: cardMouse.containsMouse && modelData.isActive ? "#26262e" : "#1b1b21"

      MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !!card.modelData.isActive
        onClicked: cc.host.notificationCommand("invokeKey", card.modelData)
      }
      Rectangle {
        id: appBadge
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.top: parent.top
        anchors.topMargin: 12
        width: 28; height: 28; radius: 14
        color: card.iconPath ? "transparent" : "#3b82c4"
        IconImage {
          anchors.fill: parent
          visible: card.iconPath !== ""
          source: card.iconPath
        }
        Text {
          anchors.centerIn: parent
          visible: card.iconPath === ""
          text: "󰋼"
          color: "#ffffff"
          font.family: cc.iconFont
          font.pixelSize: 16
        }
      }
      Column {
        id: cardBody
        anchors.left: appBadge.right
        anchors.leftMargin: 11
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.top: parent.top
        anchors.topMargin: 11
        spacing: 2
        Text {
          width: parent.width
          text: String(card.modelData.app || "")
          visible: text !== ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: cc.textMuted
          font.pixelSize: 11
        }
        Text {
          width: parent.width
          text: String(card.modelData.summary || "Notification")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: cc.text
          font.pixelSize: 13
          font.weight: Font.DemiBold
        }
        Text {
          width: parent.width
          text: String(card.modelData.body || "")
          visible: text !== ""
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
          color: cc.textMuted
          font.pixelSize: 12
        }
      }
      Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 9
        text: "󰅖"
        color: closeMouse.containsMouse ? cc.text : cc.textMuted
        font.family: cc.iconFont
        font.pixelSize: 13
        MouseArea { id: closeMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: cc.host.dismissNotification(card.modelData) }
      }
    }
  }
}
