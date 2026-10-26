import QtQuick
import "../addons/weather"

// The left and right accessory slots revealed when hovering over the resting island.
// Both sides are modular and customizable from Settings (Left 1, Left 2, Right 1, Right 2).
// Available modules: workspace, battery, network, weather, media, volume, none.
Item {
  id: glanceBar
  required property var host
  property bool shown: false

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity {
    MotionAnimation { theme: glanceBar.host.theme; pace: glanceBar.shown ? "fade" : "exit"; curve: "fade" }
  }

  readonly property var settings: glanceBar.host.settings
  readonly property string left1Kind: settings.glanceLeft1 || "workspace"
  readonly property string left2Kind: settings.glanceLeft2 || "battery"
  readonly property string right1Kind: settings.glanceRight1 || "weather"
  readonly property string right2Kind: settings.glanceRight2 || "volume"

  function componentFor(kind) {
    switch (kind) {
    case "workspace": return compWorkspace
    case "battery": return compBattery
    case "network": return compNetwork
    case "weather": return compWeather
    case "media": return compMedia
    case "volume": return compVolume
    default: return null
    }
  }

  // --- Module Component Definitions ---

  Component {
    id: compWorkspace
    Row {
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter
      Text {
        text: "󱂬"
        color: glanceBar.host.theme.accent
        font.family: glanceBar.host.theme.fontFamily
        font.pixelSize: glanceBar.host.theme.px(13)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: String(glanceBar.host.focusedWorkspaceId > 0 ? glanceBar.host.focusedWorkspaceId : "1")
        color: "#e2e6de"
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(12)
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: compBattery
    Row {
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter
      readonly property bool hasBattery: glanceBar.host.activities.hasBattery
      readonly property int level: glanceBar.host.activities.batteryLevel
      readonly property bool onPower: glanceBar.host.activities.onPower
      BatteryIcon {
        visible: parent.hasBattery
        level: parent.level
        charging: parent.onPower
        color: "#e2e6de"
        implicitWidth: 20
        implicitHeight: 11
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.hasBattery ? parent.level + "%" : "AC"
        color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(11)
        font.weight: Font.Medium
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: compNetwork
    Row {
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter
      readonly property var net: glanceBar.host.activities.netConnected
      readonly property bool online: net && net.length > 0
      readonly property bool wired: online && net[0].wired
      Text {
        text: !parent.online ? "󰖪" : parent.wired ? "󰈀" : "󰤨"
        color: !parent.online ? glanceBar.host.theme.system.orange : glanceBar.host.theme.system.blue
        font.family: glanceBar.host.theme.fontFamily
        font.pixelSize: glanceBar.host.theme.px(13)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: !parent.online ? "Offline" : parent.net[0].name || (parent.wired ? "Ethernet" : "Wi-Fi")
        color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(11)
        font.weight: Font.Medium
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 65)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: compWeather
    Row {
      spacing: 5
      anchors.verticalCenter: parent.verticalCenter
      readonly property var weatherAddon: glanceBar.host.addons.root("weather")
      readonly property bool ready: !!(weatherAddon && weatherAddon.status === "ready" && weatherAddon.current)
      WeatherIcon {
        visible: parent.ready
        code: parent.ready ? parent.weatherAddon.current.code : 0
        day: parent.ready ? parent.weatherAddon.current.day : true
        fontFamily: glanceBar.host.theme.fontFamily
        size: 16
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.ready ? Math.round(parent.weatherAddon.current.temperature) + "°" : "󰖐 --°"
        color: "#e2e6de"
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(12)
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: compMedia
    Row {
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter
      readonly property var nowPlaying: glanceBar.host.nowPlaying
      readonly property bool playing: !!(nowPlaying && nowPlaying.playing)
      Text {
        text: "󰝚"
        color: parent.playing && parent.nowPlaying.tint ? parent.nowPlaying.tint : glanceBar.host.theme.accent
        font.family: glanceBar.host.theme.fontFamily
        font.pixelSize: glanceBar.host.theme.px(13)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.playing ? parent.nowPlaying.trackTitle : "No music"
        color: parent.playing ? Qt.rgba(0.88, 0.90, 0.87, 0.8) : Qt.rgba(0.88, 0.90, 0.87, 0.45)
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(11)
        font.weight: Font.Medium
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 80)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Component {
    id: compVolume
    Row {
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter
      Text {
        text: glanceBar.host.muted || glanceBar.host.volume <= 0 ? "󰖁" : glanceBar.host.volume < 0.5 ? "󰖀" : "󰕾"
        color: glanceBar.host.muted ? glanceBar.host.theme.system.orange : "#e2e6de"
        font.family: glanceBar.host.theme.fontFamily
        font.pixelSize: glanceBar.host.theme.px(13)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: glanceBar.host.muted ? "Muted" : Math.round(glanceBar.host.volume * 100) + "%"
        color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(11)
        font.weight: Font.Medium
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // --- Left Slot: Slot 1 + Divider + Slot 2 ---
  Row {
    id: leftSlot
    anchors.left: parent.left
    anchors.leftMargin: glanceBar.host.settings.notch ? 18 : 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 7

    Loader {
      id: leftL1
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: glanceBar.componentFor(glanceBar.left1Kind)
    }

    Rectangle {
      width: 3
      height: 3
      radius: 1.5
      color: Qt.rgba(1, 1, 1, 0.25)
      anchors.verticalCenter: parent.verticalCenter
      visible: !!leftL1.item && !!leftL2.item
    }

    Loader {
      id: leftL2
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: glanceBar.componentFor(glanceBar.left2Kind)
    }
  }

  // --- Right Slot: Slot 1 + Divider + Slot 2 ---
  Row {
    id: rightSlot
    anchors.right: parent.right
    anchors.rightMargin: glanceBar.host.settings.notch ? 18 : 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 7

    Loader {
      id: rightL1
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: glanceBar.componentFor(glanceBar.right1Kind)
    }

    Rectangle {
      width: 3
      height: 3
      radius: 1.5
      color: Qt.rgba(1, 1, 1, 0.25)
      anchors.verticalCenter: parent.verticalCenter
      visible: !!rightL1.item && !!rightL2.item
    }

    Loader {
      id: rightL2
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: glanceBar.componentFor(glanceBar.right2Kind)
    }
  }
}
