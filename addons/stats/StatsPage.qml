pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../views/settings/controls"

// The System Stats pane: cards for the CPU, memory, GPU and storage, then
// the processes. Colours carry Apple's meanings (usage
// blue, pressure green to red); text and surfaces follow the theme.
ColumnLayout {
  id: page
  required property var view
  required property var stats
  property bool shown: false
  spacing: 20

  readonly property var latest: stats.latest
  readonly property var cpu: latest ? latest.cpu : null
  readonly property var memory: latest ? latest.memory : null
  readonly property var gpus: latest ? latest.gpus : []

  readonly property color red: "#ff453a"
  readonly property color blue: "#0a84ff"
  readonly property color green: "#30d158"
  readonly property color yellow: "#ffd60a"
  readonly property color orange: "#ff9f0a"
  readonly property color teal: "#64d2ff"
  readonly property color gray: "#8e8e93"

  // Formatting, shared with the table.
  function bytes(b) {
    if (b === null || b === undefined) return "—"
    var units = ["bytes", "KB", "MB", "GB", "TB"]
    var i = 0
    while (Math.abs(b) >= 1000 && i < units.length - 1) { b /= 1000; i++ }
    if (i === 0) return Math.round(b) + " bytes"
    return (b >= 100 || i === 1 ? Math.round(b) : b.toFixed(1)) + " " + units[i]
  }
  function temperature(v) { return v === null || v === undefined ? "—" : Math.round(v) + " °C" }
  // Memory pressure, from the share of the last 10 s some task waited on
  // memory (PSI): green while nothing waits, yellow, then red.
  function pressureColor(p) { return p >= 20 ? red : p >= 2 ? yellow : green }
  function pressureName(p) { return p >= 20 ? "Critical" : p >= 2 ? "Warning" : "Normal" }

  // Load: under a quarter Low, Normal, Busy past 60%, High past 85%.
  function loadName(v) { return v >= 85 ? "High" : v >= 60 ? "Busy" : v >= 25 ? "Normal" : "Low" }
  function loadColor(v) { return v >= 85 ? red : v >= 60 ? yellow : green }
  function round(v) { return v === null || v === undefined ? "—" : Math.round(v) + "%" }

  // The cards, 10 apart each way.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 10

    // CPU and Memory ---------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      StatCard {
        view: page.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        icon: "󰻠"
        iconColor: page.blue
        title: "CPU"
        readonly property real busy: page.cpu ? page.cpu.user + page.cpu.system : 0
        value: busy
        rows: [
          { label: "User", value: page.round(page.cpu && page.cpu.user) },
          { label: "System", value: page.round(page.cpu && page.cpu.system) },
          { label: "Idle", value: page.round(page.cpu && page.cpu.idle) }
        ]
        status: page.cpu ? page.loadName(busy) : ""
        statusColor: page.loadColor(busy)
      }
      StatCard {
        view: page.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        icon: "󰍛"
        iconColor: page.green
        ringColor: page.green
        title: "Memory"
        value: page.memory ? page.memory.used / page.memory.total * 100 : 0
        rows: page.memory ? [
          { label: "Used", value: page.bytes(page.memory.used) },
          { label: "Free", value: page.bytes(page.memory.total - page.memory.used) },
          { label: "Swap", value: page.bytes(page.memory.swapUsed) }
        ] : []
        status: page.memory ? page.pressureName(page.memory.pressure) : ""
        statusColor: page.memory ? page.pressureColor(page.memory.pressure) : page.green
      }
    }

    // The GPUs, then how hot it all runs, two to a row; Thermal takes a whole
    // row when it would be alone ----------------------------------------------
    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: 10
      rowSpacing: 10
      Repeater {
        // By count: each reading's new array would otherwise rebuild the
        // cards (and replay their rings) every second.
        model: page.gpus.length
        delegate: StatCard {
          id: gpuCard
          required property int index
          readonly property var gpu: page.gpus[index] || ({})
          view: page.view
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          icon: "󰢮"
          iconColor: page.teal
          ringColor: page.teal
          title: page.gpus.length > 1 ? "GPU " + (index + 1) : "GPU"
          value: gpu.usage || 0
          rows: (gpu.temp != null ? [{ label: "Temp", value: page.temperature(gpu.temp) }] : [])
            .concat(gpu.vramTotal ? [{ label: "VRAM", value: page.bytes(gpu.vramUsed) }] : [])
            .concat(gpu.power != null ? [{ label: "Power", value: gpu.power.toFixed(0) + " W" }] : [])
          status: gpu.usage != null ? page.loadName(gpu.usage) : ""
          statusColor: page.loadColor(gpu.usage || 0)
        }
      }
      ThermalCard {
        view: page.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        Layout.columnSpan: page.gpus.length % 2 === 0 ? 2 : 1
        // Each GPU named as its card is.
        temps: (page.cpu && page.cpu.temp !== null && page.cpu.temp !== undefined ? [{ label: "CPU", value: page.cpu.temp }] : [])
          .concat(page.gpus.map(function(g, i) {
            return { label: page.gpus.length > 1 ? "GPU " + (i + 1) : "GPU", value: g.temp }
          }).filter(function(t) { return t.value !== null && t.value !== undefined }))
          // The hottest drive stands for them all.
          .concat(page.latest && page.latest.ssdTemps && page.latest.ssdTemps.length
            ? [{ label: "SSD", value: Math.max.apply(null, page.latest.ssdTemps), ssd: true }] : [])
      }
    }

    // Storage, as System Settings shows it: each volume's name and how much
    // of it is used, a thick bar, and what's used and available. The
    // startup disk comes first.
    Card {
      id: storage
      readonly property var volumes: {
        var all = page.latest ? page.latest.volumes : []
        return all.filter(function(v) { return v.mount === "/" }).concat(all.filter(function(v) { return v.mount !== "/" }))
      }
      view: page.view
      visible: volumes.length > 0
      Layout.fillWidth: true
      implicitHeight: storageBody.implicitHeight + 32

      ColumnLayout {
        id: storageBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 14
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: "󰋊"
            color: page.gray
            font.family: page.view.host.theme.fontFamily
            font.pixelSize: page.view.host.theme.px(16)
          }
          Text {
            text: "Storage"
            color: page.view.text
            font.family: "Adwaita Sans"
            font.pixelSize: page.view.detailFontSize + 1
            font.weight: Font.DemiBold
          }
        }
        // By count, so a new reading updates the volumes in place.
        Repeater {
          model: storage.volumes.length
          delegate: ColumnLayout {
            id: volume
            required property int index
            readonly property var modelData: storage.volumes[index] || ({ mount: "", size: 1, used: 0 })
            readonly property real free: modelData.size - modelData.used
            readonly property bool full: modelData.used / modelData.size > 0.9
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              visible: volume.index > 0
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              Layout.bottomMargin: 6
              color: page.view.divider
            }
            RowLayout {
              Layout.fillWidth: true
              Text {
                Layout.fillWidth: true
                text: volume.modelData.mount === "/" ? "Startup Disk" : volume.modelData.mount.split("/").pop() || volume.modelData.mount
                elide: Text.ElideRight
                color: page.view.text
                font.family: "Adwaita Sans"
                font.pixelSize: page.view.detailFontSize
                font.weight: Font.DemiBold
              }
              Text {
                text: page.bytes(volume.modelData.used) + " of " + page.bytes(volume.modelData.size) + " used"
                color: page.view.textMuted
                font.family: "Adwaita Sans"
                font.pixelSize: page.view.host.theme.px(13)
                font.features: { "tnum": 1 }
              }
            }
            UsageBar {
              view: page.view
              Layout.fillWidth: true
              barHeight: 18
              barRadius: 5
              total: volume.modelData.size
              segments: [
                { label: "Used", value: volume.modelData.used, color: volume.full ? page.red : page.blue,
                  text: page.bytes(volume.modelData.used) },
                { label: "Available", value: 0, color: page.view.host.theme.withAlpha(page.view.text, 0.25),
                  text: page.bytes(volume.free) }
              ]
            }
          }
        }
      }
    }
  }

  // Processes, on a card like the others: its title and search, then the
  // table, each of your rows with its own ⓧ to quit it ----------------------
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 8
    Card {
      view: page.view
      Layout.fillWidth: true
      implicitHeight: processBody.implicitHeight + 24

      ColumnLayout {
        id: processBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 14
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 8
          spacing: 6
          Text {
            text: "󰒋"
            color: page.gray
            font.family: page.view.host.theme.fontFamily
            font.pixelSize: page.view.host.theme.px(16)
          }
          Text {
            text: "Processes"
            color: page.view.text
            font.family: "Adwaita Sans"
            font.pixelSize: page.view.detailFontSize + 1
            font.weight: Font.DemiBold
          }
          Item { Layout.fillWidth: true }
          // Search, filtering as you type.
          Rectangle {
            Layout.preferredWidth: 140
            Layout.preferredHeight: 26
            radius: 7
            color: page.view.well
            border.width: filter.activeFocus ? 2 : 0
            border.color: page.view.host.theme.withAlpha(page.view.accent, 0.6)
            Text {
              x: 8
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍉"
              color: page.view.textMuted
              font.family: page.view.host.theme.fontFamily
              font.pixelSize: page.view.host.theme.px(13)
            }
            Text {
              x: 26
              anchors.verticalCenter: parent.verticalCenter
              visible: filter.text === ""
              text: "Search"
              color: page.view.textMuted
              font.family: "Adwaita Sans"
              font.pixelSize: page.view.host.theme.px(13)
            }
            TextInput {
              id: filter
              x: 26
              width: parent.width - 34
              anchors.verticalCenter: parent.verticalCenter
              clip: true
              color: page.view.text
              font.family: "Adwaita Sans"
              font.pixelSize: page.view.host.theme.px(13)
              Keys.onEscapePressed: function(event) {
                if (text !== "") { text = ""; event.accepted = true }
                else event.accepted = false
              }
            }
          }
        }

        ProcessTable {
          id: table
          Layout.fillWidth: true
          Layout.preferredHeight: implicitHeight
          view: page.view
          stats: page.stats
          format: page
          query: filter.text
          onQuitRequested: function(row) { sheet.ask(row) }
        }
      }
    }
  }

  QuitSheet {
    id: sheet
    parent: page.view
    view: page.view
    onQuit: function(row, force) { page.stats.quit(row, force) }
  }
}
