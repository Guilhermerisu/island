import QtQuick
import QtQuick.Layouts
import "../../components"

// A compact Control Center with grouped switches, sliders, and notifications.
// What the controls show and do is in Controls.qml, the grid and editing it
// in ControlLayout.qml; the cards are their own files.
ColumnLayout {
  id: cc
  required property var host
  property bool active: false
  readonly property Controls controls: Controls { host: cc.host }

  // Keep the black island while deriving its controls from the active theme.
  readonly property color accent: host.theme.accent
  readonly property color accentInk: host.theme.accentText
  readonly property color text: host.theme.text
  readonly property color textMuted: host.theme.secondary
  readonly property color tile: host.theme.tile
  readonly property color card: host.theme.card
  readonly property color edge: host.theme.hairline
  readonly property color well: host.theme.well
  readonly property color wellHover: host.theme.wellHover
  readonly property string iconFont: host.theme.fontFamily
  // macOS shapes: switches are capsules, cards concentric with the island.
  readonly property real cardRadius: host.theme.radii.card
  // macOS's module sizes: a tile, a slider card, and the gap between them.
  readonly property real tileHeight: 64
  readonly property real sectionHeight: 86
  readonly property real gap: 8
  // The icon on a switched-on (accent) badge: white, as macOS's on blue,
  // or a deep shade of the accent when it's too light for white.
  readonly property color badgeOnInk: accent.hslLightness < 0.62 ? "#ffffff" : Qt.hsla(accent.hslHue, accent.hslSaturation, 0.16, 1)
  property bool editMode: false
  property bool outputsOpen: false
  property bool inputsOpen: false
  onEditModeChanged: {
    outputsOpen = false
    inputsOpen = false
    cc.forceActiveFocus()
  }
  onActiveChanged: {
    if (!active) { outputsOpen = false; inputsOpen = false; editMode = false; controlLayout.endDrag(); return }
    Qt.callLater(function() { cc.forceActiveFocus() })
    controls.refresh()
  }
  function controlComponent(key) {
    var tile = host.addons.tileFor(key)
    if (tile) return tile.component
    if (key === "sound") return soundCard
    if (key === "microphone") return microphoneCard
    if (key === "display") return displayCard
    return quickCard
  }

  spacing: cc.gap

  // Esc leaves edit mode, then closes the control center.
  Keys.onEscapePressed: {
    if (cc.editMode) { cc.editMode = false; controlLayout.endDrag() }
    else cc.host.view = "rest"
  }

  // ---------- Header ----------

  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: 30
    Layout.leftMargin: 6
    Layout.rightMargin: 2
    spacing: 6
    // Today's date as the title ("Wed, Oct 21"); Edit Controls while editing.
    Text {
      text: cc.editMode ? "Edit Controls" : Qt.locale("en_US").toString(cc.host.clockDate, "ddd, MMM d")
      color: cc.text
      font.family: cc.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.pixelSize: cc.host.theme.px(15)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
    }
    Item { Layout.fillWidth: true }
    Rectangle {
      scale: editMouse.pressed ? 0.92 : 1
      Behavior on scale { MotionAnimation { theme: cc.host.theme; pace: editMouse.pressed ? "press" : "standard" } }
      Layout.preferredWidth: cc.editMode ? 58 : 28
      Layout.preferredHeight: 28
      radius: 14
      color: editMouse.containsMouse || cc.editMode ? cc.well : cc.card
      Tooltip { theme: cc.host.theme; text: cc.editMode ? "" : "Edit Controls" }
      Text {
        anchors.centerIn: parent
        text: cc.editMode ? "Done" : "󰏫"
        color: cc.text
        font.family: cc.editMode ? cc.host.theme.textFontFamily : cc.iconFont
        font.letterSpacing: cc.host.theme.tracking(cc.editMode ? cc.host.theme.textFontFamily : cc.iconFont, cc.editMode ? cc.host.theme.px(12) : cc.host.theme.px(15))
        font.pixelSize: cc.editMode ? cc.host.theme.px(12) : cc.host.theme.px(15)
        font.weight: Font.Medium
      }
      MouseArea {
        id: editMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cc.editMode = !cc.editMode
      }
    }
    Rectangle {
      scale: settingsMouse.pressed ? 0.92 : 1
      Behavior on scale { MotionAnimation { theme: cc.host.theme; pace: settingsMouse.pressed ? "press" : "standard" } }
      Layout.preferredWidth: 28
      Layout.preferredHeight: 28
      radius: 14
      color: settingsMouse.containsMouse ? cc.well : cc.card
      Tooltip { theme: cc.host.theme; text: "Island Settings" }
      Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: cc.text
        font.family: cc.iconFont
        font.pixelSize: cc.host.theme.px(15)
      }
      MouseArea {
        id: settingsMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cc.host.view = "settings"
      }
    }
    // Battery, as macOS's menu bar shows it: the percentage, then a battery
    // filled to the level (green while charging, red when low), with a bolt
    // while charging.
    Row {
      visible: cc.controls.hasBattery
      Layout.leftMargin: 6
      Layout.rightMargin: 6
      spacing: 6
      readonly property bool low: cc.controls.batteryPercent <= 20 && !cc.controls.charging
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: cc.controls.batteryPercent + "%"
        color: parent.low ? cc.host.theme.system.red : cc.text
        font.family: cc.host.theme.textFontFamily
        font.letterSpacing: cc.host.theme.tracking(cc.host.theme.textFontFamily, cc.host.theme.px(13))
        font.pixelSize: cc.host.theme.px(13)
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
      }
      BatteryIcon {
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 14
        level: cc.controls.batteryPercent
        charging: cc.controls.charging
        low: parent.low
        color: cc.text
      }
    }
  }

  ControlLayout {
    id: controlLayout
    Layout.fillWidth: true
    center: cc
  }

  NotificationHistory { center: cc }

  // ---------- Cards, loaded by the grid and the gallery ----------

  Component {
    id: quickCard
    CcTile {
      center: cc
      anchors.fill: parent
      icon: cc.controls.controlIcon(parent.controlKey)
      title: cc.controls.controlTitle(parent.controlKey)
      subtitle: cc.controls.controlSubtitle(parent.controlKey)
      checked: cc.controls.controlChecked(parent.controlKey)
      available: parent.galleryPreview || cc.controls.controlAvailable(parent.controlKey)
      clickable: cc.controls.controlClickable(parent.controlKey)
      opens: (parent.controlKey === "bluetooth" && !!cc.controls.btAdapter) || (parent.controlKey === "wifi" && !!cc.controls.wifiDevice)
      onClicked: cc.controls.toggleControl(parent.controlKey)
      onOpened: cc.host.view = parent.controlKey
    }
  }
  Component { id: soundCard; SoundCard { center: cc } }
  Component { id: microphoneCard; MicrophoneCard { center: cc } }
  Component { id: displayCard; DisplayCard { center: cc } }
}
