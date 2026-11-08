import QtQuick
import QtQuick.Layouts
import "../../components"

// The plugins not yet pinned, in the add panel (see AddPanel): a card each,
// like the controls'. Click its + to pin it, or drag it onto the Plugins zone
// (which the drag brings in if it isn't there) to pin it where it's dropped:
// the zone (see PluginsZone) takes the drag, as the control grid does for the
// controls'. `panel` is the AddPanel.
ColumnLayout {
  id: gallery
  required property var panel
  readonly property var cc: panel.center
  // The Plugins addon, once it's on: it has the list of plugins.
  readonly property var addon: cc.host.addons.root("plugins")
  readonly property string zoneId: "addon:plugins/pinned"
  // While a drag has brought the zone in; it goes again if the card isn't
  // dropped on it.
  property bool zoneForDrag: false
  // All of them while the zone is away: pins are kept without it (tiles from
  // before the zone existed are), and pinning one brings it and them back.
  readonly property var plugins: !addon ? [] : zoneForDrag || cc.zones.absent.indexOf(zoneId) !== -1 ? addon.all : addon.unpinned
  // The zone, while it's in the Control Center: what a card is dragged through.
  readonly property var zone: cc.pluginsZone
  readonly property string draggedId: zone && zone.dragFromPanel ? zone.draggedId : ""
  function settleDrag(landed) {
    if (zoneForDrag && !landed) cc.zones.remove(zoneId)
    zoneForDrag = false
  }

  spacing: 8

  GridLayout {
    Layout.fillWidth: true
    visible: gallery.plugins.length > 0
    columns: gallery.panel.cardColumns
    columnSpacing: 0
    rowSpacing: 0
    Repeater {
      model: gallery.plugins
      delegate: Item {
        id: card
        required property var modelData
        Layout.preferredWidth: gallery.panel.cardWidth
        Layout.preferredHeight: gallery.cc.tileHeight + 8
        scale: dragMouse.pressed ? 0.98 : 1
        Behavior on scale { MotionAnimation { theme: gallery.cc.host.theme; pace: dragMouse.pressed ? "press" : "standard" } }
        CcTile {
          anchors.fill: parent
          anchors.margins: 4
          enabled: false
          center: gallery.cc
          icon: "󰐱"
          title: card.modelData.name
          subtitle: card.modelData.id
          checked: card.modelData.enabled
        }
        MouseArea {
          id: dragMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          preventStealing: true
          property real pressX: 0
          property real pressY: 0
          onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            if ((!gallery.zone || gallery.zone.draggedId === "") && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
            if (!gallery.zone) {
              gallery.zoneForDrag = true
              gallery.cc.zones.ensure(gallery.zoneId)
              if (!gallery.zone) return
            }
            // Held where it was taken (the card is inset by 4).
            if (gallery.zone.draggedId === "")
              gallery.zone.beginDrag(card.modelData.id, true, card.width - 8, card.height - 8, pressX - 4, pressY - 4)
            gallery.zone.moveDrag(dragMouse, mouse.x, mouse.y)
          }
          onReleased: function(mouse) {
            var landed = false
            if (gallery.draggedId === card.modelData.id) {
              gallery.zone.moveDrag(dragMouse, mouse.x, mouse.y)
              landed = gallery.zone.dropActive
              gallery.zone.finishDrag()
            }
            gallery.settleDrag(landed)
          }
          onCanceled: {
            if (gallery.zone) gallery.zone.endDrag()
            gallery.settleDrag(false)
          }
        }
        Item {
          anchors.fill: parent
          anchors.margins: 4
          CcEditBadge {
            center: gallery.cc
            adding: true
            shown: gallery.draggedId !== card.modelData.id
            cornerRadius: gallery.cc.cardRadius
            tip: "Pin " + card.modelData.name
            onClicked: {
              gallery.addon.pin(card.modelData.id)
              gallery.cc.zones.ensure(gallery.zoneId)
            }
          }
        }
        Tooltip { theme: gallery.cc.host.theme; text: "Drag to Plugins, or pin " + card.modelData.name }
      }
    }
  }
  Text {
    visible: gallery.plugins.length === 0
    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.bottomMargin: 8
    horizontalAlignment: Text.AlignHCenter
    text: !gallery.addon ? "Add the Plugins or Plugin List zone to pin plugins"
      : gallery.addon.all.length ? "All plugins have been pinned"
      : gallery.addon.loading ? "Loading…" : "No plugins added"
    color: gallery.cc.textMuted
    font.family: gallery.cc.host.theme.textFontFamily
    font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.px(13))
    font.pixelSize: gallery.cc.host.theme.px(13)
  }
}
