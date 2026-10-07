pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../../../components"

// Static samples only: no live trackers, personal data, or ambient animations.
Item {
  id: preview
  required property var view
  required property string kind
  readonly property color accent: view.accent
  readonly property string iconFont: view.host.theme.fontFamily
  readonly property bool colorfulActivities: !!view.settings.colorfulLiveActivities
  readonly property bool transfer: kind === "downloads" || kind === "updates"
  readonly property color transferColor: colorfulActivities ? "#30d158" : accent
  readonly property string glyph: ({ media: "󰝚", clipboard: "󰆏", downloads: "󰁅", updates: "󰏗", bluetooth: "󰋋", network: "󰤨" })[kind] || ""

  Rectangle {
    id: pill
    anchors.centerIn: parent
    width: 196
    height: preview.kind === "bluetooth" ? 52 : 40
    scale: Math.min(1.06, preview.width / width)
    radius: height / 2
    color: "#000000"
    border.width: 0
    clip: true
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: "#000000"
      shadowOpacity: 0.28
      shadowBlur: 0.55
      shadowVerticalOffset: 3
    }

    VolumeLevel {
      anchors.fill: parent
      visible: preview.kind === "volume" || preview.kind === "brightness"
      theme: preview.view.host.theme
      level: preview.kind === "brightness" ? 0.4 : 0.18
      icon: preview.kind === "brightness" ? "󰍹" : ""
      animateLevel: false
    }
    Row {
      anchors.centerIn: parent
      visible: preview.kind === "workspace"
      spacing: 9
      Repeater {
        model: 5
        delegate: Item {
          id: workspace
          required property int index
          width: 20; height: 20
          Rectangle {
            anchors.centerIn: parent
            width: workspace.index === 1 ? 24 : 6
            height: workspace.index === 1 ? 18 : 6
            radius: height / 2
            color: workspace.index === 1 ? (preview.colorfulActivities ? "#ffffff" : preview.accent) : workspace.index < 3 ? "#aaaaaa" : "#444444"
            Text {
              anchors.centerIn: parent
              visible: workspace.index === 1
              text: "2"
              color: preview.colorfulActivities ? "#000000" : preview.view.accentInk
              font.family: preview.view.host.theme.textFontFamily
              font.pixelSize: preview.view.host.theme.px(11)
              font.weight: Font.Bold
            }
          }
        }
      }
    }

    // Shared leading glyph: album-cover tile, transfer ring, or device icon.
    Rectangle {
      id: leading
      x: preview.kind === "media" ? 8 : 12
      anchors.verticalCenter: parent.verticalCenter
      width: 28; height: 28
      visible: preview.glyph !== ""
      radius: preview.transfer ? 14 : 7
      color: preview.kind === "media" ? Qt.tint("#252525", preview.view.host.theme.withAlpha(preview.accent, 0.5)) : "transparent"
      border.width: preview.transfer ? 2 : 0
      border.color: preview.transfer ? preview.transferColor : preview.accent
      Text {
        anchors.centerIn: parent
        visible: preview.glyph !== ""
        text: preview.glyph
        color: preview.kind === "bluetooth" || preview.kind === "media" ? "#ffffff" : preview.transfer ? preview.transferColor : preview.accent
        font.family: preview.iconFont
        font.pixelSize: preview.kind === "bluetooth" ? preview.view.host.theme.px(27) : preview.transfer ? preview.view.host.theme.px(13) : preview.view.host.theme.px(17)
      }
    }
    BatteryIcon {
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      visible: preview.kind === "battery"
      width: 25; height: 12
      level: 64
      charging: true
      chargingColor: preview.colorfulActivities ? "#30d158" : preview.accent
      lowColor: preview.colorfulActivities ? "#ff453a" : preview.accent
    }
    Text {
      x: preview.kind === "battery" ? 47 : preview.transfer ? 57 : 43
      anchors.verticalCenter: parent.verticalCenter
      visible: preview.kind === "battery" || preview.kind === "clipboard" || preview.transfer || preview.kind === "network"
      text: ({ battery: "Charging", clipboard: "Hello, world!", network: "Home" })[preview.kind] || "12:34"
      color: "#ffffff"
      font.family: preview.view.host.theme.textFontFamily
      font.pixelSize: preview.transfer ? preview.view.host.theme.px(12) : preview.view.host.theme.px(10)
      font.weight: preview.transfer ? Font.DemiBold : Font.Normal
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      visible: preview.kind === "battery" || preview.kind === "clipboard" || preview.transfer || preview.kind === "network"
      text: ({ battery: "64%", clipboard: "Copied", updates: "Updating", downloads: "2 MB/s", network: "Connected" })[preview.kind] || ""
      color: preview.kind === "battery" ? (preview.colorfulActivities ? "#30d158" : preview.accent) : preview.kind === "clipboard" ? preview.accent : preview.kind === "network" ? preview.accent : preview.transfer ? preview.transferColor : "#ffffff"
      font.family: preview.view.host.theme.textFontFamily
      font.pixelSize: preview.view.host.theme.px(10)
      font.weight: Font.DemiBold
    }
    Column {
      x: 52
      anchors.verticalCenter: parent.verticalCenter
      visible: preview.kind === "bluetooth"
      spacing: 1
      Text {
        text: "Connected"
        color: "#888888"
        font.family: preview.view.host.theme.textFontFamily
        font.pixelSize: preview.view.host.theme.px(10)
      }
      Text { text: "Headphones"; color: "#ffffff"; font.family: preview.view.host.theme.textFontFamily; font.pixelSize: preview.view.host.theme.px(12) }
    }
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      visible: preview.kind === "bluetooth"
      width: 30; height: 30; radius: 15
      color: "transparent"
      border.width: 2
      border.color: preview.colorfulActivities ? "#30d158" : preview.accent
      Text { anchors.centerIn: parent; text: "72"; color: preview.colorfulActivities ? "#30d158" : preview.accent; font.family: preview.view.host.theme.textFontFamily; font.pixelSize: preview.view.host.theme.px(10) }
    }
    Text {
      anchors.centerIn: parent
      visible: preview.kind === "media"
      text: "12:34"
      color: "#ffffff"
      font.family: preview.view.host.theme.textFontFamily
      font.pixelSize: preview.view.host.theme.px(12)
      font.weight: Font.DemiBold
    }
    Row {
      anchors.right: parent.right
      anchors.rightMargin: 15
      anchors.verticalCenter: parent.verticalCenter
      visible: preview.kind === "media"
      spacing: 3
      Repeater {
        model: [8, 16, 22, 12, 18]
        delegate: Rectangle {
          required property int modelData
          anchors.verticalCenter: parent.verticalCenter
          width: 3; height: modelData; radius: 1.5
          color: preview.accent
        }
      }
    }
  }
}
