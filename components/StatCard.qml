pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// A widget card in the style of iOS: a coloured icon and title
// with the reading's meaning in a tinted capsule, then a usage ring beside
// a short list of figures.
//   rows  [{ label, value, color }] (color optional, for a status word)
Card {
  id: card
  property string icon: ""
  property color iconColor: "#0a84ff"
  property string title: ""
  property real value: 0
  property color ringColor: "#0a84ff"
  property var rows: []
  property string status: ""
  property color statusColor: "#30d158"
  // Off when the title sits outside the card (see the System Stats pane).
  property bool header: true
  property int padding: 16
  implicitHeight: body.implicitHeight + 2 * padding

  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: card.padding
    spacing: 14

    RowLayout {
      visible: card.header
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: card.icon
        color: card.iconColor
        font.family: card.view.host.theme.fontFamily
        font.pixelSize: card.view.host.theme.px(16)
      }
      Text {
        Layout.fillWidth: true
        text: card.title
        elide: Text.ElideRight
        color: card.view.text
        font.family: card.view.host.theme.textFontFamily
        font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.host.theme.px(15))
        font.features: { "tnum": 1 }
        font.pixelSize: card.view.host.theme.px(15)
        font.weight: Font.DemiBold
      }
      Rectangle {
        visible: card.status !== ""
        Layout.preferredHeight: 20
        Layout.preferredWidth: statusText.implicitWidth + 16
        radius: 10
        color: card.view.host.theme.withAlpha(card.statusColor, 0.16)
        Text {
          id: statusText
          anchors.centerIn: parent
          text: card.status
          color: card.statusColor
          font.family: card.view.host.theme.textFontFamily
          font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.view.host.theme.px(12))
          font.features: { "tnum": 1 }
          font.pixelSize: card.view.host.theme.px(12)
          font.weight: Font.Medium
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 14
      Ring {
        view: card.view
        value: card.value
        color: card.ringColor
        thickness: 9
        Layout.preferredWidth: 78
        Layout.preferredHeight: 78
      }
      // Figures as an inset list: label left, value right, hairlines between;
      // on a flat card, as System Settings' rows: the label in the text
      // colour and the value secondary.
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
            Layout.preferredHeight: 26
            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: figure.modelData.label
              color: card.flat ? card.view.text : card.view.textMuted
              font.family: card.view.host.theme.textFontFamily
              font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.flat ? card.view.detailFontSize : card.view.host.theme.px(13))
              font.features: { "tnum": 1 }
              font.pixelSize: card.flat ? card.view.detailFontSize : card.view.host.theme.px(13)
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: figure.modelData.value
              color: figure.modelData.color || (card.flat ? card.view.textMuted : card.view.text)
              font.family: card.view.host.theme.textFontFamily
              font.letterSpacing: card.view.host.theme.tracking(card.view.host.theme.textFontFamily, card.flat ? card.view.detailFontSize : card.view.host.theme.px(13))
              font.pixelSize: card.flat ? card.view.detailFontSize : card.view.host.theme.px(13)
              font.weight: card.flat ? Font.Normal : Font.DemiBold
              font.features: { "tnum": 1 }
            }
            Rectangle {
              visible: figure.index < card.rows.length - 1
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: card.view.divider
            }
          }
        }
      }
    }
  }
}
