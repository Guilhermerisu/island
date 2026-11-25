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
import "control-center/zones.js" as ZoneModel

// Every view the island can open. Each is a Surface: its name (also its IPC
// route: `omarchy-shell guilhermerisu.island show <name>`), how wide the
// island gets, its padding, and the view itself. Adding a view means adding
// its folder under views/ and one Surface here. Enabled addons' views are
// added at the end (see addons/Addon.qml).
Item {
  id: views
  required property var host

  readonly property var surfaces: [controlsSurface, wifiSurface, bluetoothSurface, themesSurface, wallpapersSurface, appsSurface, powerSurface, emojiSurface, keybindsSurface, clipboardSurface, menuSurface, trayMenuSurface, playerSurface, settingsSurface, notificationsSurface]
  function surfaceFor(name) {
    for (var i = 0; i < surfaces.length; i++) if (surfaces[i].viewName === name) return surfaces[i]
    for (var j = 0; j < addonSurfaces.count; j++) {
      var surface = addonSurfaces.itemAt(j)
      if (surface && surface.viewName === name) return surface
    }
    return null
  }

  // The control center's bar: the most the island may be, the height dragged
  // out on its handle (0 = the default 780), within the screen. `screenMargin`
  // is the gap above the island (at least the default 8, so the notch keeps
  // its room) and 52 more for below it. `dragMax` is the live value while the handle is held (-1 otherwise). In edit
  // mode the island may be as tall as the screen: the zones with their title
  // bars, the bar's handle, the add panel and that panel's own handle; the add
  // panel is what gives (see ControlCenter.editPanelHeight).
  readonly property real screenMargin: Math.max(8, views.host.islandTop) + 52
  readonly property real screenLimit: Math.max(260, Window.height - screenMargin)
  property real dragMax: -1
  readonly property real chosenMax: dragMax >= 0 ? dragMax
    : views.host.settings.controlCenterMaxHeight > 0 ? views.host.settings.controlCenterMaxHeight : 780
  // The bar's height as chosen.
  readonly property real barHeight: Math.max(260, Math.min(chosenMax, screenLimit))
  readonly property real controlsMaxHeight: controlCenter.editMode ? screenLimit : barHeight
  // The add panel's height while its handle is held (-1 otherwise).
  property real dragPanel: -1
  // The control center's width while a side handle is held (-1 otherwise).
  property real dragWidth: -1

  Surface {
    id: controlsSurface
    host: views.host
    viewName: "controls"
    // 28 corners and 14 padding, so the cards' 14 corners sit concentric.
    padding: 14
    cornerRadius: 28
    // Follows the columns the control center shows.
    fixedWidth: controlCenter.islandWidth
    maxHeight: views.controlsMaxHeight
    // As tall as the control center, up to the bar (the screen in edit mode):
    // each zone is as tall as it is and none scrolls inside, so what is more
    // than the island may be scrolls as a page, and the notifications under the
    // controls stay in reach.
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
      WheelLatch { id: controlsLatch; flickable: controlsScroll; parent: controlsScroll }
      ControlCenter { id: controlCenter; host: views.host; active: controlsSurface.active; pageScrolling: controlsLatch.engaged; surfacePadding: controlsSurface.padding; islandLimit: views.screenLimit; editPanelDrag: views.dragPanel; widthDrag: views.dragWidth; x: controlsScroll.bleed; width: controlsScroll.width - 2 * controlsScroll.bleed
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
    padding: 14
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
    padding: 14
    ClipboardList { host: views.host; active: clipboardSurface.active; anchors.fill: parent }
  }

  Surface {
    id: menuSurface
    host: views.host
    viewName: "menu"
    fixedWidth: 520
    padding: 14
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
    padding: 16
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

  // A handle: drag it to set `value` (what it is as it is pressed), within
  // [least, most]; `live` carries the value while it is held, `committed` the
  // one it is let go at, `reset` a double-click. Pointer y is read in the
  // window, not in the handle: the handle moves with the island while it is
  // dragged. `panel` is the add panel's, drawn as a tab; the bar's is a
  // capsule. Its hit area is `padding` tall, as the island's padding.
  // `horizontal` ones are dragged sideways at the island's `side` edge (-1
  // left, +1 right): the island is centered, so its width changes by twice
  // the pointer's move, `side * 2 * dx`.
  component Grip: Item {
    id: grip
    property bool panel: false
    property bool horizontal: false
    property int side: 1
    property string tip: ""
    property real value: 0
    property real least: 0
    property real most: 0
    property real pressAt
    property real pressValue
    property real last: -1
    property bool moved
    readonly property bool active: area.containsMouse || area.pressed || gripTip.hovered
    readonly property real factor: horizontal ? 2 * side : 1
    signal live(real value)
    signal committed(real value)
    signal cancelled()
    signal reset()
    width: horizontal ? controlsSurface.padding : 72
    height: horizontal ? 72 : controlsSurface.padding
    function at(item, mouse) {
      var p = item.mapToItem(null, mouse.x, mouse.y)
      return horizontal ? p.x : p.y
    }
    Rectangle {
      visible: !grip.panel
      anchors.centerIn: parent
      width: grip.horizontal ? 5 : 36; height: grip.horizontal ? 36 : 5; radius: 2.5
      color: grip.active ? views.host.theme.fill("stronger") : views.host.theme.fill("strong")
      Behavior on color { MotionColorAnimation { theme: views.host.theme } }
      // Shown while it is hovered or held, and throughout edit mode.
      opacity: grip.active || controlCenter.editMode ? 1 : 0
      Behavior on opacity { MotionAnimation { theme: views.host.theme; pace: "fade"; curve: "fade" } }
    }
    // The panel's: a wider tab with two lines in it, in the accent, so the two
    // handles in edit mode are not taken for one another.
    Rectangle {
      visible: grip.panel
      anchors.centerIn: parent
      width: 56; height: 14; radius: 7
      color: grip.active ? views.host.theme.accentFill("medium") : views.host.theme.accentFill("soft")
      border.width: 1
      border.color: views.host.theme.accentFill("ring")
      Behavior on color { MotionColorAnimation { theme: views.host.theme } }
      Column {
        anchors.centerIn: parent
        spacing: 2
        Repeater {
          model: 2
          Rectangle { width: 20; height: 2; radius: 1; color: views.host.theme.accent }
        }
      }
    }
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: grip.horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
      onPressed: function(mouse) {
        grip.pressAt = grip.at(area, mouse)
        grip.pressValue = grip.value
        grip.moved = false
      }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        var d = grip.at(area, mouse) - grip.pressAt
        if (!grip.moved && Math.abs(d) < 2) return
        grip.moved = true
        grip.last = Math.max(grip.least, Math.min(grip.pressValue + grip.factor * d, Math.max(grip.least, grip.most)))
        grip.live(grip.last)
      }
      onReleased: {
        if (grip.moved) grip.committed(grip.last)
        else grip.cancelled()
      }
      onCanceled: grip.cancelled()
      onDoubleClicked: grip.reset()
    }
    Tooltip { id: gripTip; theme: views.host.theme; text: grip.tip; above: !grip.horizontal }
  }

  // The bar's handle: drag it to set how tall the island may grow (the rest
  // scrolls), double-click for the default. Outside edit mode it rides the
  // island's bottom edge, inside the surface's padding, so it never overlaps
  // the content and stays put when the content is shorter than the bar. In edit mode it sits under the zones' frame, where
  // the control center leaves it room (ControlCenter.daySlot), and goes with
  // the page when that scrolls out of view.
  Grip {
    id: barGrip
    readonly property Item slot: controlCenter.daySlot
    readonly property real slotY: controlsSurface.padding + slot.y - controlsScroll.contentY + (slot.height - height) / 2
    visible: controlsSurface.active && (!controlCenter.editMode
      || (slotY >= controlsSurface.padding - 2 && slotY + height <= controlsSurface.padding + controlsScroll.height + 2))
    opacity: controlsSurface.opacity
    height: controlCenter.editMode ? 20 : controlsSurface.padding
    x: (views.width - width) / 2
    y: controlCenter.editMode ? slotY : views.height - height
    tip: "Drag to resize"
    // Outside edit mode, start from the island's actual height when content is
    // shorter than the saved cap so dragging up shrinks the island immediately.
    value: controlCenter.editMode ? views.barHeight : Math.max(260, Math.min(views.barHeight, Math.round(controlsSurface.islandHeight)))
    least: 260
    most: views.screenLimit
    onLive: function(v) { views.dragMax = v }
    onCommitted: function(v) {
      views.host.settings.controlCenterMaxHeight = Math.round(v)
      views.dragMax = -1
    }
    onCancelled: views.dragMax = -1
    onReset: views.host.settings.controlCenterMaxHeight = 0
  }

  // The add panel's handle, in edit mode, at the island's bottom edge under
  // the panel: drag it to show more of what there is to add (saved).
  Grip {
    id: panelGrip
    panel: true
    visible: controlsSurface.active && controlCenter.editMode
    opacity: controlsSurface.opacity
    x: (views.width - width) / 2
    y: views.height - height
    tip: "Drag to show more to add"
    value: controlCenter.editPanelHeight
    least: ZoneModel.minEditPanelHeight
    most: controlCenter.editPanelRoom
    onLive: function(v) { views.dragPanel = v }
    onCommitted: function(v) {
      views.host.settings.controlCenterEditPanelHeight = Math.round(v)
      views.dragPanel = -1
    }
    onCancelled: views.dragPanel = -1
    onReset: views.host.settings.controlCenterEditPanelHeight = 0
  }

  // Side handles: drag left or right to widen or narrow the control center
  // without changing its column count.
  Repeater {
    model: [-1, 1]
    delegate: Grip {
      required property int modelData
      horizontal: true
      side: modelData
      tip: "Drag to resize width"
      x: side < 0 ? 0 : views.width - width
      y: (views.height - height) / 2
      visible: controlsSurface.active
      opacity: controlsSurface.opacity
      value: controlCenter.islandWidth
      least: controlCenter.widthBounds.min
      most: controlCenter.widthBounds.max
      onLive: function(v) { views.dragWidth = v }
      onCommitted: function(v) {
        controlCenter.zones.setWidth(controlCenter.shownColumns, Math.round(v))
        views.dragWidth = -1
      }
      onCancelled: views.dragWidth = -1
      onReset: controlCenter.zones.setWidth(controlCenter.shownColumns, 0)
    }
  }
}
