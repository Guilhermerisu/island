pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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

  readonly property color red: page.view.host.theme.system.red
  readonly property color blue: page.view.host.theme.system.blue
  readonly property color green: page.view.host.theme.system.green
  readonly property color yellow: page.view.host.theme.system.yellow
  readonly property color orange: page.view.host.theme.system.orange
  readonly property color teal: page.view.host.theme.system.cyan
  readonly property color purple: page.view.host.theme.system.purple
  readonly property color gray: page.view.host.theme.system.gray

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
    opacity: page.ready ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: page.view.host.theme; pace: page.ready ? "exit" : "fade"; curve: "fade" } }
    Layout.fillWidth: true
    Layout.preferredHeight: page.ready ? 0 : 240
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
            strokeColor: page.view.textMuted
            strokeWidth: 2.5
            capStyle: ShapePath.RoundCap
            PathAngleArc {
              centerX: 11; centerY: 11; radiusX: 9; radiusY: 9
              startAngle: 0; sweepAngle: 270
            }
          }
        }
        RotationAnimator on rotation {
          running: loading.visible && page.shown
          from: 0
          to: 360
          duration: 900
          loops: Animation.Infinite
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Loading…"
        color: page.view.textMuted
        font.family: page.view.host.theme.textFontFamily
        font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailCaptionFontSize)
        font.features: { "tnum": 1 }
        font.pixelSize: page.view.detailCaptionFontSize
      }
    }
  }

  // The groups, 20 apart down and 10 across, as the other panes' groups.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 20
    // Takes back the spacing after the collapsed spinner while it fades.
    Layout.topMargin: loading.visible ? -page.spacing : 0
    opacity: page.ready ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { MotionAnimation { theme: page.view.host.theme; pace: "fade"; curve: "fade" } }

    // CPU and Memory, then the GPUs and how hot it all runs, two to a row;
    // Thermal takes a whole row when it would be alone. Each card carries
    // its own title and status.
    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: 12
      rowSpacing: 12
      StatCard {
        id: cpuCard
        readonly property real busy: page.cpu ? page.cpu.user + page.cpu.system : 0
        view: page.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        title: "CPU"
        status: page.cpu ? page.loadName(busy) : ""
        statusColor: page.loadColor(busy)
        value: busy
        caption: "in use"
        ringColor: page.blue
        rows: [
          { label: "User", value: page.round(page.cpu && page.cpu.user) },
          { label: "System", value: page.round(page.cpu && page.cpu.system) },
          { label: "Idle", value: page.round(page.cpu && page.cpu.idle) }
        ]
      }
      StatCard {
        view: page.view
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        title: "Memory"
        status: page.memory ? page.pressureName(page.memory.pressure) : ""
        statusColor: page.memory ? page.pressureColor(page.memory.pressure) : page.green
        ringColor: page.purple
        caption: "in use"
        value: page.memory ? page.memory.used / page.memory.total * 100 : 0
        rows: page.memory ? [
          { label: "Used", value: page.bytes(page.memory.used) },
          { label: "Free", value: page.bytes(page.memory.total - page.memory.used) },
          { label: "Swap", value: page.memory.swapUsed ? page.bytes(page.memory.swapUsed) : "None" }
        ] : []
      }
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
          title: page.gpus.length > 1 ? "GPU " + (index + 1) : "GPU"
          status: gpu.usage != null ? page.loadName(gpu.usage) : ""
          statusColor: page.loadColor(gpu.usage || 0)
          ringColor: page.teal
          caption: "in use"
          value: gpuCard.gpu.usage || 0
          rows: (gpuCard.gpu.temp != null ? [{ label: "Temp", value: page.temperature(gpuCard.gpu.temp) }] : [])
            .concat(gpuCard.gpu.vramTotal ? [{ label: "VRAM", value: page.bytes(gpuCard.gpu.vramUsed) }] : [])
            .concat(gpuCard.gpu.power != null ? [{ label: "Power", value: gpuCard.gpu.power.toFixed(0) + " W" }] : [])
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
    Section {
      view: page.view
      visible: storage.volumes.length > 0
      Layout.fillWidth: true
      title: "Storage"
    Card {
      id: storage
      readonly property var volumes: {
        var all = page.latest ? page.latest.volumes : []
        return all.filter(function(v) { return v.mount === "/" }).concat(all.filter(function(v) { return v.mount !== "/" }))
      }
      view: page.view
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
              color: page.view.divider
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              PaneIcon {
                view: page.view
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                // A drive for the startup disk, a server for the rest.
                glyph: volume.modelData.mount === "/" ? "󰣳" : "󰒋"
                tint: page.gray
              }
              // The volume's name as the file manager shows it (its label,
              // else its folder's), then where it's mounted.
              Text {
                text: volume.modelData.mount === "/" ? "Startup Disk" : volume.modelData.label || page.capitalized(volume.modelData.mount.split("/").pop() || volume.modelData.mount)
                elide: Text.ElideRight
                Layout.maximumWidth: implicitWidth
                color: page.view.text
                font.family: page.view.host.theme.textFontFamily
                font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
                font.features: { "tnum": 1 }
                font.pixelSize: page.view.detailFontSize
                font.weight: Font.DemiBold
              }
              // Where it's mounted; not for the startup disk, whose "/"
              // alone reads as a stray mark.
              Text {
                Layout.fillWidth: true
                text: volume.modelData.mount === "/" ? "" : volume.modelData.mount
                elide: Text.ElideMiddle
                color: page.view.textMuted
                font.family: page.view.host.theme.textFontFamily
                font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailCaptionFontSize)
                font.features: { "tnum": 1 }
                font.pixelSize: page.view.detailCaptionFontSize
              }
              Text {
                text: page.bytes(volume.modelData.used) + " of " + page.bytes(volume.modelData.size) + " used"
                color: page.view.textMuted
                font.family: page.view.host.theme.textFontFamily
                font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailCaptionFontSize)
                font.pixelSize: page.view.detailCaptionFontSize
                font.features: { "tnum": 1 }
              }
            }
            UsageBar {
              view: page.view
              Layout.fillWidth: true
              barHeight: 10
              squareLegend: true
              total: volume.modelData.size
              segments: [
                { label: "Used", value: volume.modelData.used, color: volume.full ? page.red : page.blue,
                  text: page.bytes(volume.modelData.used) },
                { label: "Available", value: 0, color: page.view.host.theme.fill("stronger"),
                  text: page.bytes(volume.free) }
              ]
            }
          }
        }
      }
    }
    }
  }

  // Processes, in a box like the others: its title and search above, then
  // the table, each of your rows with its own ⓧ to quit it ----------------
  Section {
    Layout.fillWidth: true
    visible: page.ready
    opacity: page.ready ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: page.view.host.theme; pace: "fade"; curve: "fade" } }
    view: page.view
    title: "Processes"
    count: page.ready ? String(table.total) : ""
    accessory: [
      // Search, filtering as you type; inset as the Settings text fields,
      // with their focus ring.
      Rectangle {
        width: 170
        height: 28
        radius: 8
        color: page.view.host.theme.solid("quiet")
        border.width: 1
        border.color: page.view.host.theme.fill(filter.activeFocus ? "strong" : "raised")
        Rectangle {
          anchors.centerIn: parent
          width: parent.width + 6
          height: parent.height + 6
          radius: parent.radius + 3
          color: "transparent"
          border.width: 3
          border.color: page.view.host.theme.accentFill("ring")
          opacity: filter.activeFocus ? 1 : 0
          scale: filter.activeFocus ? 1 : 1.12
          Behavior on opacity { MotionAnimation { theme: page.view.host.theme; pace: "fade"; curve: "fade" } }
          Behavior on scale { MotionAnimation { theme: page.view.host.theme; pace: "standard" } }
        }
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
          text: "Filter processes"
          color: page.view.textMuted
          font.family: page.view.host.theme.textFontFamily
          font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.host.theme.px(13))
          font.features: { "tnum": 1 }
          font.pixelSize: page.view.host.theme.px(13)
        }
        TextInput {
          id: filter
          selectionColor: page.view.accent
          selectedTextColor: page.view.accentInk
          x: 26
          width: parent.width - 34
          anchors.verticalCenter: parent.verticalCenter
          clip: true
          color: page.view.text
          font.family: page.view.host.theme.textFontFamily
          font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.host.theme.px(13))
          font.features: { "tnum": 1 }
          font.pixelSize: page.view.host.theme.px(13)
          Keys.onEscapePressed: function(event) {
            if (text !== "") { text = ""; event.accepted = true }
            else event.accepted = false
          }
        }
      }
    ]
    Card {
      view: page.view
      flat: true
      Layout.fillWidth: true
      implicitHeight: processBody.implicitHeight + 16

      ColumnLayout {
        id: processBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        spacing: 10

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
