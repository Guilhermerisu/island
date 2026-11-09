import QtQuick
import QtQuick.Layouts
import "../../components"

// The controls that aren't in the grid, in the add panel (see AddPanel): the
// same cards as the Control Center's, laid out in sections. Preview inputs
// are disabled: dragging a card in (or clicking its +) adds it without
// changing the represented setting. A card dragged out of the grid onto the
// panel is removed (see ControlLayout). Drags go through the grid's layout,
// `panel.layout`; with its zone out of the Control Center only the + works.
ColumnLayout {
  id: gallery
  required property var panel
  readonly property var cc: panel.center
  readonly property var controls: cc.controls
  readonly property var layout: panel.layout
  readonly property var sections: [
    { title: "Connectivity", keys: ["wifi", "bluetooth"] },
    { title: "Focus & System", keys: ["focus", "microphoneMute", "night", "awake", "screensaver", "screenshot", "screenrecord", "dictate", "reminder", "game", "power", "keyboard"] },
    { title: "Sound & Display", keys: ["sound", "microphone", "display"] },
    { title: "Addons", keys: gallery.cc.host.addons.tiles.map(function(tile) { return tile.key }) }
  ]
  readonly property bool hasResults: {
    for (var i = 0; i < sections.length; i++)
      if (keysFor(sections[i]).length) return true
    return false
  }
  function keysFor(section) {
    return section.keys.filter(function(key) {
      return !gallery.controls.isShown(key)
        && (!gallery.controls.isMicrophoneControl(key) || gallery.controls.controlPresent(key))
    })
  }

  spacing: 12

  Repeater {
    model: gallery.sections
    delegate: ColumnLayout {
      id: section
      required property var modelData
      readonly property var keys: gallery.keysFor(modelData)
      visible: keys.length > 0
      Layout.fillWidth: true
      spacing: 4
      Text {
        Layout.leftMargin: 6
        text: section.modelData.title
        color: gallery.cc.textMuted
        font.family: gallery.cc.host.theme.textFontFamily
        font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.size.callout)
        font.pixelSize: gallery.cc.host.theme.size.callout
        font.weight: Font.DemiBold
      }
      GridLayout {
        Layout.fillWidth: true
        columns: gallery.panel.cardColumns
        columnSpacing: 0
        rowSpacing: 0
        Repeater {
          model: section.keys
          delegate: Item {
            id: choice
            required property string modelData
            readonly property bool wide: gallery.controls.controlWide(modelData)
            Layout.preferredWidth: gallery.panel.cardWidth * (wide ? 2 : 1)
            Layout.columnSpan: wide ? 2 : 1
            Layout.preferredHeight: (wide ? gallery.cc.sectionHeight : gallery.cc.tileHeight) + 8
            scale: addMouse.pressed ? 0.98 : 1
            Behavior on scale { MotionAnimation { theme: gallery.cc.host.theme; pace: addMouse.pressed ? "press" : "standard" } }
            Loader {
              anchors.fill: parent
              anchors.margins: 4
              enabled: false
              property var center: gallery.cc
              property string controlKey: choice.modelData
              property bool galleryPreview: true
              sourceComponent: gallery.cc.controlComponent(choice.modelData)
            }
            MouseArea {
              id: addMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: gallery.layout ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
              preventStealing: true
              property real pressX: 0
              property real pressY: 0
              onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
              onPositionChanged: function(mouse) {
                if (!pressed || !gallery.layout) return
                if (gallery.layout.draggedKey === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
                if (gallery.layout.draggedKey === "")
                  gallery.layout.beginDrag(choice.modelData, true, choice.width - 8, choice.height - 8)
                gallery.layout.moveDrag(addMouse, mouse.x, mouse.y)
              }
              onReleased: function(mouse) {
                if (gallery.layout && gallery.layout.dragFromGallery && gallery.layout.draggedKey === choice.modelData) {
                  gallery.layout.moveDrag(addMouse, mouse.x, mouse.y)
                  gallery.layout.finishDrag()
                }
              }
              onCanceled: if (gallery.layout) gallery.layout.endDrag()
            }
            // The card's +, on its corner (inside the Loader's margins).
            Item {
              anchors.fill: parent
              anchors.margins: 4
              CcEditBadge {
                center: gallery.cc
                adding: true
                shown: !gallery.layout || gallery.layout.draggedKey !== choice.modelData
                cornerRadius: gallery.cc.cardRadius
                tip: "Add " + gallery.controls.controlTitle(choice.modelData)
                onClicked: gallery.controls.setShown(choice.modelData, true)
              }
            }
            Tooltip { theme: gallery.cc.host.theme;
              text: (gallery.layout ? "Drag to Add " : "Add ") + gallery.controls.controlTitle(choice.modelData)
            }
          }
        }
      }
    }
  }
  Text {
    visible: !gallery.hasResults
    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.bottomMargin: 8
    horizontalAlignment: Text.AlignHCenter
    text: "All controls have been added"
    color: gallery.cc.textMuted
    font.family: gallery.cc.host.theme.textFontFamily
    font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.size.body)
    font.pixelSize: gallery.cc.host.theme.size.body
  }
}
