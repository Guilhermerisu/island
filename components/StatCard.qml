pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// A System Stats card: its title with the reading's meaning in a tinted
// capsule (a dot and a word), then a usage ring beside a short list of
// figures.
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
  property int padding: 14
  flat: true
  implicitHeight: body.implicitHeight + 2 * padding

  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: card.padding
    spacing: 12

    RowLayout {
      Layout.fillWidth: true
      Layout.minimumHeight: 22
      spacing: 8
      Text {
        Layout.fillWidth: true
        text: card.title
        elide: Text.ElideRight
        color: card.view.text
        font.family: card.view.host.theme.textFontFamily
        font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.detailFontSize)
        font.pixelSize: card.view.detailFontSize
        font.weight: Font.DemiBold
      }
      Rectangle {
        visible: card.status !== ""
        Layout.preferredHeight: 20
        Layout.preferredWidth: statusRow.implicitWidth + 16
        radius: 10
        color: card.view.host.theme.withAlpha(card.statusColor, 0.16)
        Row {
          id: statusRow
          anchors.centerIn: parent
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
            font.family: card.view.host.theme.textFontFamily
            font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.detailCaptionFontSize)
            font.pixelSize: card.view.detailCaptionFontSize
            font.weight: Font.DemiBold
          }
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
        thickness: 8
        text: card.ringText
        caption: card.caption
        Layout.preferredWidth: 78
        Layout.preferredHeight: 78
      }
      // The figures: label left, value right, no rules between.
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
            Layout.preferredHeight: 24
            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: figure.modelData.label
              color: card.view.host.theme.withAlpha(card.view.text, 0.85)
              font.family: card.view.host.theme.textFontFamily
              font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.detailFontSize)
              font.features: { "tnum": 1 }
              font.pixelSize: card.view.detailFontSize
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: figure.modelData.value
              color: figure.modelData.color || card.view.text
              font.family: card.view.host.theme.textFontFamily
              font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.detailFontSize)
              font.pixelSize: card.view.detailFontSize
              font.features: { "tnum": 1 }
            }
          }
        }
      }
    }
  }
}
