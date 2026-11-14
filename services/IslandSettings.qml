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
      property bool clock24h: true
      property bool clockAmPm: false
      property string clockFormat: "time"
      property string hoverStyle: "none"
      property bool hoverExpand: hoverStyle === "expand"
      property bool hoverCapsules: hoverStyle === "capsules"
      property string glanceLeft1: "workspace"
      property string glanceLeft2: "battery"
      property string glanceRight1: "weather"
      property string glanceRight2: "volume"
      property bool glanceMediaSatellite: true
      property bool glanceMediaSatelliteBorder: true
      property bool capsuleWorkspaces: false
      property bool capsuleTray: true
      property bool capsuleSystem: true
      property bool capsuleEvent: false
      property bool capsuleWeather: false
      property bool capsuleNotifications: true
      property bool capsuleMedia: false
      property bool capsulePlugins: false
      property bool mediaPill: true
      property bool volumeHud: true
      property bool brightnessHud: true
      property int bannerSeconds: 5
      property bool stackNotifications: false
      property bool notificationButtons: false
      property bool notificationFullText: false
      property bool notch: false
      // Windows start under the resting island (the reserve window in Island.qml).
      property bool reserveSpace: false
      property bool downloads: true
      property bool clipboard: true
      property bool screenRecordingActivity: true
      property bool systemUpdates: true
      property bool batteryActivity: true
      property bool bluetoothActivity: true
      property bool networkActivity: true
      property bool playbackOsd: false
      property bool workspaceHud: false
      property bool colorfulSettingsIcons: true
      property bool colorfulLiveActivities: true
      property bool themeBackground: false
      property string textFontMode: "island"
      property string customFont: ""
      property real textScale: 1
      property string controlCenterOrder: "wifi,bluetooth,focus,night,sound,microphone,display"
      property string controlCenterHidden: "game,power,keyboard"
      // The plugins' tiles added to its control grid (addons/plugins), as
      // "plugins.<plugin id>"; none until added.
      property string controlCenterPlugins: ""
      // Its columns (1–3) and, per column, the zones in it (JSON, see
      // views/control-center/Zones.qml).
      property int controlCenterColumns: 1
      property string controlCenterZones: "[[\"controls\",\"notifications\"]]"
      // Each column's share of the width, per column count (JSON, e.g.
      // {"3":[0.3,0.4,0.3]}); unset counts split evenly.
      property string controlCenterColumnWidths: ""
      // Slider cards drawn upright, as their keys.
      property string controlCenterVertical: ""
      // Its height cap, set with the handle under it; 0 for the default.
      property int controlCenterMaxHeight: 0
      property bool microphoneMuteControl: false
      property bool stayAwakeControl: false
      property bool screensaverControl: false
      property bool screenshotControl: false
      property bool screenRecordControl: false
      property bool dictateControl: false
      property bool reminderControl: false
      property bool autoHideFullscreen: false
      property bool autoHideTiling: false
      property bool menuApps: false
      // Before Ask AI was an addon; carried over and cleared (see Addons.qml).
      property string askAi: ""
      // Addon id → enabled, and addon id → its options (see addons/Addons.qml).
      property var addons: ({})
      property var addonOptions: ({})
    }
  }
}
