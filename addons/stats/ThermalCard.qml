pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../components"

// How hot the machine runs, as macOS puts it: the hottest part's temperature
// on a ring like the other boxes', in its level's colour, beside each part's
// temperature; and (as `levelName`, for the title
// above it; see Section) one word for whichever part runs hottest for its kind.
// Chips are Good under 70 °C, Fair under 80, High under 90; SSDs, which
// slow down sooner, 20 °C lower.
Card {
  id: card
  property var temps: []          // [{ label, value, ssd }]
  readonly property var levels: [
    { label: "Good", color: card.view.host.theme.system.green },
    { label: "Fair", color: card.view.host.theme.system.yellow },
    { label: "High", color: card.view.host.theme.system.orange },
    { label: "Max", color: card.view.host.theme.system.red }
  ]
  function levelOf(t) {
    var good = t.ssd ? 50 : 70
    return t.value < good ? 0 : t.value < good + 10 ? 1 : t.value < good + 20 ? 2 : 3
  }
  readonly property int level: temps.reduce(function(top, t) { return Math.max(top, card.levelOf(t)) }, 0)
  readonly property string levelName: temps.length ? levels[level].label : ""
  // The part furthest into its scale: the highest level, then the hottest.
  readonly property var hottest: temps.reduce(function(top, t) {
    if (!top) return t
    var a = card.levelOf(t), b = card.levelOf(top)
    return a > b || (a === b && t.value > top.value) ? t : top
  }, null)
  readonly property color levelColor: levels[level].color
  implicitHeight: body.implicitHeight + 28

  RowLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: 14
    spacing: 14

    // The hottest part as a ring like the other boxes': its temperature
    // toward its Max (100 °C for chips, 80 for SSDs), in its level's colour.
    Ring {
      view: card.view
      Layout.preferredWidth: 78
      Layout.preferredHeight: 78
      thickness: 9
      value: card.hottest ? card.hottest.value / ((card.hottest.ssd ? 50 : 70) + 30) * 100 : 0
      color: card.levelColor
      text: card.hottest ? Math.round(card.hottest.value) + "°" : "—"
      caption: card.hottest ? card.hottest.label : ""
    }

    // A row per part, as the other boxes' figures: its name, a dot in its
    // level's colour, and its temperature.
    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 0
      Repeater {
        model: card.temps.length
        delegate: Item {
          id: reading
          required property int index
          readonly property var modelData: card.temps[index] || ({ label: "", value: 0 })
          Layout.fillWidth: true
          Layout.preferredHeight: 26
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: reading.modelData.label
            color: card.view.text
            font.family: card.view.host.theme.textFontFamily
            font.features: { "tnum": 1 }
            font.pixelSize: card.view.detailFontSize
          }
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 6
              height: 6
              radius: 3
              color: card.levels[card.levelOf(reading.modelData)].color
            }
            Text {
              text: Math.round(reading.modelData.value) + " °C"
              color: card.view.textMuted
              font.family: card.view.host.theme.textFontFamily
              font.pixelSize: card.view.detailFontSize
              font.features: { "tnum": 1 }
            }
          }
          Rectangle {
            visible: reading.index < card.temps.length - 1
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
