import QtQuick
import QtQuick.Layouts
import "../../components"

// The zones that aren't in the control center, in the add panel (see
// AddPanel): a card each, like the controls' and plugins'. Click it or its +
// to add it, or drag it to a place in a column (see ZoneColumns, which carries
// it; an addon's zone switches the addon on, its badge lit if it's on already).
// `panel` is the AddPanel.
ColumnLayout {
  id: gallery
  required property var panel
  readonly property var center: panel.center
  readonly property var zones: center.zones
  readonly property var board: center.zoneBoard

  spacing: 8

  GridLayout {
    visible: gallery.zones.absent.length > 0
    Layout.fillWidth: true
    columns: gallery.panel.cardColumns
    columnSpacing: 0
    rowSpacing: 0
    Repeater {
      model: gallery.zones.absent
      delegate: Item {
        id: choice
        required property string modelData
        readonly property var info: gallery.zones.definition(modelData)
        readonly property string title: info ? info.title : modelData
        Layout.preferredWidth: gallery.panel.cardWidth
        Layout.preferredHeight: gallery.center.tileHeight + 8
        scale: addMouse.pressed ? 0.98 : 1
        Behavior on scale { MotionAnimation { theme: gallery.center.host.theme; pace: addMouse.pressed ? "press" : "standard" } }
        CcTile {
          anchors.fill: parent
          anchors.margins: 4
          enabled: false
          center: gallery.center
          icon: choice.info ? choice.info.icon : ""
          title: choice.title
          subtitle: choice.info ? choice.info.about : ""
          checked: !!choice.info && (!choice.info.addon || gallery.center.host.addons.isEnabled(choice.info.addon))
        }
        MouseArea {
          id: addMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          preventStealing: true
          property real pressX: 0
          property real pressY: 0
          property bool dragging: false
          onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y; dragging = false }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            if (!dragging && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
            var scene = mapToItem(null, mouse.x, mouse.y)
            if (dragging) { gallery.board.moveDrag(scene); return }
            dragging = true
            // Held where it was taken (the card is inset by 4).
            gallery.board.beginDrag(choice.modelData, Qt.size(choice.width - 8, choice.height - 8), Qt.point(pressX - 4, pressY - 4), scene)
          }
          onReleased: if (dragging) gallery.board.finishDrag()
          onCanceled: if (dragging) gallery.board.cancelDrag()
          onClicked: if (!dragging) gallery.zones.add(choice.modelData)
        }
        Item {
          anchors.fill: parent
          anchors.margins: 4
          CcEditBadge {
            center: gallery.center
            adding: true
            shown: gallery.board.draggedId !== choice.modelData
            cornerRadius: gallery.center.cardRadius
            tip: "Add " + choice.title
            onClicked: gallery.zones.add(choice.modelData)
          }
        }
        Tooltip { theme: gallery.center.host.theme; text: "Drag to a column, or add " + choice.title }
      }
    }
  }
  Text {
    visible: gallery.zones.absent.length === 0
    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.bottomMargin: 8
    horizontalAlignment: Text.AlignHCenter
    text: "All zones have been added"
    color: gallery.center.textMuted
    font.family: gallery.center.host.theme.textFontFamily
    font.letterSpacing: gallery.center.host.theme.tracking(gallery.center.host.theme.textFontFamily, gallery.center.host.theme.size.body)
    font.pixelSize: gallery.center.host.theme.size.body
  }
}
