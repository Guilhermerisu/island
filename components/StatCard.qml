pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// A System Stats card: its title with the reading's meaning as a dot and a
// word in its colour, then a usage ring beside a short list of figures
// (grey labels, the values in the label colour).
//   rows  [{ label, value, color }] (color optional, for a status word)
Card {
  id: card
  property string title: ""
  property real value: 0
  property color ringColor: "#0a84ff"
  // The ring's middle: the percentage by default, and a word under it.
  property string ringText: Math.round(Math.max(0, Math.min(100, value))) + "%"
  property string caption: ""
  property var rows: []
  property string status: ""
  property color statusColor: "#30d158"
  readonly property var theme: card.view.host.theme
  flat: true
  implicitHeight: 12 + body.implicitHeight + 14

  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 12
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        Layout.fillWidth: true
        text: card.title
        elide: Text.ElideRight
        color: card.view.text
        font.family: card.theme.textFontFamily
        font.letterSpacing: card.theme.tracking(card.theme.textFontFamily, card.theme.px(13))
        font.pixelSize: card.theme.px(13)
        font.weight: Font.DemiBold
      }
      Row {
        visible: card.status !== ""
        spacing: 5
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 6
          height: 6
          radius: 3
          color: card.statusColor
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: card.status
          color: card.statusColor
          font.family: card.theme.textFontFamily
          font.letterSpacing: card.theme.tracking(card.theme.textFontFamily, card.theme.px(11))
          font.pixelSize: card.theme.px(11)
          font.weight: Font.Medium
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 16
      Ring {
        view: card.view
        value: card.value
        color: card.ringColor
        thickness: 6
        text: card.ringText
        caption: card.caption
        textSize: card.theme.px(15)
        captionSize: card.theme.px(10)
        Layout.preferredWidth: 68
        Layout.preferredHeight: 68
      }
      // The figures: label left, value right, no rules between. Three rows
      // fit beside the ring, so the cards come out the same height.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0
        // By count, not by array: each reading's new array would otherwise
        // rebuild the rows each reading.
        Repeater {
          model: card.rows.length
          delegate: Item {
            id: figure
            required property int index
            readonly property var modelData: card.rows[index] || ({})
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: figure.modelData.label
              color: card.view.textMuted
              font.family: card.theme.textFontFamily
              font.letterSpacing: card.theme.tracking(card.theme.textFontFamily, card.theme.px(12))
              font.pixelSize: card.theme.px(12)
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: figure.modelData.value
              color: figure.modelData.color || card.view.text
              font.family: card.theme.textFontFamily
              font.letterSpacing: card.theme.tracking(card.theme.textFontFamily, card.theme.px(12))
              font.pixelSize: card.theme.px(12)
              font.features: { "tnum": 1 }
            }
          }
        }
      }
    }
  }
}
