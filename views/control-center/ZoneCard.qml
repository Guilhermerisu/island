import QtQuick
import QtQuick.Layouts
import "../../addons"
import "../../components"

// One zone of the control center, in its column: what it holds (the control
// grid, the notifications, or an addon's zone, see addons/Addon.qml) and, in
// edit mode, a title bar that moves it and the − that removes it. In edit
// mode only the grid keeps its content, as it has its own editing; the
// others are just their bar.
// `center` is the ControlCenter, `zoneBoard` the ZoneColumns, `zoneId` the zone,
// `columnWidth` the width its column will have once the island has its width.
ColumnLayout {
  id: zone
  required property var center
  required property var zoneBoard
  required property string zoneId
  required property real columnWidth
  readonly property var info: center.zones.definition(zoneId)
  readonly property bool isAddon: !!(info && info.addon)
  readonly property var addonRoot: isAddon ? center.host.addons.root(info.addon) : null
  // A zone the addon draws itself: its `zone`, or the one of its `zones` this
  // is. Without, its first view or Settings page in a card (see AddonZone).
  readonly property var ownComponent: !addonRoot ? null : info.key ? (addonRoot.zones || {})[info.key] || null : addonRoot.zone
  readonly property bool hasContent: !!addonRoot && ((addonRoot.views || []).length > 0 || (addonRoot.settingsPages || []).length > 0)
  readonly property var bodyComponent: ownComponent || (hasContent ? mountedZone : null)
  Component { id: mountedZone; AddonZone { mount: true } }
  // In edit mode only a zone with its own editing keeps its content.
  readonly property bool showsBody: !center.editMode || !!(info && info.editable)
  // Judged by the column's final width, so the zone doesn't flip between its
  // content and the warning while the island is still growing.
  // The registry's minWidth, else what the addon's first view asks of the
  // island (its width less its padding, plus the card's own), known once the
  // addon is on.
  readonly property real minWidth: {
    if (!isAddon) return 0
    if (info.minWidth > 0) return info.minWidth
    var view = addonRoot && (addonRoot.views || [])[0]
    return view && view.width > 0 ? view.width - 2 * (view.padding === undefined ? 16 : view.padding) + 32 : 0
  }
  readonly property bool tooNarrow: minWidth > 0 && columnWidth < minWidth
  readonly property bool addonOff: isAddon && !center.host.addons.isEnabled(info.addon)
  // Made the first time the control center opens, then kept.
  property bool opened: center.active
  Connections {
    target: zone.center
    function onActiveChanged() { if (zone.center.active) zone.opened = true }
  }
  spacing: center.gap
  // Fades and grows in once made (a zone added, or moved to another column).
  property bool appeared: false
  Component.onCompleted: appeared = true
  opacity: !appeared ? 0 : zoneBoard.draggedId === zoneId ? 0.4 : 1
  Behavior on opacity { MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
  scale: appeared ? 1 : 0.96
  Behavior on scale { enabled: zone.zoneBoard.animating; MotionAnimation { theme: zone.center.host.theme; pace: "standard" } }

  // The column's layout places it at once; it's drawn from where it was and
  // eases there, so sizes are never in doubt. Not until the layout has first
  // placed it, or a new zone would slide down from the column's top.
  transform: Translate { id: slide }
  MotionAnimation { id: slideHome; target: slide; property: "y"; to: 0; theme: zone.center.host.theme; pace: "standard" }
  property bool placed: false
  property real lastY: 0
  Timer { interval: 50; running: true; onTriggered: { zone.lastY = zone.y; zone.placed = true } }
  onYChanged: {
    if (placed && zoneBoard.animating) {
      slide.y += lastY - y
      slideHome.restart()
    }
    lastY = y
  }

  Rectangle {
    id: bar
    visible: zone.center.editMode
    opacity: visible ? 1 : 0
    Behavior on opacity { enabled: zone.center.settled; MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
    Layout.fillWidth: true
    Layout.preferredHeight: 28
    radius: Math.min(zone.center.cardRadius, height / 2)
    color: zone.center.card
    border.width: 1
    border.color: zone.center.edge
    // Six dots, the grip.
    Grid {
      anchors.verticalCenter: parent.verticalCenter
      x: 14
      columns: 2
      spacing: 3
      Repeater {
        model: 6
        Rectangle { width: 3; height: 3; radius: 1.5; color: zone.center.textMuted }
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      x: 32
      text: zone.info ? zone.info.icon : ""
      color: zone.center.textMuted
      font.family: zone.center.iconFont
      font.pixelSize: zone.center.host.theme.px(14)
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      x: 54
      text: zone.info ? zone.info.title : zone.zoneId
      color: zone.center.text
      font.family: zone.center.host.theme.textFontFamily
      font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.callout)
      font.pixelSize: zone.center.host.theme.size.callout
      font.weight: Font.DemiBold
    }
    HoverHandler { cursorShape: dragger.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
    // Only follows the pointer: the board moves a stand-in for the zone.
    DragHandler {
      id: dragger
      target: null
      onActiveChanged: {
        if (active) zone.zoneBoard.beginDrag(zone.zoneId, Qt.size(bar.width, bar.height), centroid.pressPosition, centroid.scenePosition)
        else zone.zoneBoard.finishDrag()
      }
      onCentroidChanged: if (active) zone.zoneBoard.moveDrag(centroid.scenePosition)
    }
    CcEditBadge {
      center: zone.center
      shown: zone.zoneBoard.draggedId !== zone.zoneId
      cornerRadius: bar.radius
      tip: "Remove"
      onClicked: zone.center.zones.remove(zone.zoneId)
    }
  }

  // The grid and the notifications.
  Loader {
    active: !zone.isAddon
    visible: active && (zone.zoneId === "controls" || !zone.center.editMode)
    opacity: visible ? 1 : 0
    Behavior on opacity { enabled: zone.center.settled; MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
    Layout.fillWidth: true
    // The notifications sit a little off the grid above them.
    Layout.topMargin: zone.zoneId === "notifications" ? 4 : 0
    Layout.preferredHeight: item ? item.implicitHeight : 0
    sourceComponent: zone.zoneId === "controls" ? controlsZone : notificationsZone
  }
  Component { id: controlsZone; ControlLayout { center: zone.center } }
  Component { id: notificationsZone; NotificationHistory { center: zone.center } }

  // An addon's zone: made in this loader, so the component's parent has
  // `center` and `zoneActive`; as wide as the column, as tall as it is.
  Loader {
    id: addonBody
    property var center: zone.center
    property bool zoneActive: zone.center.active
    property var addonRoot: zone.addonRoot
    active: zone.isAddon && !!zone.bodyComponent && !zone.tooNarrow && zone.opened
    visible: active && zone.showsBody
    opacity: visible ? 1 : 0
    Behavior on opacity { enabled: zone.center.settled; MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
    Layout.fillWidth: true
    Layout.preferredHeight: item ? item.implicitHeight : 0
    sourceComponent: zone.bodyComponent
  }
  // In its place while the addon is off or loading, or the column too narrow.
  Rectangle {
    visible: zone.isAddon && zone.showsBody && !addonBody.active
    Layout.fillWidth: true
    Layout.preferredHeight: zone.addonOff || zone.tooNarrow ? 64 : zone.center.tileHeight * 0.7
    radius: zone.center.cardRadius
    color: zone.center.card
    border.width: 1
    border.color: zone.center.edge
    Column {
      anchors.centerIn: parent
      width: parent.width - 24
      spacing: 2
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: zone.addonOff ? zone.info.name + " is off"
          : zone.tooNarrow ? zone.info.name + " needs a wider column"
          : zone.addonRoot && !zone.bodyComponent ? "Nothing to show" : "Loading…"
        color: zone.addonOff || zone.tooNarrow ? zone.center.text : zone.center.textMuted
        font.family: zone.center.host.theme.textFontFamily
        font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.callout)
        font.pixelSize: zone.center.host.theme.size.callout
        font.weight: zone.addonOff || zone.tooNarrow ? Font.DemiBold : Font.Normal
      }
      Text {
        visible: zone.addonOff || zone.tooNarrow
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: zone.addonOff ? "Turn On" : "Use fewer columns"
        color: zone.addonOff ? zone.center.accent : zone.center.textMuted
        font.family: zone.center.host.theme.textFontFamily
        font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.subheadline)
        font.pixelSize: zone.center.host.theme.size.subheadline
        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          enabled: zone.addonOff
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: zone.center.host.addons.setEnabled(zone.info.addon, true)
        }
      }
    }
  }
}
