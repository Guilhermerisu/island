import QtQuick
import QtQuick.Layouts
import "../../components"

// A gallery of the same cards used by Control Center, on its own panel.
// Preview inputs are disabled: dragging a card in (or clicking its +) adds
// it without changing the represented setting. A card dragged out of the
// layout onto it is removed.
Rectangle {
  id: gallery
  required property var controlCenter
  required property var controlLayout
  readonly property var cc: controlCenter
  readonly property var controls: controlCenter.controls
  readonly property var layout: controlLayout
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
  function resetScroll() { galleryScroll.contentY = 0 }

  Layout.preferredHeight: panel.implicitHeight + 24
  radius: gallery.cc.cardRadius
  color: gallery.cc.host.theme.solid("quiet")
  border.width: 1
  border.color: gallery.cc.edge

  ColumnLayout {
    id: panel
    anchors.fill: parent
    anchors.margins: 12
    anchors.topMargin: 14
    spacing: 10
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4
      Layout.rightMargin: 4
      Text {
        text: "Add Controls"
        color: gallery.cc.text
        font.family: gallery.cc.host.theme.textFontFamily
        font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.px(13))
        font.pixelSize: gallery.cc.host.theme.px(13)
        font.weight: Font.DemiBold
      }
      Item { Layout.fillWidth: true }
      Text {
        text: gallery.layout.removeDropActive ? "Release to remove" : "Drag in or click +"
        color: gallery.cc.textMuted
        font.family: gallery.cc.host.theme.textFontFamily
        font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.px(11))
        font.pixelSize: gallery.cc.host.theme.px(11)
      }
    }
    Flickable {
      id: galleryScroll
      OverlayScrollbar { flickable: galleryScroll; parent: galleryScroll; theme: gallery.cc.host.theme }
      Layout.fillWidth: true
      Layout.preferredHeight: 260
      contentWidth: width
      contentHeight: galleryContents.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      ColumnLayout {
        id: galleryContents
        width: galleryScroll.width
        spacing: 16
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
              font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.px(12))
              font.pixelSize: gallery.cc.host.theme.px(12)
              font.weight: Font.DemiBold
            }
            GridLayout {
              Layout.fillWidth: true
              columns: 2
              columnSpacing: 0
              rowSpacing: 0
              Repeater {
                model: section.keys
                delegate: Item {
                  id: choice
                  required property string modelData
                  readonly property bool wide: gallery.controls.controlWide(modelData)
                  Layout.fillWidth: true
                  Layout.preferredWidth: 1
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
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: true
                    property real pressX: 0
                    property real pressY: 0
                    onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
                    onPositionChanged: function(mouse) {
                      if (!pressed) return
                      if (gallery.layout.draggedKey === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
                      if (gallery.layout.draggedKey === "")
                        gallery.layout.beginDrag(choice.modelData, true, choice.width - 8, choice.height - 8)
                      gallery.layout.moveDrag(addMouse, mouse.x, mouse.y)
                    }
                    onReleased: function(mouse) {
                      if (gallery.layout.dragFromGallery && gallery.layout.draggedKey === choice.modelData) {
                        gallery.layout.moveDrag(addMouse, mouse.x, mouse.y)
                        gallery.layout.finishDrag()
                      }
                    }
                    onCanceled: gallery.layout.endDrag()
                  }
                  // The card's +, on its corner (inside the Loader's margins).
                  Item {
                    anchors.fill: parent
                    anchors.margins: 4
                    CcEditBadge {
                      center: gallery.cc
                      adding: true
                      shown: gallery.layout.draggedKey !== choice.modelData
                      cornerRadius: gallery.cc.cardRadius
                      tip: "Add " + gallery.controls.controlTitle(choice.modelData)
                      onClicked: gallery.controls.setShown(choice.modelData, true)
                    }
                  }
                  Tooltip { theme: gallery.cc.host.theme;
                    text: "Drag to Add " + gallery.controls.controlTitle(choice.modelData)
                  }
                }
              }
            }
          }
        }
        Text {
          visible: !gallery.hasResults
          Layout.fillWidth: true
          Layout.topMargin: 24
          Layout.bottomMargin: 24
          horizontalAlignment: Text.AlignHCenter
          text: "All controls have been added"
          color: gallery.cc.textMuted
          font.family: gallery.cc.host.theme.textFontFamily
          font.letterSpacing: gallery.cc.host.theme.tracking(gallery.cc.host.theme.textFontFamily, gallery.cc.host.theme.px(13))
          font.pixelSize: gallery.cc.host.theme.px(13)
        }
      }
    }
  }
}
