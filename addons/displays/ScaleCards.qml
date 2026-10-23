pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../components"

// macOS's row of scale choices, from Larger Text to More Space: each a
// tiny desktop (the wallpaper, a menu bar, a window of text with its
// three buttons) drawn at that size, "Default" under Hyprland's own pick and its logical size on hover.
// The current one is ringed.
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
  implicitHeight: row.implicitHeight + 28

  RowLayout {
    id: row
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 8

    Repeater {
      model: cards.choices
      delegate: Item {
        id: card
        required property var modelData
        required property int index
        readonly property bool current: !!cards.entry && Math.abs(cards.entry.scale - modelData.scale) < 1e-4
        // The ends name the direction, as macOS's; "Default" goes under its
        // card in between, or into an end card's tooltip.
        readonly property string caption: index === 0 && cards.choices.length > 1 ? "Larger Text"
          : index === cards.choices.length - 1 && cards.choices.length > 1 ? "More Space"
          : modelData.isDefault ? "Default" : ""
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: column.implicitHeight

        Column {
          id: column
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: 5

          // The screen, ringed while it's the current scale, lifted on hover.
          Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(84, card.width)
            // Taller for a turned monitor, so its portrait cards aren't tiny.
            height: cards.turned ? 92 : 56
            Item {
              anchors.fill: parent
              scale: press.pressed ? 0.96 : press.containsMouse && !card.current && cards.view.settings.hoverLift ? 1.05 : 1
              Behavior on scale { MotionAnimation { theme: cards.view.host.theme; pace: press.pressed ? "press" : "standard" } }
              DisplayScreen {
                id: desk
                readonly property real ratio: cards.turned ? card.modelData.height / card.modelData.width : card.modelData.width / card.modelData.height
                readonly property real zoom: cards.narrowest / card.modelData.width
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * ratio) - 8
                height: width / ratio
                view: cards.view
                radius: 5
                bezel: 2
                sourceWidth: 200
                // A menu bar, and a window of text, larger as the logical
                // width shrinks, with its three buttons.
                Rectangle {
                  width: parent.width
                  height: Math.max(2, 4 * desk.zoom)
                  color: Qt.rgba(1, 1, 1, 0.5)
                }
                Rectangle {
                  id: window
                  anchors.centerIn: parent
                  anchors.verticalCenterOffset: 2
                  width: parent.width * Math.max(0.3, 0.56 * desk.zoom)
                  height: parent.height * Math.max(0.26, 0.5 * desk.zoom)
                  radius: 2.5
                  color: cards.view.card
                  border.width: 0.5
                  border.color: Qt.rgba(1, 1, 1, 0.14)
                  Row {
                    id: lights
                    visible: window.width >= 18 && window.height >= 12
                    x: 3; y: 3
                    spacing: Math.max(1, 1.6 * desk.zoom)
                    Repeater {
                      model: ["#ff5f57", "#febc2e", "#28c840"]
                      delegate: Rectangle {
                        required property string modelData
                        width: Math.max(2, 3.2 * desk.zoom)
                        height: width
                        radius: width / 2
                        color: modelData
                      }
                    }
                  }
                  Text {
                    anchors.centerIn: parent
                    // Below the buttons, so they never touch.
                    anchors.verticalCenterOffset: lights.visible ? lights.height / 2 + 1.5 : 0
                    text: "Aa"
                    color: cards.view.text
                    font.family: cards.view.host.theme.textFontFamily
                    font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, Math.max(6, Math.round(Math.min(13 * desk.zoom, window.height * 0.42))))
                    font.pixelSize: Math.max(6, Math.round(Math.min(13 * desk.zoom, window.height * 0.42)))
                    font.weight: Font.DemiBold
                  }
                }
              }
              Rectangle {
                anchors.centerIn: desk
                width: desk.width + 8
                height: desk.height + 8
                radius: 8
                color: "transparent"
                border.width: 2.5
                border.color: cards.view.accent
                opacity: card.current ? 1 : 0
                scale: card.current ? 1 : 0.96
                Behavior on opacity { MotionAnimation { theme: cards.view.host.theme } }
                Behavior on scale { MotionAnimation { theme: cards.view.host.theme } }
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
            Tooltip {
              theme: cards.view.host.theme
              text: "Looks like " + (cards.turned ? card.modelData.height + " × " + card.modelData.width : card.modelData.width + " × " + card.modelData.height)
                + (card.modelData.isDefault ? " (Default)" : "")
            }
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            // Held open when empty, so the cards stay level.
            text: card.caption || " "
            color: card.current ? cards.view.text : cards.view.textMuted
            font.family: cards.view.host.theme.textFontFamily
            font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailCaptionFontSize)
            font.pixelSize: cards.view.detailCaptionFontSize
          }
        }
      }
    }
  }
}
