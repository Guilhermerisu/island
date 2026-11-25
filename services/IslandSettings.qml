import QtQuick
import Quickshell.Io

// The island's own settings, saved to ~/.config/omarchy/island.json and
// changed live from Settings. `values` is the adapter: read and assign its
// properties directly. A missing file is written with the defaults (see
// SettingsData.qml).
Item {
  id: islandSettings
  required property string home
  readonly property QtObject values: settingsData
  readonly property string path: home + "/.config/omarchy/island.json"
  // A copy of an island.json that couldn't be read, made before the next
  // change writes over it.
  readonly property string backupPath: path + ".broken"
  // Why island.json couldn't be read, or "" while it reads fine. Settings
  // shows it; the island runs on the defaults meanwhile.
  property string loadError: ""
  // The gap above the resting island, within the limits Settings offers,
  // since island.json can be hand-edited. Flush with the edge is the notch's.
  readonly property int topGapMin: 1
  readonly property int topGapMax: 32
  readonly property int topGap: Math.max(topGapMin, Math.min(topGapMax, settingsData.topGap))

  function check(raw) {
    var parsed
    try {
      parsed = JSON.parse(raw)
      if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("it isn't a JSON object")
    } catch (e) {
      if (loadError === "") {
        backup.command = ["cp", "-f", path, backupPath]
        backup.running = true
        console.warn("island: couldn't read " + path + " (" + e.message + "); using the defaults, a copy is at " + backupPath)
      }
      loadError = String(e.message || e)
      return
    }
    loadError = ""
    migrate(parsed)
  }
  // Settings saved by older versions.
  function migrate(saved) {
    // The hover style was two switches before it was one choice.
    if (!saved.hoverStyle && (saved.hoverCapsules || saved.hoverExpand))
      settingsData.hoverStyle = saved.hoverCapsules ? "capsules" : "expand"
  }
  Process { id: backup }

  FileView {
    id: file
    path: islandSettings.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: islandSettings.check(text())
    onAdapterUpdated: writeAdapter()
    onLoadFailed: function(error) {
      if (error !== FileViewError.FileNotFound) {
        islandSettings.loadError = "it couldn't be opened"
        return
      }
      writeAdapter()
      Qt.callLater(reload)
    }
    SettingsData { id: settingsData }
  }
}
