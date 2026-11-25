pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../components"

// System Stats in an XSmall or Small control center zone (see "Zone sizes" in
// Addon.qml), in place of the cards: a mounted Settings page has no card of
// its own (AddonZone pads it 0), so this draws one, of exactly the height the
// size allows. A click on either opens the Settings page (the process table
// and Quit are there). XSmall is a line of coloured pills ("CPU 12% RAM 48% 52 °C"),
// Small four gauges side by side. The readings and their colours are the
// cards' (`readings`, StatsCards), the same as the Normal zone shows.
Rectangle {
  id: glance
  required property var view
  required property var readings
  required property string zoneSize
  readonly property var theme: view.host.theme
  readonly property bool xs: zoneSize === "xsmall"
  // XSmall is the zone's fixed line (the page's `zoneRoom`, 58: the card is
  // padded 0); Small is as tall as it holds, under its 91 minimum.
  property real xsHeight: 58
  implicitHeight: xs ? xsHeight : 80
  radius: theme.radii.card
  color: view.card
  border.width: 1
  border.color: view.edge

  readonly property bool ready: readings.ready
  readonly property var cpu: readings.cpu
  readonly property real busy: cpu ? cpu.user + cpu.system : 0
  readonly property real mem: readings.memory ? readings.memory.used / readings.memory.total * 100 : 0
  readonly property var gpu: readings.gpus.length ? readings.gpus[0] : null
  // The hottest chip, as the Thermal card's ring.
  readonly property var hot: {
    var all = (cpu && cpu.temp != null ? [cpu.temp] : []).concat(readings.gpus.map(function(g) { return g.temp }))
      .filter(function(t) { return t != null })
    return all.length ? Math.max.apply(null, all) : null
  }
  readonly property color hotColor: hot == null ? readings.orange : hot < 70 ? readings.green : hot < 80 ? readings.yellow : hot < 90 ? readings.orange : readings.red
  // The startup disk (the first volume if it is not listed).
  readonly property var disk: {
    var all = readings.latest ? readings.latest.volumes : []
    return all.filter(function(v) { return v.mount === "/" })[0] || all[0] || null
  }
  readonly property real diskUsed: disk ? disk.used / disk.size * 100 : 0
  readonly property color diskColor: diskUsed > 90 ? readings.red : readings.blue

  function percent(v) { return ready ? readings.round(v) : "—" }
  function degrees(t) { return t == null ? "" : readings.temperature(t) }

  readonly property var pills: [
    { label: "CPU", value: percent(busy), color: readings.blue },
    { label: "RAM", value: percent(mem), color: readings.purple },
    hot != null ? { label: "", value: degrees(hot), color: hotColor }
      : { label: "Disk", value: disk ? percent(diskUsed) : "—", color: diskColor }
  ]
  readonly property var gauges: [
    { label: "CPU", value: percent(busy), frac: busy / 100, color: readings.blue, sub: degrees(cpu ? cpu.temp : null) },
    { label: "RAM", value: percent(mem), frac: mem / 100, color: readings.purple,
      sub: readings.memory ? readings.bytes(readings.memory.used) : "" },
    gpu ? { label: "GPU", value: gpu.usage != null ? percent(gpu.usage) : "—", frac: (gpu.usage || 0) / 100,
            color: readings.teal, sub: degrees(gpu.temp) }
      : { label: "Temp", value: hot != null ? degrees(hot) : "—", frac: (hot || 0) / 100, color: hotColor, sub: "" },
    { label: "Disk", value: disk ? percent(diskUsed) : "—", frac: diskUsed / 100, color: diskColor,
      sub: disk ? readings.bytes(disk.used) : "" }
  ]

  // The process table and Quit are Settings' (not in a zone): a click opens it.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: glance.view.host.openSettings("System Stats")
  }

  RowLayout {
    visible: glance.xs
    anchors.fill: parent
    anchors.margins: 10
    spacing: 6
    Repeater {
      model: glance.pills
      delegate: Rectangle {
        id: pill
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        radius: height / 2
        color: glance.theme.withAlpha(modelData.color, 0.16)
        clip: true
        Row {
          anchors.centerIn: parent
          spacing: 5
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: pill.modelData.color
          }
          Text {
            visible: pill.modelData.label !== ""
            text: pill.modelData.label
            color: glance.view.textMuted
            font.family: glance.theme.textFontFamily
            font.pixelSize: glance.view.detailCaptionFontSize
            font.weight: Font.Medium
          }
          Text {
            text: pill.modelData.value
            color: glance.view.text
            font.family: glance.theme.textFontFamily
            font.features: { "tnum": 1 }
            font.pixelSize: glance.view.detailCaptionFontSize
            font.weight: Font.DemiBold
          }
        }
      }
    }
  }

  RowLayout {
    visible: !glance.xs
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10
    Repeater {
      model: glance.gauges
      delegate: Column {
        id: gauge
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignVCenter
        spacing: 3
        Text {
          width: parent.width
          text: gauge.modelData.label
          elide: Text.ElideRight
          color: glance.view.textMuted
          font.family: glance.theme.textFontFamily
          font.pixelSize: glance.view.detailCaptionFontSize
        }
        Text {
          width: parent.width
          text: gauge.modelData.value
          elide: Text.ElideRight
          color: glance.view.text
          font.family: glance.theme.textFontFamily
          font.features: { "tnum": 1 }
          font.pixelSize: glance.theme.px(15)
          font.weight: Font.DemiBold
        }
        Rectangle {
          width: parent.width
          height: 4
          radius: 2
          color: glance.theme.fill("raised")
          Rectangle {
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0, Math.min(1, gauge.modelData.frac))
            color: gauge.modelData.color
            Behavior on width { MotionAnimation { theme: glance.theme; pace: "standard" } }
          }
        }
        Text {
          width: parent.width
          text: gauge.modelData.sub
          elide: Text.ElideRight
          color: glance.view.textMuted
          font.family: glance.theme.textFontFamily
          font.features: { "tnum": 1 }
          font.pixelSize: glance.view.detailCaptionFontSize
        }
      }
    }
  }
}
