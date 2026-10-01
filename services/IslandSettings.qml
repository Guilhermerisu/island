import QtQuick
import Quickshell.Io

// The island's own settings, saved to ~/.config/omarchy/island.json and
// changed live from Settings. `values` is the adapter: read and assign its
// properties directly. A missing file is written with the defaults below.
Item {
  id: islandSettings
  required property string home
  readonly property QtObject values: settingsData

  FileView {
    path: islandSettings.home + "/.config/omarchy/island.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: function(error) {
      if (error !== FileViewError.FileNotFound) return
      writeAdapter()
      Qt.callLater(reload)
    }
    JsonAdapter {
      id: settingsData
      property real motionScale: 1.5
      property bool hoverLift: true
      property bool clock24h: true
      property bool mediaPill: true
      property bool volumeHud: true
      property int bannerSeconds: 5
      property bool notch: false
      property bool downloads: true
      property bool clipboard: true
      property bool systemUpdates: true
      property bool batteryActivity: true
      property bool bluetoothActivity: true
      property bool workspaceHud: false
      property bool colorfulSettingsIcons: true
      property bool colorfulLiveActivities: true
      property string controlCenterOrder: "wifi,bluetooth,focus,night,sound,microphone,display"
      property string controlCenterHidden: "game,power,keyboard"
      property bool microphoneMuteControl: false
      property string askAi: "chatgpt"
      // Addon id → enabled, and addon id → its options (see addons/Addons.qml).
      property var addons: ({})
      property var addonOptions: ({})
    }
  }
}
