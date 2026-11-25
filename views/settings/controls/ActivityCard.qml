import QtQuick
import QtQuick.Layouts
import "../../../components"

// A checkable activity preview card. Its checked state belongs to
// IslandSettings.
FocusScope {
  id: card
  required property var view
  required property string kind
  required property string title
  required property string description
  property bool checked: false
  property bool pointerFocus: false
  // Found by Settings' search as a SettingsRow is.
  property string keywords: ""
  readonly property string searchText: [title, description, keywords].join(" ")
  readonly property bool searchHit: !!view.matches && view.matches(searchText)
  Component.onCompleted: if (view.registerSearchable) view.registerSearchable(card)
  Component.onDestruction: if (view.unregisterSearchable) view.unregisterSearchable(card)
  signal toggled(bool checked)

  implicitWidth: 220
  implicitHeight: content.implicitHeight
  scale: mouse.pressed ? 0.97 : 1
  Behavior on scale { id: scaleMotion; MotionAnimation { theme: card.view.host.theme; pace: towards(scaleMotion.targetValue, mouse.pressed ? "press" : "standard") } }
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

  // The card: the pill's preview in a darker well, then the name and what
  // it shows beside a switch. A click anywhere on it flips the switch.
  Rectangle {
    id: backdrop
    anchors.fill: parent
    radius: card.view.groupRadius
    color: card.searchHit ? Qt.tint(card.view.card, card.view.host.theme.accentFill("soft"))
      : mouse.containsMouse ? Qt.tint(card.view.card, card.view.host.theme.fill("quiet")) : card.view.card
    Behavior on color { MotionColorAnimation { theme: card.view.host.theme } }
    Rectangle {
      anchors.fill: parent
      anchors.margins: -3
      radius: backdrop.radius + 3
      color: "transparent"
      border.width: 2
      border.color: card.view.host.theme.withAlpha(card.view.accent, 0.8)
      visible: card.activeFocus && !card.pointerFocus
    }
  }
  ColumnLayout {
    id: content
    width: parent.width
    spacing: 0
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: 8
      Layout.rightMargin: 8
      Layout.topMargin: 8
      Layout.preferredHeight: 96
      // Near-concentric with the card, a little rounder than its radius
      // less the 8 around the well.
      radius: card.view.groupRadius - 4
      // Only a slightly darker fill, no edge of its own, so the card
      // doesn't read as a box in a box.
      color: card.view.host.theme.solid("quiet")
      ActivityPreview {
        anchors.centerIn: parent
        width: parent.width - 26
        height: 64
        view: card.view
        kind: card.kind
      }
    }
    RowLayout {
      Layout.fillWidth: true
      // 10 under the preview and 4 in from its edges; 10 over the
      // card's bottom.
      Layout.leftMargin: 12
      Layout.rightMargin: 12
      Layout.topMargin: 10
      Layout.bottomMargin: 10
      spacing: 11
      Column {
        Layout.fillWidth: true
        spacing: 2
        Text {
          width: parent.width
          text: card.title
          elide: Text.ElideRight
          color: card.view.text
          font.family: card.view.host.theme.textFontFamily
          font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.detailFontSize)
          font.pixelSize: card.view.detailFontSize
          font.weight: Font.Medium
        }
        Text {
          width: parent.width
          text: card.description
          elide: Text.ElideRight
          color: card.view.textMuted
          font.family: card.view.host.theme.textFontFamily
          font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.detailCaptionFontSize)
          font.pixelSize: card.view.detailCaptionFontSize
        }
      }
      // Shows the state; the card's own click (over it) does the toggling.
      SettingsSwitch {
        view: card.view
        checked: card.checked
      }
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
