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
//
// Guaranteed clock clearance: Left and right containers are strictly bounded
// against a central exclusion reserve around the clock label, and variable-length
// items (media title, network SSID) dynamically compute their max text width
// to elide cleanly with ellipsis instead of colliding with the clock.
Item {
  id: glanceBar
  required property var host
  property bool shown: false
  property real clockWidth: 70

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

  readonly property bool hasLeftItems: (left1Kind !== "none" && left1Kind !== "") || (left2Kind !== "none" && left2Kind !== "")
  readonly property bool hasRightItems: (right1Kind !== "none" && right1Kind !== "") || (right2Kind !== "none" && right2Kind !== "")
  readonly property bool hasItems: hasLeftItems || hasRightItems

  function slotNaturalWidth(kind) {
    var scale = (glanceBar.host.settings && glanceBar.host.settings.textScale) ? glanceBar.host.settings.textScale : 1.0
    switch (kind) {
    case "workspace": return Math.round(28 * scale)
    case "battery": return Math.round(64 * scale)
    case "volume": return Math.round(58 * scale)
    case "weather": return Math.round(58 * scale)
    case "network": {
      var net = glanceBar.host.activities.netConnected
      if (net && net.length > 0 && net[0].name) {
        return Math.min(Math.round(95 * scale), Math.max(Math.round(50 * scale), Math.round((net[0].name.length * 7 + 22) * scale)))
      }
      return Math.round(60 * scale)
    }
    case "media": {
      var title = (glanceBar.host.nowPlaying && glanceBar.host.nowPlaying.title) ? glanceBar.host.nowPlaying.title : ""
      if (!title) return Math.round(60 * scale)
      return Math.min(Math.round(140 * scale), Math.max(Math.round(60 * scale), Math.round((title.length * 7 + 26) * scale)))
    }
    default: return 0
    }
  }

  readonly property real leftSideWidth: {
    var w = 0
    var c1 = left1Kind !== "none" && left1Kind !== ""
    var c2 = left2Kind !== "none" && left2Kind !== ""
    if (c1) w += slotNaturalWidth(left1Kind)
    if (c2) w += slotNaturalWidth(left2Kind)
    if (c1 && c2) w += 17
    return w
  }

  readonly property real rightSideWidth: {
    var w = 0
    var c1 = right1Kind !== "none" && right1Kind !== ""
    var c2 = right2Kind !== "none" && right2Kind !== ""
    if (c1) w += slotNaturalWidth(right1Kind)
    if (c2) w += slotNaturalWidth(right2Kind)
    if (c1 && c2) w += 17
    return w
  }

  readonly property real maxSideWidth: Math.max(leftSideWidth, rightSideWidth)
  readonly property real neededWidth: hasItems
    ? (sideMargin * 2 + Math.max(30, maxSideWidth) * 2 + Math.max(clockWidth, 60) + 48)
    : 0

  readonly property real sideMargin: glanceBar.host.settings.notch ? 18 : 16

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

  // --- Center Clock Exclusion Zone ---
  Item {
    id: centerReserve
    anchors.centerIn: parent
    width: Math.max(glanceBar.clockWidth, 60) + 24
    height: parent.height
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

      readonly property real containerWidth: netItem.parent && (netItem.parent === leftL1 || netItem.parent === leftL2)
        ? leftContainer.width : rightContainer.width
      readonly property real otherWidth: {
        if (netItem.parent === rightL1) return rightL2.item ? (rightL2.item.implicitWidth + 17) : 0
        if (netItem.parent === rightL2) return rightL1.item ? (rightL1.item.implicitWidth + 17) : 0
        if (netItem.parent === leftL1) return leftL2.item ? (leftL2.item.implicitWidth + 17) : 0
        if (netItem.parent === leftL2) return leftL1.item ? (leftL1.item.implicitWidth + 17) : 0
        return 45
      }
      readonly property real maxNetTextWidth: Math.max(30, Math.min(80, containerWidth - otherWidth - 20))

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
          width: Math.min(implicitWidth, netItem.maxNetTextWidth)
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

      readonly property real containerWidth: mediaItem.parent && (mediaItem.parent === leftL1 || mediaItem.parent === leftL2)
        ? leftContainer.width : rightContainer.width
      readonly property real otherWidth: {
        if (mediaItem.parent === rightL1) return rightL2.item ? (rightL2.item.implicitWidth + 17) : 0
        if (mediaItem.parent === rightL2) return rightL1.item ? (rightL1.item.implicitWidth + 17) : 0
        if (mediaItem.parent === leftL1) return leftL2.item ? (leftL2.item.implicitWidth + 17) : 0
        if (mediaItem.parent === leftL2) return leftL1.item ? (leftL1.item.implicitWidth + 17) : 0
        return 45
      }
      readonly property real maxTextWidth: Math.max(30, containerWidth - otherWidth - 21)

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
          width: Math.min(implicitWidth, mediaItem.maxTextWidth)
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

  // --- Left Container: Strictly bounded between parent.left and centerReserve.left ---
  Item {
    id: leftContainer
    visible: glanceBar.hasLeftItems
    anchors.left: parent.left
    anchors.leftMargin: glanceBar.sideMargin
    anchors.right: centerReserve.left
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    clip: true

    Row {
      id: leftSlot
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 7

      Loader {
        id: leftL1
        visible: !!item
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
        visible: !!item
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: glanceBar.componentFor(glanceBar.left2Kind)
      }
    }
  }

  // --- Right Container: Strictly bounded between centerReserve.right and parent.right ---
  Item {
    id: rightContainer
    visible: glanceBar.hasRightItems
    anchors.right: parent.right
    anchors.rightMargin: glanceBar.sideMargin
    anchors.left: centerReserve.right
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height
    clip: true

    Row {
      id: rightSlot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 7

      Loader {
        id: rightL1
        visible: !!item
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
        visible: !!item
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: glanceBar.componentFor(glanceBar.right2Kind)
      }
    }
  }
}
