import QtQuick
import "../../../components"

// Settings' pop-up menu, opened by a SettingsPopUp (`button`) with its
// options; picking one hands it to the button's picked().
Popover {
  id: menu
  required property var view
  property Item button: null
  property var options: []
  property var value
  theme: view.host.theme
  open: !!button
  transformOrigin: Item.Center
  z: 50

  FontMetrics { id: menuFont; font.family: menu.view.host.theme.textFontFamily; font.letterSpacing: menu.view.host.theme.tracking(menu.view.host.theme.textFontFamily, menu.view.detailFontSize); font.pixelSize: menu.view.detailFontSize }
  function openFor(target) {
    var widest = 0
    for (var i = 0; i < target.options.length; i++) widest = Math.max(widest, menuFont.advanceWidth(target.options[i].label))
    options = target.options
    value = target.value
    width = Math.max(target.width, Math.ceil(widest) + 52)
    height = target.options.length * 28 + 10
    var p = target.mapToItem(view, 0, 0)
    x = Math.max(4, p.x + target.width - width)
    // As macOS's pop-up menus: the current choice opens over the button.
    var chosen = 0
    for (var j = 0; j < target.options.length; j++) if (target.options[j].value === target.value) chosen = j
    var top = p.y + (target.height - 28) / 2 - 5 - chosen * 28
    y = Math.max(4, Math.min(view.height - height - 4, top))
    button = target
  }

  Column {
    id: menuColumn
    x: 5
    y: 5
    width: parent.width - 10
    Repeater {
      model: menu.options
      delegate: Rectangle {
        id: menuItem
        required property var modelData
        readonly property bool chosen: menu.value === modelData.value
        width: menuColumn.width
        height: 28
        radius: menu.view.host.theme.radii.small
        color: itemMouse.containsMouse ? menu.view.accent : "transparent"
        Text {
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          visible: menuItem.chosen
          text: "󰄬"
          color: itemMouse.containsMouse ? menu.view.accentInk : menu.view.text
          font.family: menu.view.host.theme.fontFamily
          font.pixelSize: menu.view.host.theme.px(12)
        }
        Text {
          x: 26
          anchors.verticalCenter: parent.verticalCenter
          text: menuItem.modelData.label
          color: itemMouse.containsMouse ? menu.view.accentInk : menu.view.text
          font.family: menu.view.host.theme.textFontFamily
          font.letterSpacing: menu.view.host.theme.tracking(menu.view.host.theme.textFontFamily, menu.view.detailFontSize)
          font.pixelSize: menu.view.detailFontSize
        }
        MouseArea {
          id: itemMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var target = menu.button
            menu.button = null
            if (target) target.picked(menuItem.modelData.value)
          }
        }
      }
    }
  }
}
