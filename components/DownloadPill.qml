import QtQuick

// Download live activity, in iOS's style, fed by DownloadTracker.qml
// (browser downloads) and PackageUpdateTracker.qml (system updates). While
// running: an icon inside a spinning ring left of the clock, and the speed
// or phase on the right. When done: a check, the name and details, and for a
// downloaded file, an App Store–style Open button.
Item {
  id: pill
  required property var host
  readonly property var tracker: host.downloads
  // Package updates share this pill; file downloads take precedence.
  readonly property var packages: host.packages
  readonly property bool packageMode: !tracker.active && tracker.finishedName === ""
  readonly property bool downloading: host.downloadActive
  readonly property bool done: host.downloadDone
  readonly property color activityAccent: host.settings.colorfulLiveActivities ? "#30d158" : host.theme.accent
  readonly property color activityInk: host.theme.contrastOn(activityAccent)

  opacity: downloading || done ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  function formatBytes(n) {
    if (n >= 1073741824) return (n / 1073741824).toFixed(1) + " GB"
    if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB"
    if (n >= 1024) return Math.round(n / 1024) + " KB"
    return Math.round(n) + " B"
  }

  // ---------- Downloading ----------

  Item {
    anchors.fill: parent
    opacity: pill.downloading ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

    // A still arrow inside a ring that spins (there's no total size to show
    // progress against).
    Item {
      id: badge
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      width: 28; height: 28
      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2.5
        border.color: pill.host.theme.withAlpha(pill.activityAccent, 0.22)
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
          ctx.arc(width / 2, height / 2, width / 2 - 1.25, -Math.PI / 2, Math.PI * 0.9)
          ctx.stroke()
        }
        Connections {
          target: pill
          function onActivityAccentChanged() { progressArc.requestPaint() }
        }
        AmbientRotation {
          target: progressArc
          running: pill.downloading && pill.visible
        }
      }
      Text {
        anchors.centerIn: parent
        text: pill.packageMode ? "󰏗" : "󰁅"
        color: pill.activityAccent
        font.family: pill.host.theme.fontFamily
        font.pixelSize: pill.host.theme.px(15)
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
        font.pixelSize: pill.host.theme.px(12)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
      }
      Text {
        text: pill.packageMode ? pill.packages.status
          : pill.tracker.speed > 0 ? pill.formatBytes(pill.tracker.speed) + "/s" : pill.formatBytes(pill.tracker.bytes)
        textFormat: Text.PlainText
        color: pill.activityAccent
        font.family: pill.host.theme.textFontFamily
        font.pixelSize: pill.host.theme.px(12)
        font.weight: Font.DemiBold
        font.letterSpacing: -0.2
        font.features: { "tnum": 1 }
      }
    }
  }

  // ---------- Finished ----------

  Item {
    anchors.fill: parent
    opacity: pill.done ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

    Rectangle {
      id: check
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 40; height: 40; radius: 20
      color: pill.activityAccent
      scale: pill.done ? 1 : 0.86
      Behavior on scale { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
      Text {
        anchors.centerIn: parent
        text: "󰄬"
        color: pill.activityInk
        font.family: pill.host.theme.fontFamily
        font.pixelSize: pill.host.theme.px(22)
        font.weight: Font.Bold
      }
    }
    Column {
      anchors.left: check.right
      anchors.leftMargin: 12
      anchors.right: openButton.visible ? openButton.left : parent.right
      anchors.rightMargin: openButton.visible ? 12 : 20
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text {
        width: parent.width
        text: pill.packageMode ? pill.packages.finishedTitle : pill.tracker.finishedName
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: "#ffffff"
        font.family: pill.host.theme.textFontFamily
        font.pixelSize: pill.host.theme.px(15)
        font.weight: Font.DemiBold
        font.letterSpacing: -0.2
      }
      Text {
        width: parent.width
        text: pill.packageMode ? pill.packages.finishedDetail
          : "Downloaded" + (pill.tracker.finishedBytes > 0 ? " · " + pill.formatBytes(pill.tracker.finishedBytes) : "")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: pill.host.theme.textFontFamily
        font.pixelSize: pill.host.theme.px(12)
      }
    }
    // App Store–style capsule; the whole pill opens the file too.
    Rectangle {
      id: openButton
      visible: !pill.packageMode
      anchors.right: parent.right
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      width: openLabel.implicitWidth + 28
      height: 30
      radius: 15
      color: pill.host.theme.withAlpha(pill.activityAccent, 0.22)
      Text {
        id: openLabel
        anchors.centerIn: parent
        text: "Open"
        color: pill.activityAccent
        font.family: pill.host.theme.textFontFamily
        font.pixelSize: pill.host.theme.px(14)
        font.weight: Font.Bold
      }
    }
  }
}
