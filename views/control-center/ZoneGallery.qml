import QtQuick
import QtQuick.Layouts
import "../../components"

// The zones that aren't in the control center, in the add panel (see
// AddPanel): click a card's + to add it (an addon's zone switches the addon
// on). `panel` is the AddPanel.
ColumnLayout {
  id: gallery
  required property var panel
  readonly property var center: panel.center
  readonly property var zones: center.zones

  spacing: 8

  Flow {
    visible: gallery.zones.absent.length > 0
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.topMargin: 4
    spacing: 12
    Repeater {
      model: gallery.zones.absent
      delegate: Rectangle {
        id: choice
        required property string modelData
        readonly property var info: gallery.zones.definition(modelData)
        width: label.implicitWidth + 32
        height: 32
        radius: Math.min(gallery.center.cardRadius, height / 2)
        color: addMouse.containsMouse ? gallery.center.tile : gallery.center.card
        border.width: 1
        border.color: gallery.center.edge
        Behavior on color { MotionColorAnimation { theme: gallery.center.host.theme } }
        scale: addMouse.pressed ? 0.97 : 1
        Behavior on scale { MotionAnimation { theme: gallery.center.host.theme; pace: addMouse.pressed ? "press" : "standard" } }
        Text {
          id: label
          anchors.centerIn: parent
          text: choice.info ? choice.info.title : choice.modelData
          color: gallery.center.text
          font.family: gallery.center.host.theme.textFontFamily
          font.letterSpacing: gallery.center.host.theme.tracking(gallery.center.host.theme.textFontFamily, gallery.center.host.theme.px(12))
          font.pixelSize: gallery.center.host.theme.px(12)
          font.weight: Font.Medium
        }
        MouseArea {
          id: addMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gallery.zones.add(choice.modelData)
        }
        CcEditBadge {
          center: gallery.center
          adding: true
          cornerRadius: choice.radius
          tip: "Add " + (choice.info ? choice.info.title : choice.modelData)
          onClicked: gallery.zones.add(choice.modelData)
        }
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
    font.letterSpacing: gallery.center.host.theme.tracking(gallery.center.host.theme.textFontFamily, gallery.center.host.theme.px(13))
    font.pixelSize: gallery.center.host.theme.px(13)
  }
}
