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
  readonly property color textMuted: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.6))
  readonly property color tile: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.11))
  readonly property color card: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.075))
  readonly property color edge: host.theme.withAlpha(text, 0.05)
  readonly property color well: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.16))
  readonly property color wellHover: Qt.tint(host.theme.background, host.theme.withAlpha(text, 0.22))
  readonly property string iconFont: host.theme.fontFamily
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

  spacing: 10

  // Esc leaves edit mode, then closes the control center.
  Keys.onEscapePressed: {
    if (cc.editMode) { cc.editMode = false; controlLayout.endDrag() }
    else cc.host.view = "rest"
  }

  // ---------- Header ----------

  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    Text {
      text: "Control Center"
      color: cc.text
      font.family: cc.host.theme.textFontFamily
      font.pixelSize: cc.host.theme.px(17)
      font.weight: Font.DemiBold
    }
    Item { Layout.fillWidth: true }
    Rectangle {
      Layout.preferredWidth: cc.editMode ? 64 : 32
      Layout.preferredHeight: 32
      radius: 16
      color: editMouse.containsMouse || cc.editMode ? cc.well : cc.card
      Tooltip { theme: cc.host.theme; text: cc.editMode ? "" : "Edit Controls" }
      Text {
        anchors.centerIn: parent
        text: cc.editMode ? "Done" : "󰏫"
        color: cc.text
        font.family: cc.editMode ? cc.host.theme.textFontFamily : cc.iconFont
        font.pixelSize: cc.editMode ? cc.host.theme.px(12) : cc.host.theme.px(17)
        font.weight: Font.DemiBold
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
      Layout.preferredWidth: 32
      Layout.preferredHeight: 32
      radius: 16
      color: settingsMouse.containsMouse ? cc.well : cc.card
      Tooltip { theme: cc.host.theme; text: "Island Settings" }
      Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: cc.text
        font.family: cc.iconFont
        font.pixelSize: cc.host.theme.px(17)
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
        color: parent.low ? "#ff453a" : cc.text
        font.family: cc.host.theme.textFontFamily
        font.pixelSize: cc.host.theme.px(13)
        font.weight: Font.DemiBold
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
      opens: (parent.controlKey === "bluetooth" && !!cc.controls.btAdapter) || (parent.controlKey === "wifi" && !!cc.controls.wifiDevice)
      onClicked: cc.controls.toggleControl(parent.controlKey)
      onOpened: cc.host.view = parent.controlKey
    }
  }
  Component { id: soundCard; SoundCard { center: cc } }
  Component { id: microphoneCard; MicrophoneCard { center: cc } }
  Component { id: displayCard; DisplayCard { center: cc } }
}
