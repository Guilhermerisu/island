import QtQuick
import Quickshell

// Download live activity, as iOS's, fed by DownloadTracker.qml (browser
// downloads) and PackageUpdateTracker.qml (system updates). While running:
// an arrow in a ring left of the clock, filling as it goes (spinning when
// the size is unknown), and the time left, speed or phase on the right.
// When done, it opens straight into a card: the file's icon, its name over
// its size and folder, and an outlined check, each coming in from a blur in
// turn.
IslandPill {
  id: pill
  readonly property var tracker: host.downloads
  // Package updates share this pill; file downloads take precedence.
  readonly property var packages: host.packages
  readonly property bool packageMode: !tracker.active && tracker.finishedName === ""
  readonly property bool downloading: host.downloadActive
  readonly property bool done: host.downloadDone
  readonly property color activityAccent: host.settings.colorfulLiveActivities ? pill.host.theme.system.green : host.theme.accent

  shown: host.downloadPill
  pillWidth: done ? 380 : tracker.active ? 240 : 280
  pillHeight: done ? 76 : host.pillHeight
  keepsClock: !done
  // The finished file, or while downloading either side, opens it (or its
  // folder); a finished update just goes.
  function clicked(mouse) {
    if (done || mouse.x < 56 || mouse.x > width - 90) host.openDownloads()
    else host.view = "controls"
  }

  function formatBytes(n) {
    if (n >= 1073741824) return (n / 1073741824).toFixed(2) + " GB"
    if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB"
    if (n >= 1024) return Math.round(n / 1024) + " KB"
    return Math.round(n) + " B"
  }
  function formatTimeLeft(s) {
    if (s < 60) return Math.max(1, Math.ceil(s)) + " sec"
    if (s < 3600) return Math.ceil(s / 60) + " min"
    return Math.ceil(s / 3600) + " hr"
  }
  function folderName(path) {
    var parts = String(path || "").split("/").filter(function(p) { return p !== "" })
    return parts.length ? parts[parts.length - 1] : ""
  }

  // ---------- Downloading ----------

  Item {
    anchors.fill: parent
    opacity: pill.downloading ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

    // A still arrow inside a ring that fills with the progress, or spins
    // when there's no size to measure against.
    Item {
      id: badge
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      width: 24; height: 24
      readonly property bool measured: !pill.packageMode && pill.tracker.progress >= 0
      property real sweep: measured ? Math.max(0.03, pill.tracker.progress) : 0.7
      Behavior on sweep { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
      onSweepChanged: progressArc.requestPaint()
      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2.5
        border.color: pill.host.theme.withAlpha(pill.activityAccent, 0.25)
      }
      Canvas {
        id: progressArc
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.strokeStyle = pill.activityAccent
          ctx.lineWidth = 2.5
          ctx.lineCap = "round"
          ctx.beginPath()
          ctx.arc(width / 2, height / 2, width / 2 - 1.25, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * badge.sweep)
          ctx.stroke()
        }
        Connections {
          target: pill
          function onActivityAccentChanged() { progressArc.requestPaint() }
        }
        AmbientRotation {
          target: progressArc
          running: pill.downloading && !badge.measured && pill.visible
          onRunningChanged: if (!running) progressArc.rotation = 0
        }
      }
      Text {
        anchors.centerIn: parent
        text: pill.packageMode ? "󰏗" : "󰁅"
        color: pill.activityAccent
        font.family: pill.host.theme.fontFamily
        font.pixelSize: pill.host.theme.px(13)
        font.weight: Font.Bold
      }
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      spacing: 5
      Text {
        visible: !pill.packageMode && pill.tracker.items.length > 1
        text: pill.tracker.items.length
        color: Qt.rgba(1, 1, 1, 0.5)
        font.family: pill.host.theme.textFontFamily
        font.letterSpacing: pill.host.theme.tracking(pill.host.theme.textFontFamily, pill.host.theme.px(13))
        font.pixelSize: pill.host.theme.px(13)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
      }
      Text {
        text: pill.packageMode ? pill.packages.status
          : pill.tracker.timeLeft >= 0 ? pill.formatTimeLeft(pill.tracker.timeLeft)
          : pill.tracker.awaitingSize || pill.tracker.bytes === 0 ? "0 sec"
          : pill.tracker.speed > 0 ? pill.formatBytes(pill.tracker.speed) + "/s"
          : pill.formatBytes(pill.tracker.bytes)
        textFormat: Text.PlainText
        color: "#ffffff"
        font.family: pill.host.theme.textFontFamily
        font.pixelSize: pill.host.theme.px(13)
        font.weight: Font.DemiBold
        font.letterSpacing: -0.2
        font.features: { "tnum": 1 }
      }
    }
  }

  // ---------- Finished ----------

  PillReveal { id: reveal; theme: pill.host.theme; shown: pill.done }

  Item {
    anchors.fill: parent
    opacity: pill.done ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

    // The file type's icon on a faint tile, as Finder's.
    Rectangle {
      id: fileTile
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      width: 46; height: 46; radius: pill.host.theme.radii.large
      color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.08)
      opacity: reveal.leadingIn
      PillPart { progress: reveal.leadingIn }
      readonly property string iconSource: pill.packageMode ? ""
        : Quickshell.iconPath(pill.tracker.finishedIcon || "text-x-generic", "text-x-generic")
      Image {
        anchors.centerIn: parent
        visible: !pill.packageMode && status === Image.Ready
        source: fileTile.iconSource
        sourceSize: Qt.size(34, 34)
        width: 34; height: 34
        asynchronous: true
      }
      Text {
        anchors.centerIn: parent
        visible: pill.packageMode
        text: "󰏗"
        color: "#ffffff"
        font.family: pill.host.theme.fontFamily
        font.pixelSize: pill.host.theme.px(22)
      }
    }
    Column {
      id: details
      anchors.left: fileTile.right
      anchors.leftMargin: 14
      anchors.right: bigCheck.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      opacity: reveal.middleIn
      PillPart { progress: reveal.middleIn; scaleFrom: 1 }
      Text {
        width: parent.width
        text: pill.packageMode ? pill.packages.finishedTitle : pill.tracker.finishedName
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: "#ffffff"
        font.family: pill.host.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: pill.host.theme.px(15)
        font.weight: Font.DemiBold
        font.letterSpacing: -0.2
      }
      Text {
        width: parent.width
        text: pill.packageMode ? pill.packages.finishedDetail
          : (pill.tracker.finishedBytes > 0 ? pill.formatBytes(pill.tracker.finishedBytes) + " · " : "")
            + pill.folderName(pill.tracker.folder)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: pill.host.theme.textFontFamily
        font.letterSpacing: pill.host.theme.tracking(pill.host.theme.textFontFamily, pill.host.theme.px(12))
        font.features: { "tnum": 1 }
        font.pixelSize: pill.host.theme.px(12)
      }
    }
    // Outlined, its tick drawn in once it's there; the whole pill opens the
    // file.
    CheckCircle {
      id: bigCheck
      anchors.right: parent.right
      anchors.rightMargin: 18
      anchors.verticalCenter: parent.verticalCenter
      width: 32; height: 32
      ink: "#ffffff"
      lineWidth: 2.2
      drawn: reveal.trailingIn
      opacity: Math.min(1, reveal.trailingIn * 2)
      PillPart { progress: reveal.trailingIn; scaleFrom: 1 }
    }
  }

  // A thin ring with a tick in it; `drawn` (0 to 1) draws the tick in.
  component CheckCircle: Canvas {
    id: check
    property color ink: "#ffffff"
    property real lineWidth: 1.6
    property real drawn: 1
    onInkChanged: requestPaint()
    onDrawnChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.strokeStyle = ink
      ctx.lineWidth = lineWidth
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      var r = width / 2 - lineWidth / 2
      ctx.beginPath()
      ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2)
      ctx.stroke()
      // The tick: a short stroke down, then a long one up, drawn in order.
      var a = [width * 0.3, height * 0.52], b = [width * 0.44, height * 0.66], c = [width * 0.7, height * 0.36]
      var first = Math.hypot(b[0] - a[0], b[1] - a[1]), second = Math.hypot(c[0] - b[0], c[1] - b[1])
      var length = (first + second) * Math.max(0, Math.min(1, drawn))
      if (length <= 0) return
      ctx.beginPath()
      ctx.moveTo(a[0], a[1])
      if (length <= first) {
        var t = length / first
        ctx.lineTo(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
      } else {
        var u = (length - first) / second
        ctx.lineTo(b[0], b[1])
        ctx.lineTo(b[0] + (c[0] - b[0]) * u, b[1] + (c[1] - b[1]) * u)
      }
      ctx.stroke()
    }
  }
}
