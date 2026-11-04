import QtQuick
import Quickshell
import Quickshell.Wayland

// Other plugins' bar widgets, made for Omarchy's own bar, kept alive off
// screen so their panels still open while Island is the bar. Such a widget
// carries its panel, which anchors to the widget and to the window it sits
// in, so the widgets sit in a click-through strip along the top of the
// screen: a panel opens just below the strip, centred, under the island.
//
// Which widgets: the third-party ones in the bar layout of shell.json. The
// shell sends `omarchy-shell shell toggle <id>` to Island's summonBarWidget,
// hideBarWidget, and isBarWidgetOpen (see Island.qml), which land here.
Item {
  id: hosts
  required property var host

  // The strip's height: a panel opens this far from the top, plus its gap.
  readonly property int stripHeight: 56

  readonly property var entries: {
    var registry = host.barWidgetRegistry
    var layout = (host.barConfig || {}).layout || {}
    var seen = {}, found = []
    if (registry) registry.revision
    ;["left", "center", "right"].forEach(function(section) {
      (layout[section] || []).forEach(function(entry) {
        var id = String(typeof entry === "string" ? entry : entry && entry.id || "")
        var meta = registry && id ? registry.metadataFor(id) : null
        if (!meta || meta.firstParty || seen[id]) return
        seen[id] = true
        found.push({ id: id, settings: typeof entry === "object" ? entry : {} })
      })
    })
    return found
  }

  function widget(id) {
    for (var i = 0; i < entries.length; i++)
      if (entries[i].id === id) {
        var slot = repeater.itemAt(i)
        return slot ? slot.item : null
      }
    return null
  }
  // In the layout (not necessarily loaded yet); reads `entries`, so a
  // binding on it follows the layout.
  function has(id) {
    for (var i = 0; i < entries.length; i++) if (entries[i].id === id) return true
    return false
  }
  function summon(id) {
    var w = widget(id)
    if (!w || typeof w.open !== "function") return false
    w.open()
    return true
  }
  function hide(id) {
    var w = widget(id)
    if (!w || typeof w.close !== "function") return false
    w.close()
    return true
  }
  function isOpen(id) {
    var w = widget(id)
    return !!w && w.opened === true
  }

  function screenOf(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
    return null
  }

  // What the widgets and their panels read off Omarchy's bar (Ui/PluginBarApi).
  // One panel open at a time, as there.
  QtObject {
    id: bar
    property var shell: hosts.host.shell
    readonly property var foreignPopoutMarker: ({ foreign: true })
    property color foreground: hosts.host.theme.text
    property color barForeground: hosts.host.theme.text
    property color background: hosts.host.theme.background
    property color urgent: hosts.host.theme.urgent
    property string fontFamily: hosts.host.theme.fontFamily
    property string position: "top"
    property bool vertical: false
    property int barSize: hosts.stripHeight
    property bool transparent: false
    property bool foregroundAnimationEnabled: true
    property bool centerSectionRevealHeld: false
    property bool centerHoverRevealSuppressed: false
    property var activePopout: null
    property var clickTargets: []
    property var layoutConfig: ({})

    function requestPopout(owner) {
      if (activePopout && activePopout !== owner && typeof activePopout.close === "function") activePopout.close()
      activePopout = owner
    }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function switchPanelFrom(owner, direction) { return false }
    function targetBelongsToWindow(target, window) { return false }
    function moduleWidgets(id) { var w = hosts.widget(id); return w ? [w] : [] }
    function run(command) { Quickshell.execDetached(["bash", "-c", String(command || "")]) }
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
    function setCenterHoverRevealSuppressed(value) {}
  }

  PanelWindow {
    screen: hosts.screenOf(hosts.host.outputName)
    visible: hosts.entries.length > 0
    color: "transparent"
    implicitHeight: hosts.stripHeight
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    WlrLayershell.namespace: "omarchy-island-widgets"
    WlrLayershell.layer: WlrLayer.Background
    // No input: the widgets are only there to be opened by key or the Plugins view.
    mask: Region {}

    Repeater {
      id: repeater
      model: hosts.entries
      delegate: Loader {
        id: slot
        required property var modelData
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: 0
        sourceComponent: (hosts.host.barWidgetRegistry.widgets[modelData.id] || {}).component || null
        onLoaded: {
          if ("bar" in item) item.bar = bar
          if ("moduleName" in item) item.moduleName = modelData.id
          if ("settings" in item) item.settings = modelData.settings
        }
      }
    }
  }
}
