import QtQuick

// Device live activities. Battery and network are laid out like the clipboard
// pill on one line: the battery or network mark leading, what's happening in
// the middle, the level or status trailing. Bluetooth devices are laid out like iOS's AirPods activity: the
// device's picture, its status over its name, and a battery ring when the
// device reports one. Fed by Island.qml's showActivity():
//   { kind: "charging" | "lowBattery" | "bluetooth" | "network",
//     title, status, connected, battery (-1 when unknown), icon (BlueZ's),
//     wired (network only) }
Item {
  id: pill
  required property var host
  readonly property var activity: host.activities.current || ({})
  readonly property bool shown: host.activityPill
  readonly property bool isBattery: activity.kind === "charging" || activity.kind === "lowBattery"
  readonly property bool isDevice: activity.kind === "bluetooth"
  readonly property bool colorfulActivities: !!host.settings.colorfulLiveActivities
  readonly property color statusColor: activity.kind === "charging" && colorfulActivities ? pill.host.theme.system.green
    : activity.kind === "lowBattery" && colorfulActivities ? pill.host.theme.system.red
    : activity.connected ? host.theme.accent : Qt.rgba(1, 1, 1, 0.55)
  readonly property color connectedColor: colorfulActivities ? pill.host.theme.system.green : host.theme.accent
  readonly property color lowBatteryColor: colorfulActivities ? pill.host.theme.system.red : host.theme.accent
  // The leading glyph for the single-line kinds: Bluetooth's mark, or the
  // network's, on (solid) or off (slashed) and wired when it is.
  readonly property string leadingGlyph: activity.kind !== "network" ? "󰂯"
    : activity.wired ? "󰈀"
    : activity.connected ? "󰤨" : "󰤭"

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  PillReveal { id: reveal; theme: pill.host.theme; shown: pill.shown }

  // Leading: the battery, or the device's symbol, settling gently into place.
  Item {
    id: leading
    visible: !pill.isDevice
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: pill.isBattery ? 30 : 26
    height: 26
    opacity: reveal.leadingIn
    scale: 0.9 + 0.1 * reveal.leadingIn
    layer.enabled: reveal.leadingIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.leadingIn }
    BatteryIcon {
      visible: pill.isBattery
      anchors.centerIn: parent
      width: 30
      height: 14
      level: pill.activity.battery || 0
      charging: pill.activity.kind === "charging"
      chargingColor: pill.colorfulActivities ? pill.host.theme.system.green : pill.host.theme.accent
      lowColor: pill.lowBatteryColor
      low: pill.activity.kind === "lowBattery"
    }
    Text {
      anchors.centerIn: parent
      visible: !pill.isBattery
      text: pill.leadingGlyph
      color: pill.activity.connected ? pill.connectedColor : Qt.rgba(1, 1, 1, 0.55)
      font.family: pill.host.theme.fontFamily
      font.pixelSize: pill.host.theme.px(19)
    }
  }

  // Middle: what it's about.
  Text {
    visible: !pill.isDevice
    opacity: reveal.middleIn
    scale: 0.94 + 0.06 * reveal.middleIn
    layer.enabled: reveal.middleIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.middleIn }
    anchors.left: leading.right
    anchors.leftMargin: 10
    anchors.right: trailing.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: pill.activity.title || ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: "#ffffff"
    font.family: pill.host.theme.textFontFamily
    font.features: { "tnum": 1 }
    font.pixelSize: pill.host.theme.px(13)
    font.weight: Font.Medium
    font.letterSpacing: -0.2
  }

  // Trailing: the status (with a device's battery), a beat after the rest.
  Row {
    id: trailing
    scale: 0.9 + 0.1 * reveal.trailingIn
    layer.enabled: reveal.trailingIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.trailingIn }
    visible: !pill.isDevice
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 7
    opacity: reveal.trailingIn
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: pill.activity.status || ""
      color: pill.statusColor
      font.family: pill.host.theme.textFontFamily
      font.pixelSize: pill.host.theme.px(13)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
      font.features: { "tnum": 1 }
    }
    BatteryIcon {
      visible: !pill.isBattery && !!pill.activity.connected && (pill.activity.battery ?? -1) >= 0
      anchors.verticalCenter: parent.verticalCenter
      level: pill.activity.battery || 0
      chargingColor: pill.connectedColor
      lowColor: pill.lowBatteryColor
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
  readonly property color ringColor: deviceBattery >= 0 && deviceBattery <= 20 && pill.colorfulActivities ? pill.host.theme.system.red : pill.connectedColor

  Text {
    id: devicePicture
    visible: pill.isDevice
    anchors.left: parent.left
    anchors.leftMargin: 22
    anchors.verticalCenter: parent.verticalCenter
    text: pill.deviceGlyph
    color: pill.activity.connected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.55)
    font.family: pill.host.theme.fontFamily
    font.pixelSize: pill.host.theme.px(32)
    opacity: reveal.leadingIn
    scale: 0.9 + 0.1 * reveal.leadingIn
    layer.enabled: reveal.leadingIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.leadingIn }
  }
  Column {
    visible: pill.isDevice
    opacity: reveal.middleIn
    scale: 0.94 + 0.06 * reveal.middleIn
    layer.enabled: reveal.middleIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.middleIn }
    anchors.left: devicePicture.right
    anchors.leftMargin: 16
    anchors.right: ring.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Text {
      width: parent.width
      text: pill.activity.status || ""
      color: "#888888"
      font.family: pill.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.pixelSize: pill.host.theme.px(13)
      font.weight: Font.Medium
    }
    Text {
      width: parent.width
      text: pill.activity.title || ""
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: "#ffffff"
      font.family: pill.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.pixelSize: pill.host.theme.px(15)
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
    opacity: (pill.deviceBattery >= 0 ? 1 : 0) * reveal.trailingIn
    scale: 0.9 + 0.1 * reveal.trailingIn
    layer.enabled: reveal.trailingIn < 1
    layer.effect: PillBlur { blur: 1 - reveal.trailingIn }
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
      font.family: pill.host.theme.textFontFamily
      font.pixelSize: pill.host.theme.px(13)
      font.weight: Font.DemiBold
      font.features: { "tnum": 1 }
    }
  }
}
