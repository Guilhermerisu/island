import QtQuick
import "../addons/weather"

// The left and right accessory slots revealed when hovering over the resting island.
// Both sides are symmetrically balanced with two items separated by a subtle divider dot:
// - Left slot: Active workspace and battery status (or network on desktop).
// - Right slot: Weather (or media) and audio volume level.
Item {
  id: glanceBar
  required property var host
  property bool shown: false

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity {
    MotionAnimation { theme: glanceBar.host.theme; pace: glanceBar.shown ? "fade" : "exit"; curve: "fade" }
  }

  // Left Slot: Workspace + Divider + Battery (or Network)
  Row {
    id: leftSlot
    anchors.left: parent.left
    anchors.leftMargin: glanceBar.host.settings.notch ? 18 : 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 7

    // Active Hyprland Workspace badge
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

    // Divider dot
    Rectangle {
      width: 3
      height: 3
      radius: 1.5
      color: Qt.rgba(1, 1, 1, 0.25)
      anchors.verticalCenter: parent.verticalCenter
    }

    // Battery (if device has battery)
    Row {
      visible: glanceBar.host.activities.hasBattery
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter
      BatteryIcon {
        level: glanceBar.host.activities.batteryLevel
        charging: glanceBar.host.activities.onPower
        color: "#e2e6de"
        implicitWidth: 20
        implicitHeight: 11
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: glanceBar.host.activities.batteryLevel + "%"
        color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(11)
        font.weight: Font.Medium
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Network status (if desktop PC / no battery)
    Row {
      visible: !glanceBar.host.activities.hasBattery
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

  // Right Slot: Weather (or Media/Sound) + Divider + Volume
  Row {
    id: rightSlot
    anchors.right: parent.right
    anchors.rightMargin: glanceBar.host.settings.notch ? 18 : 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 7

    readonly property var weatherAddon: glanceBar.host.addons.root("weather")
    readonly property bool hasWeather: !!(weatherAddon && weatherAddon.status === "ready" && weatherAddon.current)
    readonly property var nowPlaying: glanceBar.host.nowPlaying
    readonly property bool hasMedia: !!(nowPlaying && nowPlaying.playing)

    // Weather condition and temperature
    Row {
      visible: rightSlot.hasWeather
      spacing: 5
      anchors.verticalCenter: parent.verticalCenter
      WeatherIcon {
        visible: rightSlot.hasWeather
        code: rightSlot.weatherAddon && rightSlot.weatherAddon.current ? rightSlot.weatherAddon.current.code : 0
        day: rightSlot.weatherAddon && rightSlot.weatherAddon.current ? rightSlot.weatherAddon.current.day : true
        fontFamily: glanceBar.host.theme.fontFamily
        size: 16
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: rightSlot.weatherAddon && rightSlot.weatherAddon.current
          ? Math.round(rightSlot.weatherAddon.current.temperature) + "°" : ""
        color: "#e2e6de"
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(12)
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Now Playing Media fallback if no weather
    Row {
      visible: !rightSlot.hasWeather && rightSlot.hasMedia
      spacing: 5
      anchors.verticalCenter: parent.verticalCenter
      Text {
        text: "󰝚"
        color: glanceBar.host.theme.accent
        font.family: glanceBar.host.theme.fontFamily
        font.pixelSize: glanceBar.host.theme.px(13)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: rightSlot.nowPlaying ? rightSlot.nowPlaying.trackTitle : ""
        color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(11)
        font.weight: Font.Medium
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 70)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Audio fallback if no weather and no media
    Row {
      visible: !rightSlot.hasWeather && !rightSlot.hasMedia
      spacing: 4
      anchors.verticalCenter: parent.verticalCenter
      Text {
        text: "󰓃"
        color: glanceBar.host.theme.accent
        font.family: glanceBar.host.theme.fontFamily
        font.pixelSize: glanceBar.host.theme.px(13)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "Audio"
        color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
        font.family: glanceBar.host.theme.textFontFamily
        font.pixelSize: glanceBar.host.theme.px(11)
        font.weight: Font.Medium
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Divider dot
    Rectangle {
      width: 3
      height: 3
      radius: 1.5
      color: Qt.rgba(1, 1, 1, 0.25)
      anchors.verticalCenter: parent.verticalCenter
    }

    // Audio Volume level
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
}
