import QtQuick
import Quickshell.Io
import "../../../components"

// Settings' font picker: the custom font row (`button`, a
// SettingsFontPicker) opens a searchable list of every installed family;
// typing a family name from memory is guesswork.
Popover {
  id: panel
  required property var view
  property Item button: null
  property var fonts: []
  property string query: ""
  property int cursor: 0
  readonly property var filteredFonts: {
    var q = query.trim().toLowerCase()
    if (q === "") return fonts
    return fonts.filter(function(f) { return f.toLowerCase().indexOf(q) !== -1 })
  }
  theme: view.host.theme
  open: !!button
  transformOrigin: Item.Top
  z: 51
  // Rows grow with the text size, from 26 at the default.
  readonly property int rowHeight: Math.max(26, view.detailFontSize + 11)
  width: 264
  height: fontSearch.height + 10 + Math.max(1, Math.min(9, filteredFonts.length)) * rowHeight + 10

  Process {
    command: ["bash", "-c", "fc-list : -f '%{family[0]}\\n' | grep -v -iE 'emoji|signwriting' | sort -u"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: panel.fonts = String(text || "").split("\n").filter(function(f) { return f.trim() !== "" })
    }
  }

  function openFor(target) {
    query = ""
    cursor = 0
    button = target
    var p = target.mapToItem(view, 0, 0)
    x = Math.max(4, Math.min(view.width - width - 4, p.x + target.width - width))
    var below = p.y + target.height + 4
    y = below + height <= view.height - 4 ? below : Math.max(4, p.y - height - 4)
    Qt.callLater(function() { fontInput.forceActiveFocus() })
  }
  function pick(font) {
    if (!font) return
    view.settings.customFont = font
    view.settings.textFontMode = "custom"
    button = null
  }

  Rectangle {
    id: fontSearch
    x: 5
    y: 5
    width: parent.width - 10
    height: Math.max(28, panel.view.detailFontSize + 13)
    radius: panel.view.host.theme.radii.small
    color: panel.view.host.theme.fill("subtle")
    border.width: fontInput.activeFocus ? 2 : 0
    border.color: panel.view.host.theme.accentFill("ring")
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: "󰍉"
      color: panel.view.textMuted
      font.family: panel.view.host.theme.fontFamily
      font.pixelSize: panel.view.host.theme.px(13)
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 28
      anchors.verticalCenter: parent.verticalCenter
      visible: fontInput.text === ""
      text: "Search fonts"
      color: panel.view.textMuted
      font.family: panel.view.host.theme.textFontFamily
      font.letterSpacing: panel.view.host.theme.tracking(panel.view.host.theme.textFontFamily, panel.view.detailFontSize)
      font.pixelSize: panel.view.detailFontSize
    }
    TextInput {
      id: fontInput
      anchors.left: parent.left
      anchors.leftMargin: 28
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      color: panel.view.text
      selectionColor: panel.view.accent
      selectedTextColor: panel.view.accentInk
      font.family: panel.view.host.theme.textFontFamily
      font.letterSpacing: panel.view.host.theme.tracking(panel.view.host.theme.textFontFamily, panel.view.detailFontSize)
      font.pixelSize: panel.view.detailFontSize
      onTextChanged: { panel.query = text; panel.cursor = 0 }
      Keys.onDownPressed: function(event) { panel.cursor = Math.min(panel.filteredFonts.length - 1, panel.cursor + 1); event.accepted = true }
      Keys.onUpPressed: function(event) { panel.cursor = Math.max(0, panel.cursor - 1); event.accepted = true }
      Keys.onEscapePressed: function(event) { panel.button = null; event.accepted = true }
      Keys.onReturnPressed: function(event) { panel.pick(panel.filteredFonts[panel.cursor]); event.accepted = true }
      Keys.onEnterPressed: function(event) { panel.pick(panel.filteredFonts[panel.cursor]); event.accepted = true }
    }
  }

  ListView {
    id: fontRows
    OverlayScrollbar { flickable: fontRows; parent: fontRows; theme: panel.view.host.theme }
    x: 5
    y: fontSearch.y + fontSearch.height + 5
    width: parent.width - 10
    height: parent.height - y - 5
    clip: true
    model: panel.filteredFonts
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    onCountChanged: if (count > 0) positionViewAtIndex(Math.min(panel.cursor, count - 1), ListView.Contain)
    MouseArea {
      anchors.fill: parent
      onWheel: function(wheel) { fontRows.flick(0, wheel.angleDelta.y * 2) }
    }
    delegate: Rectangle {
      id: fontRow
      required property string modelData
      required property int index
      readonly property bool chosen: modelData === panel.view.settings.customFont
      readonly property bool current: index === panel.cursor
      width: fontRows.width
      height: panel.rowHeight
      radius: panel.view.host.theme.radii.small
      color: fontMouse.containsMouse || fontRow.current ? panel.view.accent : "transparent"
      Text {
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: fontRow.chosen
        text: "󰄬"
        color: fontMouse.containsMouse || fontRow.current ? panel.view.accentInk : panel.view.text
        font.family: panel.view.host.theme.fontFamily
        font.pixelSize: panel.view.host.theme.px(12)
      }
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 26
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: fontRow.modelData
        elide: Text.ElideRight
        color: fontMouse.containsMouse || fontRow.current ? panel.view.accentInk : panel.view.text
        font.family: panel.view.host.theme.textFontFamily
        font.letterSpacing: panel.view.host.theme.tracking(panel.view.host.theme.textFontFamily, panel.view.detailFontSize)
        font.pixelSize: panel.view.detailFontSize
      }
      MouseArea {
        id: fontMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: panel.cursor = fontRow.index
        onClicked: panel.pick(fontRow.modelData)
      }
    }
    Text {
      anchors.centerIn: parent
      visible: panel.filteredFonts.length === 0
      text: "No fonts match"
      color: panel.view.textMuted
      font.family: panel.view.host.theme.textFontFamily
      font.letterSpacing: panel.view.host.theme.tracking(panel.view.host.theme.textFontFamily, panel.view.host.theme.px(12))
      font.pixelSize: panel.view.host.theme.px(12)
    }
  }
}
