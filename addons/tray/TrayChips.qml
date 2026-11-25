import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../components"

// The tray's apps as round icon chips, for the zone set XSmall or Small (see
// TrayZone): a block that wraps onto as many rows as the width asks (the zone
// is as tall as they are, nothing scrolls), where in XSmall a click on the
// card's bare part turns into the tray view. A chip does what an app's icon in the
// hover capsules does: left activates (or opens the menu of a menu-only app),
// right opens its menu in the tray view, middle is its secondary action; the
// name is the tooltip.
Item {
  id: chips
  required property var host
  required property var center
  property bool small: false
  // XSmall's room for one row is fixed (42), so the chip can follow it. Only
  // read in XSmall: Small is given none (infinite).
  property real room: 42
  readonly property real chip: small ? 32 : Math.min(38, room)
  readonly property real gap: 6
  readonly property var apps: SystemTray.items.values.filter(function(item) {
    return item.status !== Status.Passive
  })

  // XSmall is one line until the chips need more rows. Never derived from
  // the height given.
  implicitHeight: small ? Math.max(chip, flow.implicitHeight) : Math.max(room, flow.implicitHeight)

  function appTitle(item) {
    return String(item.tooltipTitle || item.title || item.id || "").trim()
  }
  // Close first so the app's window, not the island, gets the keyboard (as
  // TrayList does); a menu is the tray view's, as for the hover capsules.
  function open(item, button) {
    if (button === Qt.MiddleButton) { item.secondaryActivate(); return }
    if (button === Qt.RightButton || (item.onlyMenu && item.hasMenu)) {
      if (!item.hasMenu || !item.menu) return
      host.trayMenuFor = item
      host.view = "trayMenu"
      return
    }
    host.view = "rest"
    Qt.callLater(function() { item.activate() })
  }

  component Chip: Rectangle {
    id: chip
    required property var modelData
    width: chips.chip
    height: width
    radius: width / 2
    color: mouse.containsMouse || tip.hovered ? chips.center.wellHover : chips.center.well
    scale: mouse.pressed ? 0.92 : 1
    Behavior on color { MotionColorAnimation { theme: chips.host.theme } }
    Behavior on scale { id: scaleMotion1; MotionAnimation { theme: chips.host.theme; pace: towards(scaleMotion1.targetValue, mouse.pressed ? "press" : "standard") } }
    IconImage {
      id: icon
      anchors.centerIn: parent
      implicitSize: Math.round(chip.width * 0.6)
      visible: source != ""
      source: String(chip.modelData.icon || "")
    }
    Text {
      anchors.centerIn: parent
      visible: !icon.visible
      text: "󰀻"
      color: chips.center.textMuted
      font.family: chips.host.theme.fontFamily
      font.pixelSize: Math.round(chip.width * 0.5)
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(event) { chips.open(chip.modelData, event.button) }
    }
    Tooltip { id: tip; theme: chips.host.theme; text: chips.appTitle(chip.modelData) }
  }

  // Behind the chips: the XSmall zone's direct action.
  MouseArea {
    anchors.fill: parent
    enabled: !chips.small
    cursorShape: Qt.PointingHandCursor
    onClicked: chips.host.view = "tray"
  }
  Text {
    visible: chips.apps.length === 0
    anchors.verticalCenter: parent.verticalCenter
    text: "Nothing in the tray"
    color: chips.center.textMuted
    font.family: chips.host.theme.textFontFamily
    font.letterSpacing: chips.host.theme.tracking(chips.host.theme.textFontFamily, chips.host.theme.size.body)
    font.pixelSize: chips.host.theme.size.body
  }

  Flow {
    id: flow
    // One row sits centred in XSmall's line.
    y: small ? 0 : (chips.implicitHeight - flow.implicitHeight) / 2
    width: parent.width
    spacing: chips.gap
    Repeater { model: chips.apps; delegate: Chip {} }
  }
}
