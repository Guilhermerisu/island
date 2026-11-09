import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../../addons"
import "../../components"
import "zones.js" as ZoneModel

// A compact Control Center with grouped switches, sliders, and notifications.
// What the controls show and do is in Controls.qml, the grid and editing it
// in ControlLayout.qml; the cards are their own files. Under the header, its
// zones (the grid, the notifications, addons') sit in 1 to 3 columns: which
// and where is in Zones.qml, how they're drawn and moved in ZoneColumns.qml.
ColumnLayout {
  id: cc
  required property var host
  property bool active: false
  readonly property Controls controls: Controls { host: cc.host }
  readonly property Zones zones: Zones { host: cc.host }
  // The grid's layout while its zone is on show (it sets itself), and the
  // panel that adds to it: they take each other's drags.
  property var controlLayout: null
  // The Plugins zone's likewise (PluginsZone sets itself).
  property var pluginsZone: null
  readonly property Item addPanel: addPanelItem
  readonly property Item zoneBoard: zoneBoardItem
  // The card lifted by a drag in edit mode, whichever zone it's from.
  readonly property DragProxy dragProxy: dragProxyItem
  // What the Settings pages mounted as zones have as their `view`.
  readonly property ZoneLook zoneLook: zoneLookItem

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
  // A picker whose list went empty closes (its card leaves the grid), so it
  // doesn't pop back open when a device returns.
  Connections {
    target: cc.controls
    function onOutputsChanged() { if (!cc.controls.outputs.length) cc.outputsOpen = false }
    function onInputsChanged() { if (!cc.controls.inputs.length) cc.inputsOpen = false }
  }
  // Off for the first layout each time it opens, so the header's controls
  // change shape only for what's done while it's showing.
  property bool settled: false
  Timer {
    id: settleTimer
    interval: cc.host.theme.motionDuration("morph")
    onTriggered: cc.settled = cc.active
  }

  // The island's width follows the columns showing (all of them while
  // editing, else the ones with a zone in them), within a share of the
  // screen. `surfacePadding` is the island's around the view, set by Views.
  property real surfacePadding: 16
  readonly property int shownColumns: editMode ? zones.columns : zones.occupied
  readonly property real islandWidth: ZoneModel.islandWidth(shownColumns, Window.width, gap)
  // What the columns share (ZoneColumns divides it); the island's final
  // width, not the one it is growing to.
  readonly property real columnsSpace: ZoneModel.columnsSpace(shownColumns, islandWidth, surfacePadding, gap)

  onEditModeChanged: {
    outputsOpen = false
    inputsOpen = false
    cc.forceActiveFocus()
  }
  onActiveChanged: {
    // Reset on open, not on close, so the view keeps its shape while it
    // fades out with the collapsing island.
    settled = false
    if (!active) return
    settleTimer.restart()
    outputsOpen = false
    inputsOpen = false
    editMode = false
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

  // Esc closes a zone's menu, leaves edit mode, then closes the control center.
  Keys.onEscapePressed: {
    if (cc.zoneLook.menuButton) cc.zoneLook.menuButton = null
    else if (cc.editMode) cc.editMode = false
    else cc.host.view = "rest"
  }

  // ---------- Header ----------

  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: 30
    Layout.leftMargin: 6
    Layout.rightMargin: 2
    spacing: 6
    // Today's date as the title ("Wed, Oct 21"); Edit while editing.
    Text {
      text: cc.editMode ? "Edit" : Qt.locale("en_US").toString(cc.host.clockDate, "ddd, MMM d")
      color: cc.text
      font.family: cc.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.pixelSize: cc.host.theme.px(15)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
    }
    Item { Layout.fillWidth: true }
    // How many columns, while editing: the choice is saved as it's made.
    Rectangle {
      visible: cc.editMode
      opacity: visible ? 1 : 0
      Behavior on opacity { enabled: cc.settled; MotionAnimation { theme: cc.host.theme; pace: "fade"; curve: "fade" } }
      Layout.preferredWidth: 3 * 30 + 4
      Layout.preferredHeight: 28
      radius: 14
      color: cc.card
      Repeater {
        model: [1, 2, 3]
        delegate: Rectangle {
          id: choice
          required property int modelData
          readonly property bool current: cc.zones.columns === modelData
          x: 2 + (modelData - 1) * 30
          y: 2
          width: 30
          height: 24
          radius: 12
          color: current ? cc.well : choiceMouse.containsMouse ? cc.wellHover : "transparent"
          Behavior on color { MotionColorAnimation { theme: cc.host.theme } }
          Tooltip { theme: cc.host.theme; text: modelData === 1 ? "1 column" : modelData + " columns" }
          Text {
            anchors.centerIn: parent
            text: choice.modelData
            color: choice.current ? cc.text : cc.textMuted
            font.family: cc.host.theme.textFontFamily
            font.features: { "tnum": 1 }
            font.pixelSize: cc.host.theme.px(12)
            font.weight: Font.DemiBold
          }
          MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cc.zones.setColumns(choice.modelData)
          }
        }
      }
    }
    Rectangle {
      scale: editMouse.pressed ? 0.92 : 1
      Behavior on scale { MotionAnimation { theme: cc.host.theme; pace: editMouse.pressed ? "press" : "standard" } }
      Layout.preferredWidth: cc.editMode ? 58 : 28
      Layout.preferredHeight: 28
      radius: 14
      clip: true
      color: editTip.hovered || cc.editMode ? cc.well : "transparent"
      // The pencil widens into Done, as Clear All does, cross-fading the two;
      // not while opening, when edit mode is reset.
      Behavior on Layout.preferredWidth { enabled: cc.settled; MotionAnimation { theme: cc.host.theme; pace: "standard" } }
      Behavior on color { MotionColorAnimation { theme: cc.host.theme } }
      Tooltip { id: editTip; theme: cc.host.theme; text: cc.editMode ? "" : "Edit" }
      Text {
        anchors.centerIn: parent
        opacity: cc.editMode ? 0 : 1
        visible: opacity > 0.01
        text: "󰏫"
        color: cc.text
        font.family: cc.iconFont
        font.pixelSize: cc.host.theme.px(15)
        Behavior on opacity { enabled: cc.settled; MotionAnimation { theme: cc.host.theme; pace: "fade"; curve: "fade" } }
      }
      Text {
        anchors.centerIn: parent
        opacity: cc.editMode ? 1 : 0
        visible: opacity > 0.01
        text: "Done"
        color: cc.text
        font.family: cc.host.theme.textFontFamily
        font.letterSpacing: cc.host.theme.tracking(cc.host.theme.textFontFamily, cc.host.theme.px(12))
        font.pixelSize: cc.host.theme.px(12)
        font.weight: Font.Medium
        Behavior on opacity { enabled: cc.settled; MotionAnimation { theme: cc.host.theme; pace: "fade"; curve: "fade" } }
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
      color: settingsTip.hovered ? cc.well : "transparent"
      Behavior on color { MotionColorAnimation { theme: cc.host.theme } }
      Tooltip { id: settingsTip; theme: cc.host.theme; text: "Island Settings" }
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
      // Time left, only when discharging with an estimate (UPower reports 0
      // otherwise); hidden while editing, when the header has no room to spare.
      readonly property real secondsLeft: UPower.onBattery && !cc.controls.charging ? cc.controls.battery.timeToEmpty : 0
      Text {
        visible: !cc.editMode && parent.secondsLeft > 0
        anchors.verticalCenter: parent.verticalCenter
        text: {
          var m = Math.round(parent.secondsLeft / 60)
          return m >= 60 ? Math.floor(m / 60) + "h " + m % 60 + "m" : m + "m"
        }
        color: cc.textMuted
        font.family: cc.host.theme.textFontFamily
        font.letterSpacing: cc.host.theme.tracking(cc.host.theme.textFontFamily, cc.host.theme.px(13))
        font.pixelSize: cc.host.theme.px(13)
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
      }
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

  ZoneColumns { id: zoneBoardItem; center: cc }

  Rectangle {
    visible: !cc.editMode && cc.zones.empty
    Layout.fillWidth: true
    Layout.preferredHeight: cc.tileHeight
    radius: cc.cardRadius
    color: cc.card
    border.width: 1
    border.color: cc.edge
    Text {
      anchors.centerIn: parent
      text: "Click the pencil to add zones"
      color: cc.textMuted
      font.family: cc.host.theme.textFontFamily
      font.letterSpacing: cc.host.theme.tracking(cc.host.theme.textFontFamily, cc.host.theme.px(12))
      font.pixelSize: cc.host.theme.px(12)
    }
  }

  AddPanel { id: addPanelItem; center: cc }

  // Over the whole control center, beside it rather than inside the layout.
  // Sized by bindings, not anchors: anchors could resolve before the new
  // parent is set, and an anchor to a non-sibling is dropped.
  Item {
    parent: cc.parent
    x: cc.x
    y: cc.y
    width: cc.width
    height: cc.height
    z: 100
    DragProxy { id: dragProxyItem; center: cc }
    ZoneLook { id: zoneLookItem; center: cc; anchors.fill: parent }
  }

  // ---------- Cards, loaded by the grid and the add panel ----------

  Component {
    id: quickCard
    CcTile {
      center: cc
      anchors.fill: parent
      icon: cc.controls.controlIcon(parent.controlKey)
      title: cc.controls.controlTitle(parent.controlKey, width < 190)
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
