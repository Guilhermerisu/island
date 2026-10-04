pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// How hot the machine runs, as macOS puts it: one word for whichever part
// runs hottest for its kind, the temperatures under it, and the scale.
// Chips are Good under 70 °C, Fair under 80, High under 90; SSDs, which
// slow down sooner, 20 °C lower.
Card {
  id: card
  property var temps: []          // [{ label, value, ssd }]
  readonly property var levels: [
    { label: "Good", color: "#30d158" },
    { label: "Fair", color: "#248a3d" },
    { label: "High", color: "#ffd60a" },
    { label: "Max", color: "#ff453a" }
  ]
  function levelOf(t) {
    var good = t.ssd ? 50 : 70
    return t.value < good ? 0 : t.value < good + 10 ? 1 : t.value < good + 20 ? 2 : 3
  }
  readonly property int level: temps.reduce(function(top, t) { return Math.max(top, card.levelOf(t)) }, 0)
  implicitHeight: body.implicitHeight + 32

  ColumnLayout {
    id: body
    anchors.fill: parent
    anchors.margins: 16
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: "󰔏"
        color: card.levels[card.level].color
        font.family: card.view.host.theme.fontFamily
        font.pixelSize: 16
      }
      Text {
        Layout.fillWidth: true
        text: "Thermal"
        color: card.view.text
        font.family: "Adwaita Sans"
        font.pixelSize: card.view.detailFontSize + 1
        font.weight: Font.DemiBold
      }
    }
    Item { Layout.fillHeight: true }
    Text {
      text: card.temps.length ? card.levels[card.level].label : "—"
      color: card.levels[card.level].color
      font.family: "Adwaita Sans"
      font.pixelSize: 24
      font.weight: Font.DemiBold
    }
    Text {
      Layout.fillWidth: true
      text: card.temps.map(function(t) { return t.label + " " + Math.round(t.value) + "°" }).join("  ·  ")
      elide: Text.ElideRight
      color: card.view.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 13
      font.features: { "tnum": 1 }
    }
    Item { Layout.fillHeight: true }
    Row {
      spacing: 12
      Repeater {
        model: card.levels
        delegate: Row {
          id: key
          required property var modelData
          required property int index
          readonly property bool current: index === card.level && card.temps.length > 0
          spacing: 5
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: key.modelData.color
          }
          Text {
            text: key.modelData.label
            color: key.current ? card.view.text : card.view.textMuted
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            font.weight: key.current ? Font.DemiBold : Font.Normal
          }
        }
      }
    }
  }
}
