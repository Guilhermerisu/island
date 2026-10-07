import QtQuick
import QtQuick.Layouts
import "../../../components"

// A checkable activity preview. Its checked state belongs to IslandSettings.
FocusScope {
  id: card
  required property var view
  required property string kind
  required property string title
  required property string description
  property bool checked: false
  property bool pointerFocus: false
  signal toggled(bool checked)

  implicitWidth: 220
  implicitHeight: content.implicitHeight
  activeFocusOnTab: true
  Accessible.role: Accessible.CheckBox
  Accessible.name: title
  Accessible.description: description
  Accessible.checkable: true
  Accessible.checked: checked
  Accessible.onPressAction: card.toggled(!card.checked)
  onActiveFocusChanged: {
    if (activeFocus) view.revealSettingsItem(card)
    else pointerFocus = false
  }
  Keys.onSpacePressed: function(event) {
    pointerFocus = false
    if (!event.isAutoRepeat) card.toggled(!card.checked)
  }
  Keys.onReturnPressed: function(event) {
    pointerFocus = false
    if (!event.isAutoRepeat) card.toggled(!card.checked)
  }
  Keys.onEnterPressed: function(event) {
    pointerFocus = false
    if (!event.isAutoRepeat) card.toggled(!card.checked)
  }

  ColumnLayout {
    id: content
    width: parent.width
    spacing: 6
    Rectangle {
      id: backdrop
      Layout.fillWidth: true
      Layout.preferredHeight: 104
      radius: 16
      color: mouse.containsMouse ? Qt.tint(card.view.card, card.view.host.theme.withAlpha(card.view.text, 0.04)) : card.view.card
      Behavior on color { MotionColorAnimation { theme: card.view.host.theme } }
      ActivityPreview {
        anchors.centerIn: parent
        width: parent.width - 26
        height: 64
        view: card.view
        kind: card.kind
      }
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: backdrop.radius + 3
        color: "transparent"
        border.width: 2
        border.color: card.view.host.theme.withAlpha(card.view.accent, 0.8)
        visible: card.activeFocus && !card.pointerFocus
      }
      Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 9
        width: 16; height: 16; radius: 8
        visible: card.checked
        color: card.view.accent
        Text {
          anchors.centerIn: parent
          text: "󰄬"
          color: card.view.accentInk
          font.family: card.view.host.theme.fontFamily
          font.pixelSize: 11
        }
      }
    }
    Text {
      Layout.fillWidth: true
      Layout.topMargin: 6
      text: card.title
      horizontalAlignment: Text.AlignHCenter
      color: card.view.text
      font.family: card.view.host.theme.textFontFamily
      font.pixelSize: card.view.detailFontSize
      font.weight: Font.Normal
    }
    Text {
      Layout.fillWidth: true
      text: card.description
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.NoWrap
      elide: Text.ElideRight
      color: card.view.textMuted
      font.family: card.view.host.theme.textFontFamily
      font.pixelSize: card.view.detailCaptionFontSize
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: card.pointerFocus = true
    onClicked: {
      card.forceActiveFocus(Qt.MouseFocusReason)
      card.toggled(!card.checked)
    }
  }
}
