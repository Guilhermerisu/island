import QtQuick
import "../components"
import "control-center"
import "bluetooth"
import "wifi"
import "power"
import "launcher"
import "themes"
import "wallpapers"
import "emoji"
import "keybinds"
import "clipboard"
import "menu"
import "player"
import "settings"
import "answer"

// Every view the island can open. Each is a Surface: its name (also its IPC
// route: `omarchy-shell guilhermerisu.island show <name>`), how wide the
// island gets, its padding, and the view itself. Adding a view means adding
// its folder under views/ and one Surface here. Enabled addons' views are
// added at the end (see addons/Addon.qml).
Item {
  id: views
  required property var host

  readonly property var surfaces: [controlsSurface, wifiSurface, bluetoothSurface, themesSurface, wallpapersSurface, appsSurface, powerSurface, emojiSurface, keybindsSurface, clipboardSurface, menuSurface, playerSurface, settingsSurface, answerSurface]
  function surfaceFor(name) {
    for (var i = 0; i < surfaces.length; i++) if (surfaces[i].viewName === name) return surfaces[i]
    for (var j = 0; j < addonSurfaces.count; j++) {
      var surface = addonSurfaces.itemAt(j)
      if (surface && surface.viewName === name) return surface
    }
    return null
  }

  Surface {
    id: controlsSurface
    host: views.host
    viewName: "controls"
    fixedWidth: 540
    maxHeight: 780
    ControlCenter { host: views.host; active: controlsSurface.active; anchors.fill: parent }
  }

  Surface {
    id: wifiSurface
    host: views.host
    viewName: "wifi"
    fixedWidth: 480
    WifiView { host: views.host; active: wifiSurface.active; anchors.fill: parent }
  }

  Surface {
    id: bluetoothSurface
    host: views.host
    viewName: "bluetooth"
    fixedWidth: 480
    BluetoothView { host: views.host; active: bluetoothSurface.active; anchors.fill: parent }
  }

  Surface {
    id: themesSurface
    host: views.host
    viewName: "themes"
    fixedWidth: 820
    padding: 20
    ThemeSwitcher { host: views.host; active: themesSurface.active; anchors.fill: parent }
  }

  Surface {
    id: wallpapersSurface
    host: views.host
    viewName: "wallpapers"
    fixedWidth: 820
    padding: 20
    WallpaperSwitcher { host: views.host; active: wallpapersSurface.active; anchors.fill: parent }
  }

  Surface {
    id: appsSurface
    host: views.host
    viewName: "apps"
    fixedWidth: 600
    AppLauncher { host: views.host; active: appsSurface.active; anchors.fill: parent }
  }

  Surface {
    id: emojiSurface
    host: views.host
    viewName: "emoji"
    fixedWidth: 600
    EmojiPicker { host: views.host; active: emojiSurface.active; anchors.fill: parent }
  }

  Surface {
    id: keybindsSurface
    host: views.host
    viewName: "keybinds"
    fixedWidth: 700
    KeybindList { host: views.host; active: keybindsSurface.active; anchors.fill: parent }
  }

  Surface {
    id: clipboardSurface
    host: views.host
    viewName: "clipboard"
    fixedWidth: 780
    ClipboardList { host: views.host; active: clipboardSurface.active; anchors.fill: parent }
  }

  Surface {
    id: menuSurface
    host: views.host
    viewName: "menu"
    fixedWidth: 520
    OmarchyMenu { host: views.host; active: menuSurface.active; anchors.fill: parent }
  }

  Surface {
    id: playerSurface
    host: views.host
    viewName: "player"
    fixedWidth: 440
    padding: 24
    PlayerView { host: views.host; active: playerSurface.active; anchors.fill: parent }
  }

  Surface {
    id: answerSurface
    host: views.host
    viewName: "answer"
    readonly property bool thinking: !!(view && view.thinking)
    fixedWidth: thinking ? 280 : 580
    padding: thinking ? 14 : 28
    AnswerView { host: views.host; active: answerSurface.active; anchors.fill: parent }
  }

  Surface {
    id: settingsSurface
    host: views.host
    viewName: "settings"
    fixedWidth: 760
    padding: 16
    SettingsView { host: views.host; active: settingsSurface.active; anchors.fill: parent }
  }

  Surface {
    id: powerSurface
    host: views.host
    viewName: "power"
    padding: 18
    PowerMenu { host: views.host; active: powerSurface.active; anchors.fill: parent }
  }

  Repeater {
    id: addonSurfaces
    model: views.host.addons.views
    delegate: Surface {
      required property var modelData
      host: views.host
      viewName: modelData.name
      fixedWidth: modelData.width || 0
      padding: modelData.padding === undefined ? 16 : modelData.padding
      Loader { anchors.fill: parent; sourceComponent: modelData.component }
    }
  }
}
