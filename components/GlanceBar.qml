import QtQuick
import Quickshell.Widgets
import "../addons/weather"

// The left and right accessory slots revealed when hovering over the resting island.
// Both sides are modular, customizable from Settings, and interactive:
// - Clicking Media opens the full Player view.
// - Clicking Weather opens the Weather forecast view.
// - Clicking Network opens Wi-Fi settings.
// - Clicking Volume or Battery opens Control Center.
// - Clicking Workspace switches or shows workspace HUD.
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
  readonly property string rawLeft1Kind: settings.glanceLeft1 || "workspace"
  readonly property string rawLeft2Kind: settings.glanceLeft2 || "battery"
  readonly property string rawRight1Kind: settings.glanceRight1 || "weather"
  readonly property string rawRight2Kind: settings.glanceRight2 || "volume"

  readonly property bool hasConfiguredMedia: rawLeft1Kind === "media" || rawLeft2Kind === "media"
    || rawRight1Kind === "media" || rawRight2Kind === "media"
  readonly property bool isMediaPlaying: !!(glanceBar.host.nowPlaying && glanceBar.host.nowPlaying.playing)
  // When music is actively playing and media is not in any slot, dynamically show media in right1 slot
  readonly property string left1Kind: rawLeft1Kind
  readonly property string left2Kind: rawLeft2Kind
  readonly property string right1Kind: (!hasConfiguredMedia && isMediaPlaying) ? "media" : rawRight1Kind
  readonly property string right2Kind: rawRight2Kind

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
    Item {
      id: wsItem
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: wsRow.implicitWidth
      implicitHeight: wsRow.implicitHeight
      width: implicitWidth
      height: implicitHeight

      Row {
        id: wsRow
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
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          mouse.accepted = true
          glanceBar.host.showFeedback("", 1200, "workspaces")
        }
      }
    }
  }

  Component {
    id: compBattery
    Item {
      id: battItem
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: battRow.implicitWidth
      implicitHeight: battRow.implicitHeight
      width: implicitWidth
      height: implicitHeight
      readonly property bool hasBattery: glanceBar.host.activities.hasBattery
      readonly property int level: glanceBar.host.activities.batteryLevel
      readonly property bool onPower: glanceBar.host.activities.onPower

      Row {
        id: battRow
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter
        BatteryIcon {
          visible: battItem.hasBattery
          level: battItem.level
          charging: battItem.onPower
          color: "#e2e6de"
          implicitWidth: 20
          implicitHeight: 11
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: battItem.hasBattery ? battItem.level + "%" : "AC"
          color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
          font.family: glanceBar.host.theme.textFontFamily
          font.pixelSize: glanceBar.host.theme.px(11)
          font.weight: Font.Medium
          anchors.verticalCenter: parent.verticalCenter
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          mouse.accepted = true
          glanceBar.host.view = "controls"
        }
      }
    }
  }

  Component {
    id: compNetwork
    Item {
      id: netItem
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: netRow.implicitWidth
      implicitHeight: netRow.implicitHeight
      width: implicitWidth
      height: implicitHeight
      readonly property var net: glanceBar.host.activities.netConnected
      readonly property bool online: net && net.length > 0
      readonly property bool wired: online && net[0].wired

      Row {
        id: netRow
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter
        Text {
          text: !netItem.online ? "󰖪" : netItem.wired ? "󰈀" : "󰤨"
          color: !netItem.online ? glanceBar.host.theme.system.orange : glanceBar.host.theme.system.blue
          font.family: glanceBar.host.theme.fontFamily
          font.pixelSize: glanceBar.host.theme.px(13)
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: !netItem.online ? "Offline" : netItem.net[0].name || (netItem.wired ? "Ethernet" : "Wi-Fi")
          color: Qt.rgba(0.88, 0.90, 0.87, 0.8)
          font.family: glanceBar.host.theme.textFontFamily
          font.pixelSize: glanceBar.host.theme.px(11)
          font.weight: Font.Medium
          elide: Text.ElideRight
          width: Math.min(implicitWidth, 65)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          mouse.accepted = true
          glanceBar.host.view = "wifi"
        }
      }
    }
  }

  Component {
    id: compWeather
    Item {
      id: weatherItem
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: weatherRow.implicitWidth
      implicitHeight: weatherRow.implicitHeight
      width: implicitWidth
      height: implicitHeight
      readonly property var weatherAddon: glanceBar.host.addons.root("weather")
      readonly property bool ready: !!(weatherAddon && weatherAddon.status === "ready" && weatherAddon.current)

      Row {
        id: weatherRow
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter
        WeatherIcon {
          visible: weatherItem.ready
          code: weatherItem.ready ? weatherItem.weatherAddon.current.code : 0
          day: weatherItem.ready ? weatherItem.weatherAddon.current.day : true
          fontFamily: glanceBar.host.theme.fontFamily
          size: 16
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: weatherItem.ready ? Math.round(weatherItem.weatherAddon.current.temperature) + "°" : "󰖐 --°"
          color: "#e2e6de"
          font.family: glanceBar.host.theme.textFontFamily
          font.pixelSize: glanceBar.host.theme.px(12)
          font.weight: Font.DemiBold
          anchors.verticalCenter: parent.verticalCenter
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          mouse.accepted = true
          if (weatherItem.ready) glanceBar.host.view = "weather"
          else glanceBar.host.view = "controls"
        }
      }
    }
  }

  Component {
    id: compMedia
    Item {
      id: mediaItem
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: mediaRow.implicitWidth
      implicitHeight: mediaRow.implicitHeight
      width: implicitWidth
      height: implicitHeight

      readonly property var nowPlaying: glanceBar.host.nowPlaying
      readonly property var player: nowPlaying ? nowPlaying.player : null
      readonly property bool playing: !!(nowPlaying && nowPlaying.playing)
      readonly property string track: nowPlaying && nowPlaying.title ? nowPlaying.title : ""
      readonly property string artist: nowPlaying && nowPlaying.artist ? nowPlaying.artist : (player && player.trackArtist ? String(player.trackArtist) : "")
      readonly property string artUrl: nowPlaying && nowPlaying.art ? nowPlaying.art : ""

      Row {
        id: mediaRow
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter

        ClippingRectangle {
          id: miniCoverClip
          width: 16
          height: 16
          radius: 4
          color: "transparent"
          anchors.verticalCenter: parent.verticalCenter
          visible: miniCover.status === Image.Ready

          Image {
            id: miniCover
            anchors.fill: parent
            source: mediaItem.artUrl
            sourceSize.width: 32
            sourceSize.height: 32
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
          }
        }

        Text {
          visible: !miniCoverClip.visible
          text: mediaItem.playing ? "󰝚" : (mediaItem.track !== "" ? "󰐊" : "󰝚")
          color: mediaItem.playing && mediaItem.nowPlaying && mediaItem.nowPlaying.tint ? mediaItem.nowPlaying.tint : glanceBar.host.theme.accent
          font.family: glanceBar.host.theme.fontFamily
          font.pixelSize: glanceBar.host.theme.px(13)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: mediaItem.track !== "" ? (mediaItem.artist ? mediaItem.track + " · " + mediaItem.artist : mediaItem.track) : "Player"
          color: mediaItem.track !== "" ? Qt.rgba(0.92, 0.94, 0.90, 0.9) : Qt.rgba(0.88, 0.90, 0.87, 0.45)
          font.family: glanceBar.host.theme.textFontFamily
          font.pixelSize: glanceBar.host.theme.px(11)
          font.weight: Font.Medium
          elide: Text.ElideRight
          width: Math.min(implicitWidth, 105)
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          mouse.accepted = true
          glanceBar.host.view = "player"
        }
      }
    }
  }

  Component {
    id: compVolume
    Item {
      id: volumeItem
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: volumeRow.implicitWidth
      implicitHeight: volumeRow.implicitHeight
      width: implicitWidth
      height: implicitHeight

      Row {
        id: volumeRow
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
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          mouse.accepted = true
          glanceBar.host.view = "controls"
        }
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
