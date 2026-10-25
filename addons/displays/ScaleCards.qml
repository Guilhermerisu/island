pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../components"

// macOS's row of scale choices, from Larger Text to More Space, under a
// "Scale" title with what the current one looks like: each a tiny desktop
// (the wallpaper, a window of text with its three buttons) drawn at that
// size, its scale under it, and Larger Text and More Space under the ends,
// as macOS's picker. The current one is ringed in the accent.
// `view` is the SettingsView, `displays` the DisplaysAddon, `entry` the
// monitor as drafted.
Item {
  id: cards
  required property var view
  required property var displays
  required property var entry
  readonly property var choices: entry ? displays.scaleChoices(entry, entry.width, entry.height) : []
  readonly property bool turned: !!entry && entry.transform % 2 === 1
  // The smallest logical width on offer, whose text is drawn largest.
  readonly property real narrowest: Math.min.apply(null, choices.map(function(c) { return c.width }).concat([100000]))
  function size(c) { return turned ? c.height + " × " + c.width : c.width + " × " + c.height }
  function scaleName(scale) { return Number(scale.toFixed(2)) + "×" }
  readonly property var current: {
    for (var i = 0; i < choices.length; i++) if (entry && Math.abs(entry.scale - choices[i].scale) < 1e-4) return choices[i]
    return null
  }
  implicitHeight: column.implicitHeight + 28

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 14
    spacing: 12

    // Scale is how big things look; Resolution, below, what the panel runs at.
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        Layout.fillWidth: true
        text: "Scale"
        color: cards.view.text
        font.family: cards.view.host.theme.textFontFamily
        font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailFontSize)
        font.pixelSize: cards.view.detailFontSize
      }
      Text {
        visible: !!cards.current
        text: cards.current ? "Looks like " + cards.size(cards.current) : ""
        color: cards.view.textMuted
        font.family: cards.view.host.theme.textFontFamily
        font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailCaptionFontSize)
        font.pixelSize: cards.view.detailCaptionFontSize
        font.features: { "tnum": 1 }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Repeater {
        model: cards.choices
        delegate: Item {
          id: card
          required property var modelData
          required property int index
          readonly property bool current: !!cards.entry && Math.abs(cards.entry.scale - modelData.scale) < 1e-4
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          implicitHeight: cardColumn.implicitHeight

          Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            // The screen, ringed while it's the current scale.
            Item {
              id: screenSlot
              readonly property real ratio: cards.turned ? card.modelData.height / card.modelData.width : card.modelData.width / card.modelData.height
              width: parent.width
              // Taller for a turned monitor, so its portrait cards aren't tiny.
              height: cards.turned ? width * 1.2 : width / Math.max(1, ratio)
              Item {
                anchors.fill: parent
                scale: press.pressed ? 0.97 : 1
                Behavior on scale { MotionAnimation { theme: cards.view.host.theme; pace: press.pressed ? "press" : "standard" } }
                DisplayScreen {
                  id: desk
                  readonly property real zoom: cards.narrowest / card.modelData.width
                  anchors.centerIn: parent
                  width: Math.min(parent.width, parent.height * screenSlot.ratio)
                  height: width / screenSlot.ratio
                  view: cards.view
                  radius: 8
                  bezel: 1
                  shadow: false
                  sourceWidth: 240
                  // A window of text, larger as the logical width shrinks,
                  // with its three buttons.
                  Rectangle {
                    id: window
                    anchors.centerIn: parent
                    width: parent.width * Math.max(0.24, 0.4 * desk.zoom)
                    height: parent.height * Math.max(0.2, 0.36 * desk.zoom)
                    radius: 3
                    color: cards.view.card
                    border.width: 0.5
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    Text {
                      anchors.centerIn: parent
                      text: "Aa"
                      color: cards.view.text
                      font.family: cards.view.host.theme.textFontFamily
                      font.pixelSize: Math.max(6, Math.round(Math.min(14 * desk.zoom, window.height * 0.5)))
                      font.weight: Font.Bold
                    }
                  }
                }
                Rectangle {
                  anchors.fill: desk
                  anchors.margins: -1
                  radius: desk.radius + 1
                  color: "transparent"
                  border.width: card.current ? 2 : 1
                  border.color: card.current ? cards.view.accent
                    : press.containsMouse ? cards.view.host.theme.fill("stronger") : cards.view.host.theme.fill("raised")
                  Behavior on border.color { MotionColorAnimation { theme: cards.view.host.theme } }
                }
              }
              MouseArea {
                id: press
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !cards.displays.confirming
                onClicked: cards.displays.setScale(cards.entry.name, card.modelData.scale)
              }
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: cards.scaleName(card.modelData.scale)
              color: card.current ? cards.view.text : cards.view.textMuted
              font.family: cards.view.host.theme.textFontFamily
              font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailCaptionFontSize)
              font.pixelSize: cards.view.detailCaptionFontSize
              font.weight: card.current ? Font.DemiBold : Font.Medium
              font.features: { "tnum": 1 }
            }
          }
        }
      }
    }
    // The direction, under the ends.
    RowLayout {
      visible: cards.choices.length > 1
      Layout.fillWidth: true
      Layout.topMargin: -4
      Repeater {
        model: ["Larger Text", "More Space"]
        delegate: Text {
          required property string modelData
          required property int index
          Layout.fillWidth: true
          horizontalAlignment: index === 0 ? Text.AlignLeft : Text.AlignRight
          text: modelData
          color: cards.view.host.theme.withAlpha(cards.view.textMuted, 0.75)
          font.family: cards.view.host.theme.textFontFamily
          font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailCaptionFontSize)
          font.pixelSize: cards.view.detailCaptionFontSize
        }
      }
    }
  }
}
