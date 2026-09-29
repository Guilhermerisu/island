import QtQuick
import QtQuick.Layouts
import "../../components"

// A gallery of the same cards used by Control Center. Preview inputs are
// disabled: dragging a card adds it without changing the represented setting.
ColumnLayout {
  id: gallery
  required property var controlCenter
  required property Component quickControl
  required property Component soundControl
  required property Component microphoneControl
  required property Component displayControl
  readonly property var cc: controlCenter
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
      return !gallery.cc.host.controlCenterIsShown(key)
        && (!gallery.cc.isMicrophoneControl(key) || gallery.cc.controlPresent(key))
    })
  }
  function resetScroll() { galleryScroll.contentY = 0 }

  spacing: 12
  Text {
    Layout.fillWidth: true
    text: gallery.cc.removeDropActive
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
                readonly property bool wide: gallery.cc.controlWide(modelData)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.columnSpan: wide ? 2 : 1
                Layout.preferredHeight: wide ? 108 : 82
                scale: addMouse.pressed ? 0.98 : 1
                Behavior on scale { NumberAnimation { duration: 120 * gallery.cc.host.motionScale; easing.type: Easing.OutCubic } }
                Loader {
                  anchors.fill: parent
                  anchors.margins: 4
                  enabled: false
                  property string controlKey: choice.modelData
                  property bool galleryPreview: true
                  sourceComponent: choice.modelData === "sound" ? gallery.soundControl
                    : choice.modelData === "microphone" ? gallery.microphoneControl
                    : choice.modelData === "display" ? gallery.displayControl : gallery.quickControl
                }
                Rectangle {
                  anchors.fill: parent
                  anchors.margins: 3
                  radius: 17
                  color: "transparent"
                  border.width: 1
                  border.color: addMouse.containsMouse ? gallery.cc.accent : "transparent"
                  Behavior on border.color { ColorAnimation { duration: gallery.cc.animDuration } }
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
                    if (gallery.cc.draggedKey === "" && Math.pow(mouse.x - pressX, 2) + Math.pow(mouse.y - pressY, 2) < 36) return
                    if (gallery.cc.draggedKey === "")
                      gallery.cc.beginDrag(choice.modelData, true, choice.width - 8, choice.height - 8)
                    gallery.cc.moveDrag(addMouse, mouse.x, mouse.y)
                  }
                  onReleased: function(mouse) {
                    if (gallery.cc.dragFromGallery && gallery.cc.draggedKey === choice.modelData) {
                      gallery.cc.moveDrag(addMouse, mouse.x, mouse.y)
                      gallery.cc.finishDrag()
                    }
                  }
                  onCanceled: gallery.cc.endDrag()
                }
                Tooltip {
                  text: "Drag to Add " + gallery.cc.controlTitle(choice.modelData)
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
