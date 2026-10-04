pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// A stats card in the style of an iOS widget: a coloured icon and title
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
  implicitHeight: body.implicitHeight + 32

  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 16
    spacing: 14

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: card.icon
        color: card.iconColor
        font.family: card.view.host.theme.fontFamily
        font.pixelSize: 16
      }
      Text {
        Layout.fillWidth: true
        text: card.title
        elide: Text.ElideRight
        color: card.view.text
        font.family: "Adwaita Sans"
        font.pixelSize: card.view.detailFontSize + 1
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
          font.family: "Adwaita Sans"
          font.pixelSize: 12
          font.weight: Font.DemiBold
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
      // Figures as an inset list: label left, value right, hairlines between.
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
              color: card.view.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: 13
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: figure.modelData.value
              color: figure.modelData.color || card.view.text
              font.family: "Adwaita Sans"
              font.pixelSize: 14
              font.weight: Font.DemiBold
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
