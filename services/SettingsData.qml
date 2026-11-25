import QtQuick
import Quickshell.Io

// Every island setting and its default, as saved in island.json (see
// IslandSettings).
JsonAdapter {
  id: settingsData
  property real motionScale: 1.5
  property bool clock24h: true
  property bool clockAmPm: false
  property string clockFormat: "time"
  property string hoverStyle: "none"
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
  // How long a banner stays, in seconds; 0 keeps it up until dismissed.
  property int bannerSeconds: 5
  property bool stackNotifications: false
  property bool notificationButtons: false
  property bool notificationFullText: false
  // The sound played as a banner arrives: a sound in
  // /usr/share/sounds/freedesktop/stereo, by name, or "none".
  property string notificationSound: "none"
  property bool notch: false
  property bool restingOutline: false
  // Pixels between the top edge and the island (IslandSettings.topGap has it
  // within its limits); the notch ignores it.
  property int topGap: 8
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
  // How many of workspaces 1–10 its indicator shows at once (5–10).
  property int workspaceHudCount: 5
  property bool colorfulSettingsIcons: true
  property bool colorfulLiveActivities: true
  // "dark", "light", or "theme"; empty falls back to themeBackground for older configs.
  property string appearance: ""
  property bool themeBackground: false
  property string textFontMode: "island"
  property string customFont: ""
  property real textScale: 1
  property string controlCenterOrder: "wifi,bluetooth,focus,night,sound,microphone,display"
  property string controlCenterHidden: "game,power,keyboard"
  // The plugins' tiles added to its control grid (addons/plugins), as
  // "plugins.<plugin id>"; none until added.
  property string controlCenterPlugins: ""
  // The plugins pinned to its Plugins zone (addons/plugins), in order, as
  // plugin ids; apart from the grid's tiles above.
  property string pluginsZonePinned: ""
  // Its columns (1–3) and, per column, the zones in it (JSON, see
  // views/control-center/Zones.qml).
  property int controlCenterColumns: 1
  property string controlCenterZones: "[[\"controls\",\"notifications\"]]"
  // Each column's share of the width, per column count (JSON, e.g.
  // {"3":[0.3,0.4,0.3]}); unset counts split evenly.
  property string controlCenterColumnWidths: ""
  // The island's width, per column count (JSON, e.g. {"1":620,"3":1380});
  // unset counts use the default width for that layout.
  property string controlCenterWidths: ""
  // Each zone's size when not Normal (JSON, e.g. {"weather":"small"},
  // see views/control-center/zones.js): "xsmall" or "small" by zone id.
  property string controlCenterZoneSizes: ""
  // Slider cards drawn upright, as their keys.
  property string controlCenterVertical: ""
  // Its height cap, set with the handle under it; 0 for the default.
  property int controlCenterMaxHeight: 0
  // The add panel's height in edit mode, set with the handle under it; 0 for
  // the default (views/control-center/zones.js editPanelHeight).
  property int controlCenterEditPanelHeight: 0
  property bool microphoneMuteControl: false
  property bool stayAwakeControl: false
  property bool screensaverControl: false
  property bool screenshotControl: false
  property bool screenRecordControl: false
  property bool dictateControl: false
  property bool reminderControl: false
  property bool hideOnRightClick: true
  property bool autoHideFullscreen: false
  property bool autoHideTiling: false
  property bool menuApps: false
  // Addon id → enabled, and addon id → its options (see addons/Addons.qml).
  property var addons: ({})
  property var addonOptions: ({})
}
