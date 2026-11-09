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
import "notifications"
import "../addons/tray"

// Every view the island can open. Each is a Surface: its name (also its IPC
// route: `omarchy-shell guilhermerisu.island show <name>`), how wide the
// island gets, its padding, and the view itself. Adding a view means adding
// its folder under views/ and one Surface here. Enabled addons' views are
// added at the end (see addons/Addon.qml).
Item {
  id: views
  required property var host

  readonly property var surfaces: [controlsSurface, wifiSurface, bluetoothSurface, themesSurface, wallpapersSurface, appsSurface, powerSurface, emojiSurface, keybindsSurface, clipboardSurface, menuSurface, playerSurface, settingsSurface, notificationsSurface]
  function surfaceFor(name) {
    for (var i = 0; i < surfaces.length; i++) if (surfaces[i].viewName === name) return surfaces[i]
    for (var j = 0; j < addonSurfaces.count; j++) {
      var surface = addonSurfaces.itemAt(j)
      if (surface && surface.viewName === name) return surface
    }
    return null
  }

  // The control center's height cap: the one dragged out on its handle (0 =
  // the default 780), within the screen, plus some room while editing for the
  // zones' bars and the add panel. The island sits 8 px under the top edge, so
  // `screenMargin` leaves the same below it. `dragMax` is the live value
  // while the handle is held (-1 otherwise).
  readonly property real screenMargin: 60
  readonly property real screenLimit: Math.max(260, Window.height - screenMargin)
  readonly property real editRoom: controlCenter.editMode ? 100 : 0
  property real dragMax: -1
  readonly property real chosenMax: dragMax >= 0 ? dragMax
    : views.host.settings.controlCenterMaxHeight > 0 ? views.host.settings.controlCenterMaxHeight : 780
  readonly property real controlsMaxHeight: Math.min(Math.max(260, Math.min(chosenMax, screenLimit)) + editRoom, screenLimit)

  Surface {
    id: controlsSurface
    host: views.host
    viewName: "controls"
    // Follows the columns the control center shows.
    fixedWidth: controlCenter.islandWidth
    maxHeight: views.controlsMaxHeight
    // Taller than the island allows (many controls added): scrolls, so the
    // notifications under them stay in reach.
    Flickable {
      id: controlsScroll
      // Wider than the view by the island's padding, so what pokes out of the
      // control center (a notification's × sits on its corner) isn't cut.
      readonly property real bleed: 12
      anchors.fill: parent
      anchors.leftMargin: -bleed
      anchors.rightMargin: -bleed
      implicitWidth: controlCenter.implicitWidth
      implicitHeight: controlCenter.implicitHeight
      contentWidth: width
      contentHeight: controlCenter.implicitHeight
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      // Not while editing: dragging a control would flick the page instead.
      interactive: contentHeight > height && !controlCenter.editMode
      function scrollTo(y) { contentY = Math.max(0, Math.min(contentHeight - height, y)) }
      // Not left past the end when what's in it gets shorter (a zone removed).
      onContentHeightChanged: scrollTo(contentY)
      onHeightChanged: scrollTo(contentY)
      // Editing keeps the flick off (it would steal the drags), so the wheel
      // scrolls by hand: a tall layout in one column would be cut off.
      WheelHandler {
        enabled: controlCenter.editMode
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) { controlsScroll.scrollTo(controlsScroll.contentY - event.angleDelta.y / 2) }
      }
      // More below: what's there fades into the island instead of being cut.
      Rectangle {
        parent: controlsScroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 28
        opacity: controlsScroll.contentY < controlsScroll.contentHeight - controlsScroll.height - 1 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { MotionAnimation { theme: views.host.theme; pace: "fade"; curve: "fade" } }
        gradient: Gradient {
          GradientStop { position: 0; color: views.host.theme.withAlpha(views.host.theme.background, 0) }
          GradientStop { position: 1; color: views.host.theme.background }
        }
      }
      OverlayScrollbar { flickable: controlsScroll; parent: controlsScroll; theme: views.host.theme }
      ControlCenter { id: controlCenter; host: views.host; active: controlsSurface.active; surfacePadding: controlsSurface.padding; x: controlsScroll.bleed; width: controlsScroll.width - 2 * controlsScroll.bleed
        // From the top each time it opens, and as edit mode starts.
        onActiveChanged: if (active) controlsScroll.contentY = 0
        onEditModeChanged: controlsScroll.contentY = 0
      }
    }
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
    AppLauncher { id: appLauncher; host: views.host; active: appsSurface.active; anchors.fill: parent }
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
    OmarchyMenu { host: views.host; launcher: appLauncher; active: menuSurface.active; anchors.fill: parent }
  }

  // A tray app's menu, opened from the hover capsules (see HoverCapsules)
  // whether or not the tray addon is on.
  Surface {
    id: trayMenuSurface
    host: views.host
    viewName: "trayMenu"
    fixedWidth: 440
    TrayList { host: views.host; active: trayMenuSurface.active; anchors.fill: parent }
  }

  Surface {
    id: playerSurface
    host: views.host
    viewName: "player"
    fixedWidth: 440
    padding: 24
    PlayerView { host: views.host; active: playerSurface.active; anchors.fill: parent }
  }

  // Just the notification history, opened from the hover capsules' bell.
  Surface {
    id: notificationsSurface
    host: views.host
    viewName: "notifications"
    fixedWidth: 440
    NotificationsView { host: views.host; active: notificationsSurface.active; anchors.fill: parent }
  }

  Surface {
    id: settingsSurface
    host: views.host
    viewName: "settings"
    fixedWidth: 780
    // SettingsView pads itself, so its sidebar can run to the island's edge.
    padding: 0
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
      // Its item's own size, if it has one, over its entry's.
      readonly property var own: view && view.item
      host: views.host
      viewName: modelData.name
      fixedWidth: own && own.surfaceWidth !== undefined ? own.surfaceWidth : modelData.width || 0
      padding: own && own.surfacePadding !== undefined ? own.surfacePadding
        : modelData.padding === undefined ? 16 : modelData.padding
      cornerRadius: own && own.surfaceRadius !== undefined ? own.surfaceRadius : 0
      Loader { anchors.fill: parent; sourceComponent: modelData.component }
    }
  }

  // The grip under the control center: drag it to set how tall the island may
  // grow (the rest scrolls), double-click for the default. It rides the
  // island's bottom edge, inside the surface's padding, so it never overlaps
  // the content and stays put when the content is shorter than the cap.
  Item {
    id: resizeHandle
    visible: controlsSurface.active
    opacity: controlsSurface.opacity
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: 72
    height: controlsSurface.padding
    // Pointer y in the window, not in the handle: the handle moves with the
    // island while it is dragged.
    property real pressY
    property real pressHeight
    property bool moved
    Rectangle {
      anchors.centerIn: parent
      width: 36; height: 5; radius: 2.5
      color: grip.containsMouse || grip.pressed ? views.host.theme.fill("stronger") : views.host.theme.fill("strong")
      Behavior on color { MotionColorAnimation { theme: views.host.theme } }
      opacity: grip.containsMouse || grip.pressed || controlCenter.editMode ? 1 : 0
      Behavior on opacity { MotionAnimation { theme: views.host.theme; pace: "fade"; curve: "fade" } }
    }
    MouseArea {
      id: grip
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: Qt.SizeVerCursor
      onPressed: function(mouse) {
        resizeHandle.pressY = mapToItem(null, mouse.x, mouse.y).y
        // The height shown, which is under the cap when the content is short.
        resizeHandle.pressHeight = controlsSurface.islandHeight
        resizeHandle.moved = false
      }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        var dy = mapToItem(null, mouse.x, mouse.y).y - resizeHandle.pressY
        if (!resizeHandle.moved && Math.abs(dy) < 2) return
        resizeHandle.moved = true
        views.dragMax = Math.max(260, Math.min(resizeHandle.pressHeight + dy - views.editRoom, views.screenLimit - views.editRoom))
      }
      onReleased: {
        if (views.dragMax >= 0) views.host.settings.controlCenterMaxHeight = Math.round(views.dragMax)
        views.dragMax = -1
      }
      onCanceled: views.dragMax = -1
      onDoubleClicked: views.host.settings.controlCenterMaxHeight = 0
    }
  }
}
