import QtQuick
import QtQuick.Layouts
import "../../components"

// A gallery of the same cards used by Control Center. Preview inputs are
// disabled: dragging a card adds it without changing the represented setting.
ColumnLayout {
  id: gallery
  required property var controlCenter
  required property var controlLayout
  readonly property var cc: controlCenter
  readonly property var controls: controlCenter.controls
  readonly property var layout: controlLayout
  readonly property var sections: [
    { title: "Connectivity", keys: ["wifi", "bluetooth"] },
    { title: "Focus & System", keys: ["focus", "microphoneMute", "night", "game", "power", "keyboard"] },
    { title: "Sound & Display", keys: ["sound", "microphone", "display"] }
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

  spacing: 12
  Text {
    Layout.fillWidth: true
    text: gallery.layout.removeDropActive
      ? "Release to remove this control."
      : "Drag a control into the layout above. Scroll to see more."
    color: gallery.cc.textMuted
    font.family: "Adwaita Sans"
    font.pixelSize: 12
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
  }
  Flickable {
    id: galleryScroll
    Layout.fillWidth: true
    Layout.preferredHeight: 240
    contentWidth: width
    contentHeight: galleryContents.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ColumnLayout {
      id: galleryContents
      width: galleryScroll.width
      spacing: 20
      Repeater {
        model: gallery.sections
        delegate: ColumnLayout {
          id: section
          required property var modelData
          readonly property var keys: gallery.keysFor(modelData)
          visible: keys.length > 0
          Layout.fillWidth: true
          spacing: 12
          Text {
            Layout.leftMargin: 5
            text: section.modelData.title
            color: gallery.cc.text
            font.family: "Adwaita Sans"
            font.pixelSize: 14
            font.weight: Font.DemiBold
          }
          GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            Repeater {
              model: section.keys
              delegate: Item {
                id: choice
                required property string modelData
                readonly property bool wide: gallery.controls.controlWide(modelData)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.columnSpan: wide ? 2 : 1
                Layout.preferredHeight: wide ? 108 : 82
                scale: addMouse.pressed ? 0.98 : 1
                Behavior on scale { MotionAnimation { theme: gallery.cc.host.theme; pace: addMouse.pressed ? "press" : "standard" } }
                Loader {
                  anchors.fill: parent
                  anchors.margins: 4
                  enabled: false
                  property string controlKey: choice.modelData
                  property bool galleryPreview: true
                  sourceComponent: gallery.cc.controlComponent(choice.modelData)
                }
                Rectangle {
                  anchors.fill: parent
                  anchors.margins: 3
                  radius: 17
                  color: "transparent"
                  border.width: 1
                  border.color: addMouse.containsMouse ? gallery.cc.accent : "transparent"
                  Behavior on border.color { MotionColorAnimation { theme: gallery.cc.host.theme } }
                }
                Rectangle {
                  anchors.right: parent.right
                  anchors.top: parent.top
                  width: 24; height: 24; radius: 12
                  color: gallery.cc.accent
                  border.width: 1
                  border.color: gallery.cc.edge
                  Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: gallery.cc.accentInk
                    font.family: "Adwaita Sans"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                  }
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
        font.family: "Adwaita Sans"
        font.pixelSize: 13
      }
    }
  }
}
