import QtQuick
import Quickshell.Io

// The island's side of Omarchy's OSD plumbing, so the stock omarchy.osd plugin
// can stay off (setup disables it) and no popup appears twice. `omarchy-osd`
// and Omarchy's scripts reach the OSD over IPC target "osd": ShellIpc on newer
// Omarchy, a bare IpcHandler on releases without it. The internal panel's
// brightness keys are handled inside the shell with no IPC, so the backlight
// is watched here and reported the same way.
Item {
  id: bridge
  required property var host

  // ShellIpc is a compile-time type, so it sits in its own file: where it
  // doesn't exist that file fails to load and the IpcHandler one takes over,
  // instead of the whole island failing with it.
  Loader {
    source: "OsdShellIpc.qml"
    onStatusChanged: if (status === Loader.Error) source = "OsdIpcHandler.qml"
    onLoaded: item.shown.connect(bridge.host.showOsd)
  }

  property string device: ""
  property bool seeded: false
  property int lastPercent: -1

  Process {
    id: deviceProc
    command: ["omarchy-hw-display"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: bridge.device = String(text || "").trim()
    }
  }
  FileView {
    id: brightnessFile
    path: bridge.device ? "/sys/class/backlight/" + bridge.device + "/brightness" : ""
    blockLoading: true
    watchChanges: true
    printErrors: false
    onLoaded: bridge.brightnessChanged()
    onFileChanged: reload()
  }
  FileView {
    id: maxFile
    path: bridge.device ? "/sys/class/backlight/" + bridge.device + "/max_brightness" : ""
    blockLoading: true
    printErrors: false
  }
  // The first reading is the panel reporting in, not a change; only later
  // steps show, the way the island's volume HUD treats its first reading.
  function brightnessChanged() {
    var max = Number(String(maxFile.text() || "").trim())
    var raw = Number(String(brightnessFile.text() || "").trim())
    if (!(max > 0) || isNaN(raw)) return
    var percent = Math.round(100 * raw / max)
    if (!seeded) {
      seeded = true
      lastPercent = percent
      return
    }
    if (percent === lastPercent) return
    lastPercent = percent
    if (!host.settings.brightnessHud) return
    host.showOsd(JSON.stringify({
      icon: "brightness",
      message: "",
      value: String(percent),
      max: "100",
      progressText: percent + "%",
      duration: "1200"
    }))
  }
}
