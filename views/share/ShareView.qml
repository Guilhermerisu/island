import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../../components"

// The screen-sharing activity, opened: who you're sharing with (the app the
// portal's stream goes to, read with pw-dump), for how long, and a live view
// of what's shared. A window share shows your screen: which window it is
// isn't reported. Esc or a click outside closes it.
Item {
  id: view
  required property var host
  property bool active: false
  readonly property var theme: host.theme
  readonly property color ink: host.settings.colorfulLiveActivities ? theme.system.green : theme.accent
  implicitHeight: column.implicitHeight

  property string app: ""
  onActiveChanged: if (active) {
    finder.running = true
    Qt.callLater(function() { if (view) view.forceActiveFocus() })
  }
  Keys.onEscapePressed: host.view = "rest"
  Process {
    id: finder
    command: ["python3", decodeURIComponent(String(Qt.resolvedUrl("share-app.py")).replace("file://", ""))]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: view.app = String(text || "").trim() }
  }
  readonly property var screen: {
    var all = Quickshell.screens
    for (var i = 0; i < all.length; i++) if (all[i].name === view.host.outputName) return all[i]
    return all.length ? all[0] : null
  }

  Column {
    id: column
    width: parent.width
    spacing: 12
    Row {
      spacing: 10
      Text {
        text: view.host.shareKind === "window" ? "󰖯" : "󰍹"
        color: view.ink
        font.family: view.theme.fontFamily
        font.pixelSize: view.theme.px(22)
        anchors.verticalCenter: parent.verticalCenter
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          text: view.host.shareKind === "window" ? "Sharing a window" : "Sharing your screen"
          color: "#ffffff"
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(15)
          font.weight: Font.DemiBold
        }
        Text {
          text: (view.app !== "" ? "with " + view.app + " · " : "")
            + view.host.recorder.timeText(Math.max(0, view.host.clockDate.getTime() - view.host.shareStartedAt))
          color: view.theme.muted
          font.family: view.theme.textFontFamily
          font.pixelSize: view.theme.px(12)
          font.features: { "tnum": 1 }
        }
      }
    }
    ClippingRectangle {
      width: parent.width
      height: view.screen ? width * view.screen.height / view.screen.width : width * 9 / 16
      radius: 14
      color: view.theme.fill("subtle")
      // Live while open; nothing is captured otherwise.
      ScreencopyView {
        anchors.fill: parent
        captureSource: view.active ? view.screen : null
        live: view.active
      }
    }
  }
}
