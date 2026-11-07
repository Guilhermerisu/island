pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../components"
import "../../views/settings/controls"

// The System Stats cards (CPU, memory, GPU, thermal, storage) with their
// "Loading…" state and the figures' formatting, shared by the Settings pane
// (StatsPage), also the control center zone. `view` is what the stat
// components read their colours and font sizes from: the SettingsView, or
// AddonZone's ZoneLook. `stacked` puts the cards one to a row, for
// a narrow column. Colours carry Apple's meanings (usage blue, pressure
// green to red); text and surfaces follow the theme.
ColumnLayout {
  id: cards
  required property var view
  required property var stats
  property bool shown: false
  property bool stacked: false
  spacing: 20


  readonly property var latest: stats.latest
  readonly property var cpu: latest ? latest.cpu : null
  readonly property var memory: latest ? latest.memory : null
  readonly property var gpus: latest ? latest.gpus : []

  readonly property color red: cards.view.host.theme.system.red
  readonly property color blue: cards.view.host.theme.system.blue
  readonly property color green: cards.view.host.theme.system.green
  readonly property color yellow: cards.view.host.theme.system.yellow
  readonly property color orange: cards.view.host.theme.system.orange
  readonly property color teal: cards.view.host.theme.system.cyan
  readonly property color purple: cards.view.host.theme.system.purple
  readonly property color gray: cards.view.host.theme.system.gray

  // Formatting, shared with the table.
  // `fixed` keeps one decimal ("7.0 GB"), for a column of figures.
  function bytes(b, fixed) {
    if (b === null || b === undefined) return "—"
    var units = ["bytes", "KB", "MB", "GB", "TB"]
    var i = 0
    while (Math.abs(b) >= 1000 && i < units.length - 1) { b /= 1000; i++ }
    if (i === 0) return Math.round(b) + " bytes"
    // Whole numbers without ".0", as macOS writes them ("1 TB").
    return (b >= 100 || i === 1 ? Math.round(b) : fixed ? b.toFixed(1) : Number(b.toFixed(1))) + " " + units[i]
  }
  function temperature(v) { return v === null || v === undefined ? "—" : Math.round(v) + " °C" }
  // Memory pressure, from the share of the last 10 s some task waited on
  // memory (PSI): green while nothing waits, yellow, then red.
  function pressureColor(p) { return p >= 20 ? red : p >= 2 ? yellow : green }
  function pressureName(p) { return p >= 20 ? "Critical" : p >= 2 ? "Warning" : "Normal" }

  // Load: under a quarter Low, Normal, Busy past 60%, High past 85%.
  function loadName(v) { return v >= 85 ? "High" : v >= 60 ? "Busy" : v >= 25 ? "Normal" : "Low" }
  function loadColor(v) { return v >= 85 ? red : v >= 60 ? yellow : green }
  function capitalized(name) { return name.charAt(0).toUpperCase() + name.slice(1) }
  function round(v) { return v === null || v === undefined ? "—" : Math.round(v) + "%" }

  // Until the first reading comes in (about a second), a spinner in place of
  // the groups, so nothing shows empty or jumps as it fills; then they all
  // fade in at once and the rings sweep up from zero.
  readonly property bool ready: !!latest
  // The spinner fades out over the groups as they fade in: it gives up its
  // height at once and stays drawn where it was until it's gone.
  Item {
    id: loading
    opacity: cards.ready ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: cards.view.host.theme; pace: cards.ready ? "exit" : "fade"; curve: "fade" } }
    Layout.fillWidth: true
    Layout.preferredHeight: cards.ready ? 0 : 240
    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 120 - height / 2
      spacing: 10
      Item {
        id: spinner
        anchors.horizontalCenter: parent.horizontalCenter
        width: 22
        height: 22
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: cards.view.textMuted
            strokeWidth: 2.5
            capStyle: ShapePath.RoundCap
            PathAngleArc {
              centerX: 11; centerY: 11; radiusX: 9; radiusY: 9
              startAngle: 0; sweepAngle: 270
            }
          }
        }
        RotationAnimator on rotation {
          running: loading.visible && cards.shown
          from: 0
          to: 360
          duration: 900
          loops: Animation.Infinite
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Loading…"
        color: cards.view.textMuted
        font.family: cards.view.host.theme.textFontFamily
        font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailCaptionFontSize)
        font.features: { "tnum": 1 }
        font.pixelSize: cards.view.detailCaptionFontSize
      }
    }
  }

  // The groups, 20 apart down and 10 across, as the other panes' groups.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 20
    // Takes back the spacing after the collapsed spinner while it fades.
    Layout.topMargin: loading.visible ? -cards.spacing : 0
    opacity: cards.ready ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: cards.view.host.theme; pace: "fade"; curve: "fade" } }

    // CPU and Memory, then the GPUs and how hot it all runs, two to a row
    // (one when stacked);
    // Thermal takes a whole row when it would be alone. Each card carries
    // its own title and status.
    GridLayout {
      Layout.fillWidth: true
      columns: cards.stacked ? 1 : 2
      columnSpacing: 12
      rowSpacing: 12
      StatCard {
        id: cpuCard
        readonly property real busy: cards.cpu ? cards.cpu.user + cards.cpu.system : 0
        view: cards.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        title: "CPU"
        status: cards.cpu ? cards.loadName(busy) : ""
        statusColor: cards.loadColor(busy)
        value: busy
        caption: "in use"
        ringColor: cards.blue
        rows: [
          { label: "User", value: cards.round(cards.cpu && cards.cpu.user) },
          { label: "System", value: cards.round(cards.cpu && cards.cpu.system) },
          { label: "Idle", value: cards.round(cards.cpu && cards.cpu.idle) }
        ]
      }
      StatCard {
        view: cards.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        title: "Memory"
        status: cards.memory ? cards.pressureName(cards.memory.pressure) : ""
        statusColor: cards.memory ? cards.pressureColor(cards.memory.pressure) : cards.green
        ringColor: cards.purple
        caption: "in use"
        value: cards.memory ? cards.memory.used / cards.memory.total * 100 : 0
        rows: cards.memory ? [
          { label: "Used", value: cards.bytes(cards.memory.used) },
          { label: "Free", value: cards.bytes(cards.memory.total - cards.memory.used) },
          { label: "Swap", value: cards.memory.swapUsed ? cards.bytes(cards.memory.swapUsed) : "None" }
        ] : []
      }
      Repeater {
        // By count: each reading's new array would otherwise rebuild the
        // cards (and replay their rings) every second.
        model: cards.gpus.length
        delegate: StatCard {
          id: gpuCard
          required property int index
          readonly property var gpu: cards.gpus[index] || ({})
          view: cards.view
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          title: cards.gpus.length > 1 ? "GPU " + (index + 1) : "GPU"
          status: gpu.usage != null ? cards.loadName(gpu.usage) : ""
          statusColor: cards.loadColor(gpu.usage || 0)
          ringColor: cards.teal
          caption: "in use"
          value: gpuCard.gpu.usage || 0
          rows: (gpuCard.gpu.temp != null ? [{ label: "Temp", value: cards.temperature(gpuCard.gpu.temp) }] : [])
            .concat(gpuCard.gpu.vramTotal ? [{ label: "VRAM", value: cards.bytes(gpuCard.gpu.vramUsed) }] : [])
            .concat(gpuCard.gpu.power != null ? [{ label: "Power", value: gpuCard.gpu.power.toFixed(0) + " W" }] : [])
        }
      }
      ThermalCard {
        view: cards.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        Layout.columnSpan: !cards.stacked && cards.gpus.length % 2 === 0 ? 2 : 1
        // Each GPU named as its card is.
        temps: (cards.cpu && cards.cpu.temp !== null && cards.cpu.temp !== undefined ? [{ label: "CPU", value: cards.cpu.temp }] : [])
          .concat(cards.gpus.map(function(g, i) {
            return { label: cards.gpus.length > 1 ? "GPU " + (i + 1) : "GPU", value: g.temp }
          }).filter(function(t) { return t.value !== null && t.value !== undefined }))
          // The hottest drive stands for them all.
          .concat(cards.latest && cards.latest.ssdTemps && cards.latest.ssdTemps.length
            ? [{ label: "SSD", value: Math.max.apply(null, cards.latest.ssdTemps), ssd: true }] : [])
      }
    }

    // Storage, as System Settings shows it: each volume's name and how much
    // of it is used, a thick bar, and what's used and available. The
    // startup disk comes first.
    Section {
      view: cards.view
      visible: storage.volumes.length > 0
      Layout.fillWidth: true
      title: "Storage"
    Card {
      id: storage
      readonly property var volumes: {
        var all = cards.latest ? cards.latest.volumes : []
        return all.filter(function(v) { return v.mount === "/" }).concat(all.filter(function(v) { return v.mount !== "/" }))
      }
      view: cards.view
      flat: true
      Layout.fillWidth: true
      implicitHeight: storageBody.implicitHeight + 28

      ColumnLayout {
        id: storageBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 14
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
            // The rule between volumes runs the card's full width.
            Rectangle {
              visible: volume.index > 0
              Layout.fillWidth: true
              Layout.leftMargin: -14
              Layout.rightMargin: -14
              Layout.preferredHeight: 1
              Layout.bottomMargin: 6
              color: cards.view.divider
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              PaneIcon {
                view: cards.view
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                // A drive for the startup disk, a server for the rest.
                glyph: volume.modelData.mount === "/" ? "󰣳" : "󰒋"
                tint: cards.gray
              }
              // The volume's name as the file manager shows it (its label,
              // else its folder's), then where it's mounted.
              Text {
                text: volume.modelData.mount === "/" ? "Startup Disk" : volume.modelData.label || cards.capitalized(volume.modelData.mount.split("/").pop() || volume.modelData.mount)
                elide: Text.ElideRight
                Layout.maximumWidth: implicitWidth
                color: cards.view.text
                font.family: cards.view.host.theme.textFontFamily
                font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailFontSize)
                font.features: { "tnum": 1 }
                font.pixelSize: cards.view.detailFontSize
                font.weight: Font.DemiBold
              }
              // Where it's mounted; not for the startup disk, whose "/"
              // alone reads as a stray mark.
              Text {
                Layout.fillWidth: true
                text: volume.modelData.mount === "/" ? "" : volume.modelData.mount
                elide: Text.ElideMiddle
                color: cards.view.textMuted
                font.family: cards.view.host.theme.textFontFamily
                font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailCaptionFontSize)
                font.features: { "tnum": 1 }
                font.pixelSize: cards.view.detailCaptionFontSize
              }
              Text {
                text: cards.bytes(volume.modelData.used) + " of " + cards.bytes(volume.modelData.size) + " used"
                color: cards.view.textMuted
                font.family: cards.view.host.theme.textFontFamily
                font.letterSpacing: cards.view.host.theme.tracking(cards.view.host.theme.textFontFamily, cards.view.detailCaptionFontSize)
                font.pixelSize: cards.view.detailCaptionFontSize
                font.features: { "tnum": 1 }
              }
            }
            UsageBar {
              view: cards.view
              Layout.fillWidth: true
              barHeight: 10
              squareLegend: true
              total: volume.modelData.size
              segments: [
                { label: "Used", value: volume.modelData.used, color: volume.full ? cards.red : cards.blue,
                  text: cards.bytes(volume.modelData.used) },
                { label: "Available", value: 0, color: cards.view.host.theme.fill("stronger"),
                  text: cards.bytes(volume.free) }
              ]
            }
          }
        }
      }
    }
    }
  }
}
