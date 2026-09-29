import QtQuick

// Device live activities. Battery is laid out like the clipboard pill on one
// line: the battery leading, what's happening in the middle, the level
// trailing. Bluetooth devices are laid out like iOS's AirPods activity: the
// device's picture, its status over its name, and a battery ring when the
// device reports one. Fed by Island.qml's showActivity():
//   { kind: "charging" | "lowBattery" | "bluetooth",
//     title, status, connected, battery (-1 when unknown), icon (BlueZ's) }
Item {
  id: pill
  required property var host
  readonly property var activity: host.activity || ({})
  readonly property bool shown: host.activityPill
  readonly property bool isBattery: activity.kind === "charging" || activity.kind === "lowBattery"
  readonly property bool isDevice: activity.kind === "bluetooth"
  readonly property color statusColor: activity.kind === "charging" ? "#30d158"
    : activity.kind === "lowBattery" ? "#ff453a"
    : activity.connected ? host.colorAccent : Qt.rgba(1, 1, 1, 0.55)

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * pill.host.motionScale; easing.type: Easing.InOutQuad } }

  // Leading: the battery, or the device's symbol, springing in.
  Item {
    id: leading
    visible: !pill.isDevice
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: pill.isBattery ? 30 : 26
    height: 26
    scale: pill.shown ? 1 : 0.4
    Behavior on scale { NumberAnimation { duration: 360 * pill.host.motionScale; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    BatteryIcon {
      visible: pill.isBattery
      anchors.centerIn: parent
      width: 30
      height: 14
      level: pill.activity.battery || 0
      charging: pill.activity.kind === "charging"
      low: pill.activity.kind === "lowBattery"
    }
    Text {
      anchors.centerIn: parent
      visible: !pill.isBattery
      text: "󰂯"
      color: pill.activity.connected ? pill.host.colorAccent : Qt.rgba(1, 1, 1, 0.55)
      font.family: pill.host.fontFamily
      font.pixelSize: 19
    }
  }

  // Middle: what it's about.
  Text {
    visible: !pill.isDevice
    anchors.left: leading.right
    anchors.leftMargin: 10
    anchors.right: trailing.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: pill.activity.title || ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: "#ffffff"
    font.family: "Adwaita Sans"
    font.pixelSize: 13
    font.weight: Font.Medium
    font.letterSpacing: -0.2
  }

  // Trailing: the status (with a device's battery), a beat after the rest.
  Row {
    id: trailing
    visible: !pill.isDevice
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 7
    opacity: pill.shown ? 1 : 0
    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: pill.shown ? 120 * pill.host.motionScale : 0 }
        NumberAnimation { duration: 180 * pill.host.motionScale; easing.type: Easing.OutQuad }
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: pill.activity.status || ""
      color: pill.statusColor
      font.family: "Adwaita Sans"
      font.pixelSize: 13
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
      font.features: { "tnum": 1 }
    }
    BatteryIcon {
      visible: !pill.isBattery && !!pill.activity.connected && (pill.activity.battery ?? -1) >= 0
      anchors.verticalCenter: parent.verticalCenter
      level: pill.activity.battery || 0
      low: (pill.activity.battery ?? 100) <= 20
    }
  }

  // ---------- Bluetooth, like iOS's AirPods activity ----------

  // BlueZ's device icon names to pictures.
  readonly property string deviceGlyph: {
    var icon = String(activity.icon || "")
    if (/headset|headphone/.test(icon)) return "󰋋"
    if (/speaker|audio-card/.test(icon)) return "󰓃"
    if (/keyboard/.test(icon)) return "󰌌"
    if (/mouse|tablet/.test(icon)) return "󰍽"
    if (/gaming|joystick/.test(icon)) return "󰊴"
    if (/phone/.test(icon)) return "󰏲"
    if (/computer/.test(icon)) return "󰇄"
    return "󰂯"
  }
  readonly property int deviceBattery: activity.connected && (activity.battery ?? -1) >= 0 ? activity.battery : -1
  readonly property color ringColor: deviceBattery >= 0 && deviceBattery <= 20 ? "#ff453a" : "#30d158"

  Text {
    id: devicePicture
    visible: pill.isDevice
    anchors.left: parent.left
    anchors.leftMargin: 22
    anchors.verticalCenter: parent.verticalCenter
    text: pill.deviceGlyph
    color: pill.activity.connected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.55)
    font.family: pill.host.fontFamily
    font.pixelSize: 32
    scale: pill.shown ? 1 : 0.4
    Behavior on scale { NumberAnimation { duration: 360 * pill.host.motionScale; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
  }
  Column {
    visible: pill.isDevice
    anchors.left: devicePicture.right
    anchors.leftMargin: 16
    anchors.right: ring.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Text {
      width: parent.width
      text: pill.activity.status || ""
      color: Qt.rgba(1, 1, 1, 0.5)
      font.family: "Adwaita Sans"
      font.pixelSize: 13
      font.weight: Font.Medium
    }
    Text {
      width: parent.width
      text: pill.activity.title || ""
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: "#ffffff"
      font.family: "Adwaita Sans"
      font.pixelSize: 16
      font.weight: Font.Medium
      font.letterSpacing: -0.2
    }
  }
  // Battery ring: a dim track, the level around it, the percentage inside.
  Item {
    id: ring
    visible: pill.isDevice
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    width: pill.deviceBattery >= 0 ? 42 : 0
    height: 42
    opacity: pill.shown && pill.deviceBattery >= 0 ? 1 : 0
    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: pill.shown ? 120 * pill.host.motionScale : 0 }
        NumberAnimation { duration: 180 * pill.host.motionScale; easing.type: Easing.OutQuad }
      }
    }
    Canvas {
      id: ringCanvas
      anchors.fill: parent
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var r = width / 2 - 2.5, c = pill.ringColor
        ctx.lineWidth = 3.5
        ctx.lineCap = "round"
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.28)
        ctx.beginPath()
        ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2)
        ctx.stroke()
        var level = Math.max(0, Math.min(100, pill.deviceBattery)) / 100
        if (level <= 0) return
        ctx.strokeStyle = c
        ctx.beginPath()
        ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * level)
        ctx.stroke()
      }
      Connections {
        target: pill
        function onDeviceBatteryChanged() { ringCanvas.requestPaint() }
        function onRingColorChanged() { ringCanvas.requestPaint() }
      }
    }
    Text {
      anchors.centerIn: parent
      text: pill.deviceBattery
      color: pill.ringColor
      font.family: "Adwaita Sans"
      font.pixelSize: 14
      font.weight: Font.DemiBold
      font.features: { "tnum": 1 }
    }
  }
}
